//! Linux backend: EGL DMA-BUF sharing for the OpenGL (virgl) path.
//!
//! Vulkan/lavapipe under UTM can't export DMA-BUF, but virgl's GL stack exposes
//! EGL_MESA_image_dma_buf_export (app) and EGL_EXT_image_dma_buf_import
//! (compositor). The app renders into a normal wgpu GL texture, wraps it as an
//! EGLImage, and exports a DMA-BUF fd + layout (stride/offset/fourcc/modifier).
//! The compositor imports that fd via EGL into a GL texture it composites.
//!
//! wgpu-hal's gles `Device` hides its EGL context, so the EGL display/context
//! and extension entry points are captured once from the `Adapter` (see
//! [`init_egl`]) into a process-global and reused here. The GL context is
//! current on the render thread after any wgpu op, which is when these run.

use glow::HasContext;
use std::ffi::c_void;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::OnceLock;

static NEXT_ID: AtomicU32 = AtomicU32::new(1);

// -- EGL / GL constants --
const EGL_GL_TEXTURE_2D: u32 = 0x30B1;
const EGL_LINUX_DMA_BUF_EXT: u32 = 0x3270;
const EGL_WIDTH: i32 = 0x3057;
const EGL_HEIGHT: i32 = 0x3056;
const EGL_LINUX_DRM_FOURCC_EXT: i32 = 0x3271;
const EGL_DMA_BUF_PLANE0_FD_EXT: i32 = 0x3272;
const EGL_DMA_BUF_PLANE0_OFFSET_EXT: i32 = 0x3273;
const EGL_DMA_BUF_PLANE0_PITCH_EXT: i32 = 0x3274;
const EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT: i32 = 0x3443;
const EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT: i32 = 0x3444;
const EGL_IMAGE_PRESERVED_KHR: i32 = 0x30D2;
const EGL_NONE: i32 = 0x3038;
const EGL_TRUE: u32 = 1;
const GL_TEXTURE_2D: u32 = 0x0DE1;

type EglDisplay = *mut c_void;
type EglContext = *mut c_void;
type EglImage = *mut c_void;
type EglClientBuffer = *mut c_void;

type PfnCreateImage =
    unsafe extern "system" fn(EglDisplay, EglContext, u32, EglClientBuffer, *const i32) -> EglImage;
type PfnDestroyImage = unsafe extern "system" fn(EglDisplay, EglImage) -> u32;
type PfnExportQuery =
    unsafe extern "system" fn(EglDisplay, EglImage, *mut i32, *mut i32, *mut u64) -> u32;
type PfnExport =
    unsafe extern "system" fn(EglDisplay, EglImage, *mut i32, *mut i32, *mut i32) -> u32;
type PfnImageTargetTexture = unsafe extern "system" fn(u32, EglImage);
type PfnMakeCurrent =
    unsafe extern "system" fn(EglDisplay, EglImage, EglImage, EglContext) -> u32;

/// Process-global EGL handles + extension entry points captured from the adapter.
struct EglShared {
    display: EglDisplay,
    context: EglContext,
    glow: glow::Context,
    create_image: PfnCreateImage,
    destroy_image: PfnDestroyImage,
    export_query: PfnExportQuery,
    export: PfnExport,
    image_target_texture: PfnImageTargetTexture,
    make_current: PfnMakeCurrent,
}

impl EglShared {
    /// Make our (wgpu's) EGL context current on this thread (surfaceless) so the
    /// GL/EGL calls below operate on it. wgpu re-binds it on its next op.
    unsafe fn make_current(&self) {
        (self.make_current)(self.display, std::ptr::null_mut(), std::ptr::null_mut(), self.context);
    }
}
// SAFETY: the GL/EGL handles are only touched on the render thread where the
// context is current; access is effectively single-threaded per device.
unsafe impl Send for EglShared {}
unsafe impl Sync for EglShared {}

static EGL: OnceLock<EglShared> = OnceLock::new();

/// Capture the EGL display/context + dma_buf extension entry points from a
/// freshly created GL adapter. Must be called once after `request_adapter`,
/// before any [`SharedTexture`] is created. No-op if already initialized or the
/// adapter isn't the GL backend.
pub fn init_egl(adapter: &wgpu::Adapter) {
    if EGL.get().is_some() {
        return;
    }
    unsafe {
        let Some(hal_adapter) = adapter.as_hal::<wgpu_hal::gles::Api>() else {
            log::warn!("init_egl: adapter is not the GL backend");
            return;
        };
        let ctx = hal_adapter.adapter_context();
        let Some(egl) = ctx.egl_instance() else {
            log::error!("init_egl: no EGL instance on adapter context");
            return;
        };
        let Some(display) = ctx.raw_display() else {
            log::error!("init_egl: no EGL display on adapter context");
            return;
        };
        let display = display.as_ptr();
        let context = ctx.raw_context();

        macro_rules! load {
            ($name:literal, $ty:ty) => {
                match egl.get_proc_address($name) {
                    Some(f) => std::mem::transmute::<_, $ty>(f),
                    None => {
                        log::error!("init_egl: missing entry point {}", $name);
                        return;
                    }
                }
            };
        }
        let create_image = load!("eglCreateImageKHR", PfnCreateImage);
        let destroy_image = load!("eglDestroyImageKHR", PfnDestroyImage);
        let export_query = load!("eglExportDMABUFImageQueryMESA", PfnExportQuery);
        let export = load!("eglExportDMABUFImageMESA", PfnExport);
        let image_target_texture =
            load!("glEGLImageTargetTexture2DOES", PfnImageTargetTexture);
        let make_current = load!("eglMakeCurrent", PfnMakeCurrent);

        // A glow context bound to the same loader, used for compositor-side
        // glGenTextures/glBindTexture during import. from_loader_function reads
        // GL_VERSION immediately, so the EGL context must be current; hold the
        // adapter context lock (which makes it current) while building it.
        let glow = {
            let _current = ctx.lock();
            glow::Context::from_loader_function(|s| {
                egl.get_proc_address(s).map_or(std::ptr::null(), |f| f as *const c_void)
            })
        };

        let _ = EGL.set(EglShared {
            display,
            context,
            glow,
            create_image,
            destroy_image,
            export_query,
            export,
            image_target_texture,
            make_current,
        });
        log::info!("init_egl: EGL dma_buf sharing ready");
    }
}

/// A wgpu GL texture shareable cross-process via EGL DMA-BUF.
pub struct SharedTexture {
    texture: wgpu::Texture,
    view: wgpu::TextureView,
    surface_id: u32,
    width: u32,
    height: u32,
    /// Owned DMA-BUF fd (creator side). None on the importing side.
    dmabuf_fd: Option<OwnedFd>,
    stride: u32,
    offset: u32,
    fourcc: u32,
    modifier: u64,
    /// EGLImage kept alive for the imported texture's lifetime (importer side).
    egl_image: EglImage,
}

impl SharedTexture {
    /// Create a renderable texture and export it as a DMA-BUF (app side).
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let surface_id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        let usage = wgpu::TextureUsages::RENDER_ATTACHMENT
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_SRC;
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("shared_gl_texture"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage,
            view_formats: &[],
        });
        let view = texture.create_view(&Default::default());

        match export_texture(&texture) {
            Ok((fd, stride, offset, fourcc, modifier)) => {
                log::debug!("dma_buf export OK: {width}x{height} stride={stride} fourcc={fourcc:#x} mod={modifier:#x}");
                Ok(Self {
                    texture, view, surface_id, width, height,
                    dmabuf_fd: Some(fd), stride, offset, fourcc, modifier,
                    egl_image: std::ptr::null_mut(),
                })
            }
            Err(e) => {
                log::warn!("EGL dma_buf export failed ({e}); surface won't be shared");
                Ok(Self {
                    texture, view, surface_id, width, height,
                    dmabuf_fd: None, stride: 0, offset: 0, fourcc: 0, modifier: 0,
                    egl_image: std::ptr::null_mut(),
                })
            }
        }
    }

    /// Import a DMA-BUF as a texture (compositor side).
    pub fn from_dmabuf(
        device: &wgpu::Device,
        fd: i32,
        stride: u32,
        offset: u32,
        fourcc: u32,
        modifier: u64,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let usage = wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_SRC;
        Self::import_with_usage(device, fd, stride, offset, fourcc, modifier, width, height, format, usage)
    }

    /// Import a DMA-BUF as a RENDER TARGET (for KMS scanout: render into a gbm bo).
    #[allow(clippy::too_many_arguments)]
    pub fn from_dmabuf_render(
        device: &wgpu::Device,
        fd: i32,
        stride: u32,
        offset: u32,
        fourcc: u32,
        modifier: u64,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
    ) -> Result<Self, String> {
        let usage = wgpu::TextureUsages::RENDER_ATTACHMENT
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_DST
            | wgpu::TextureUsages::COPY_SRC; // readback for SIGUSR1 screen dump
        Self::import_with_usage(device, fd, stride, offset, fourcc, modifier, width, height, format, usage)
    }

    #[allow(clippy::too_many_arguments)]
    fn import_with_usage(
        device: &wgpu::Device,
        fd: i32,
        stride: u32,
        offset: u32,
        fourcc: u32,
        modifier: u64,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
        usage: wgpu::TextureUsages,
    ) -> Result<Self, String> {
        let surface_id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        let (texture, egl_image) =
            import_dmabuf(device, fd, stride, offset, fourcc, modifier, width, height, format, usage)?;
        let view = texture.create_view(&Default::default());
        Ok(Self {
            texture, view, surface_id, width, height,
            dmabuf_fd: None, stride, offset, fourcc, modifier, egl_image,
        })
    }

    /// Dup the DMA-BUF fd + return its layout for SCM_RIGHTS transfer.
    /// Caller closes the fd after sendmsg.
    pub fn export_dmabuf(&self) -> Result<(i32, u32, u32, u32, u64), String> {
        match &self.dmabuf_fd {
            Some(fd) => {
                let raw = unsafe { libc::dup(fd.as_raw_fd()) };
                if raw < 0 {
                    Err("dup() failed on DMA-BUF fd".into())
                } else {
                    Ok((raw, self.stride, self.offset, self.fourcc, self.modifier))
                }
            }
            None => Err("No DMA-BUF fd (export unavailable)".into()),
        }
    }

    pub fn export_fd(&self) -> Result<i32, String> {
        self.export_dmabuf().map(|(fd, ..)| fd)
    }

    pub fn iosurface_id(&self) -> u32 { self.surface_id }
    pub fn surface_id(&self) -> u32 { self.surface_id }
    pub fn mach_port(&self) -> u32 { 0 }
    pub fn texture(&self) -> &wgpu::Texture { &self.texture }
    pub fn view(&self) -> &wgpu::TextureView { &self.view }
    pub fn width(&self) -> u32 { self.width }
    pub fn height(&self) -> u32 { self.height }

    pub fn into_texture(self) -> wgpu::Texture {
        let texture = unsafe { std::ptr::read(&self.texture) };
        std::mem::forget(self);
        texture
    }

    // -- macOS-only API, unavailable on Linux --
    pub fn from_id(_: &wgpu::Device, _: u32, _: u32, _: u32, _: wgpu::TextureFormat) -> Result<Self, String> {
        Err("SharedTexture::from_id not available on Linux; use from_dmabuf".into())
    }
    pub fn from_mach_port(_: &wgpu::Device, _: u32, _: u32, _: u32, _: wgpu::TextureFormat) -> Result<Self, String> {
        Err("Mach ports not available on Linux".into())
    }
}

impl Drop for SharedTexture {
    fn drop(&mut self) {
        if !self.egl_image.is_null() {
            if let Some(egl) = EGL.get() {
                unsafe { (egl.destroy_image)(egl.display, self.egl_image) };
            }
        }
    }
}

/// Pull the raw GL texture name out of a wgpu texture.
fn gl_texture_name(texture: &wgpu::Texture) -> Result<u32, String> {
    unsafe {
        let hal = texture
            .as_hal::<wgpu_hal::gles::Api>()
            .ok_or("texture is not a GL texture")?;
        match &hal.inner {
            wgpu_hal::gles::TextureInner::Texture { raw, .. } => Ok(raw.0.get()),
            _ => Err("GL texture is not a plain 2D texture".into()),
        }
    }
}

/// Wrap a GL texture as an EGLImage and export it as a DMA-BUF.
/// Returns (fd, stride, offset, fourcc, modifier).
fn export_texture(texture: &wgpu::Texture) -> Result<(OwnedFd, u32, u32, u32, u64), String> {
    let egl = EGL.get().ok_or("EGL not initialized (init_egl not called)")?;
    let name = gl_texture_name(texture)?;
    unsafe {
        egl.make_current();
        // Flush so the rendered contents are visible through the DMA-BUF.
        egl.glow.flush();

        let attribs = [EGL_IMAGE_PRESERVED_KHR, EGL_TRUE as i32, EGL_NONE];
        let image = (egl.create_image)(
            egl.display,
            egl.context,
            EGL_GL_TEXTURE_2D,
            name as usize as EglClientBuffer,
            attribs.as_ptr(),
        );
        if image.is_null() {
            return Err("eglCreateImageKHR(GL_TEXTURE_2D) returned EGL_NO_IMAGE".into());
        }

        let mut fourcc = 0i32;
        let mut num_planes = 0i32;
        let mut modifier = 0u64;
        if (egl.export_query)(egl.display, image, &mut fourcc, &mut num_planes, &mut modifier)
            != EGL_TRUE
        {
            (egl.destroy_image)(egl.display, image);
            return Err("eglExportDMABUFImageQueryMESA failed".into());
        }

        let mut fd = -1i32;
        let mut stride = 0i32;
        let mut offset = 0i32;
        if (egl.export)(egl.display, image, &mut fd, &mut stride, &mut offset) != EGL_TRUE {
            (egl.destroy_image)(egl.display, image);
            return Err("eglExportDMABUFImageMESA failed".into());
        }
        // The exported fd holds an independent reference to the buffer; the
        // image is no longer needed.
        (egl.destroy_image)(egl.display, image);

        if fd < 0 {
            return Err("export produced no fd".into());
        }
        Ok((OwnedFd::from_raw_fd(fd), stride as u32, offset as u32, fourcc as u32, modifier))
    }
}

/// Import a DMA-BUF fd as a GL texture wrapped into a wgpu texture.
#[allow(clippy::too_many_arguments)]
#[allow(clippy::too_many_arguments)]
fn import_dmabuf(
    device: &wgpu::Device,
    fd: i32,
    stride: u32,
    offset: u32,
    fourcc: u32,
    modifier: u64,
    width: u32,
    height: u32,
    format: wgpu::TextureFormat,
    usage: wgpu::TextureUsages,
) -> Result<(wgpu::Texture, EglImage), String> {
    let egl = EGL.get().ok_or("EGL not initialized (init_egl not called)")?;
    unsafe {
        egl.make_current();
        let attribs = [
            EGL_WIDTH, width as i32,
            EGL_HEIGHT, height as i32,
            EGL_LINUX_DRM_FOURCC_EXT, fourcc as i32,
            EGL_DMA_BUF_PLANE0_FD_EXT, fd,
            EGL_DMA_BUF_PLANE0_OFFSET_EXT, offset as i32,
            EGL_DMA_BUF_PLANE0_PITCH_EXT, stride as i32,
            EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, (modifier & 0xffff_ffff) as i32,
            EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, (modifier >> 32) as i32,
            EGL_NONE,
        ];
        let image = (egl.create_image)(
            egl.display,
            std::ptr::null_mut(), // EGL_NO_CONTEXT
            EGL_LINUX_DMA_BUF_EXT,
            std::ptr::null_mut(),
            attribs.as_ptr(),
        );
        if image.is_null() {
            return Err("eglCreateImageKHR(LINUX_DMA_BUF) returned EGL_NO_IMAGE".into());
        }

        // Bind the EGLImage to a fresh GL texture.
        let gl = &egl.glow;
        let tex = gl
            .create_texture()
            .map_err(|e| format!("glGenTextures failed: {e}"))?;
        gl.bind_texture(GL_TEXTURE_2D, Some(tex));
        (egl.image_target_texture)(GL_TEXTURE_2D, image);
        gl.tex_parameter_i32(GL_TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
        gl.tex_parameter_i32(GL_TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
        gl.tex_parameter_i32(GL_TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::CLAMP_TO_EDGE as i32);
        gl.tex_parameter_i32(GL_TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::CLAMP_TO_EDGE as i32);
        gl.bind_texture(GL_TEXTURE_2D, None);

        // Wrap the GL texture name into a wgpu texture via the gles HAL.
        let hal_desc = wgpu_hal::TextureDescriptor {
            label: Some("dmabuf_import"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage: to_hal_usage(usage),
            memory_flags: wgpu_hal::MemoryFlags::empty(),
            view_formats: vec![],
        };
        let hal_device = device
            .as_hal::<wgpu_hal::gles::Api>()
            .ok_or("compositor device is not GL")?;
        let hal_texture = hal_device.texture_from_raw(
            std::num::NonZeroU32::new(tex.0.get()).ok_or("zero GL texture name")?,
            &hal_desc,
            None,
        );
        drop(hal_device);
        let wgpu_desc = wgpu::TextureDescriptor {
            label: Some("dmabuf_import"),
            size: wgpu::Extent3d { width, height, depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage,
            view_formats: &[],
        };
        let texture = device.create_texture_from_hal::<wgpu_hal::gles::Api>(hal_texture, &wgpu_desc);
        Ok((texture, image))
    }
}

fn to_hal_usage(usage: wgpu::TextureUsages) -> wgpu_types::TextureUses {
    let mut flags = wgpu_types::TextureUses::empty();
    if usage.contains(wgpu::TextureUsages::TEXTURE_BINDING) {
        flags |= wgpu_types::TextureUses::RESOURCE;
    }
    if usage.contains(wgpu::TextureUsages::COPY_SRC) {
        flags |= wgpu_types::TextureUses::COPY_SRC;
    }
    if usage.contains(wgpu::TextureUsages::COPY_DST) {
        flags |= wgpu_types::TextureUses::COPY_DST;
    }
    if usage.contains(wgpu::TextureUsages::RENDER_ATTACHMENT) {
        flags |= wgpu_types::TextureUses::COLOR_TARGET;
    }
    flags
}
