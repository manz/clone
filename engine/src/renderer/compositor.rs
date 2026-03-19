/// Multi-pass compositor for glassmorphism effects.
///
/// Pipeline:
/// 1. Render opaque background to offscreen texture
/// 2. Blur that texture via dual-Kawase (BlurPipeline)
/// 3. Composite blurred texture through SDF rounded-rect mask + tint
/// 4. Draw foreground UI on top

use crate::commands::{RenderCommand, RgbaColor};
use crate::renderer::blur::BlurPipeline;

/// Identifies which commands need blur effects applied.
pub struct BlurRegion {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
    pub radius: f32,
    pub blur: f32,
    pub tint: RgbaColor,
}

/// Extract blur regions from the command stream.
pub fn extract_blur_regions(commands: &[RenderCommand]) -> Vec<BlurRegion> {
    let mut regions = Vec::new();
    for cmd in commands {
        if let RenderCommand::BlurRect {
            x,
            y,
            w,
            h,
            radius,
            blur,
            tint,
        } = cmd
        {
            regions.push(BlurRegion {
                x: *x,
                y: *y,
                w: *w,
                h: *h,
                radius: *radius,
                blur: *blur,
                tint: tint.clone(),
            });
        }
    }
    regions
}

/// Compositor state — owns the blur pipeline and offscreen textures.
pub struct Compositor {
    pub blur_pipeline: BlurPipeline,
    offscreen_texture: Option<wgpu::Texture>,
    offscreen_view: Option<wgpu::TextureView>,
    width: u32,
    height: u32,
}

impl Compositor {
    pub fn new(device: &wgpu::Device, surface_format: wgpu::TextureFormat) -> Self {
        Self {
            blur_pipeline: BlurPipeline::new(device, surface_format),
            offscreen_texture: None,
            offscreen_view: None,
            width: 0,
            height: 0,
        }
    }

    pub fn resize(
        &mut self,
        device: &wgpu::Device,
        width: u32,
        height: u32,
        surface_format: wgpu::TextureFormat,
    ) {
        if width == self.width && height == self.height {
            return;
        }
        self.width = width;
        self.height = height;

        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("offscreen_scene"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: surface_format,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT
                | wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        });

        self.offscreen_view = Some(texture.create_view(&Default::default()));
        self.offscreen_texture = Some(texture);

        self.blur_pipeline.resize(device, width, height, surface_format);
    }

    pub fn offscreen_view(&self) -> Option<&wgpu::TextureView> {
        self.offscreen_view.as_ref()
    }

    /// Copy the offscreen texture to the blur pipeline's input mip[0].
    pub fn copy_scene_to_blur(&self, encoder: &mut wgpu::CommandEncoder) {
        if let (Some(src), Some(dst)) = (&self.offscreen_texture, self.blur_pipeline.scene_texture()) {
            encoder.copy_texture_to_texture(
                src.as_image_copy(),
                dst.as_image_copy(),
                wgpu::Extent3d {
                    width: self.width,
                    height: self.height,
                    depth_or_array_layers: 1,
                },
            );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_blur_regions_empty() {
        let regions = extract_blur_regions(&[]);
        assert!(regions.is_empty());
    }

    #[test]
    fn extract_blur_regions_filters_correctly() {
        let white = RgbaColor {
            r: 1.0,
            g: 1.0,
            b: 1.0,
            a: 0.3,
        };
        let commands = vec![
            RenderCommand::Rect {
                x: 0.0,
                y: 0.0,
                w: 100.0,
                h: 100.0,
                color: white.clone(),
            },
            RenderCommand::BlurRect {
                x: 10.0,
                y: 10.0,
                w: 200.0,
                h: 30.0,
                radius: 8.0,
                blur: 20.0,
                tint: white.clone(),
            },
            RenderCommand::PopClip,
        ];
        let regions = extract_blur_regions(&commands);
        assert_eq!(regions.len(), 1);
        assert_eq!(regions[0].blur, 20.0);
        assert_eq!(regions[0].x, 10.0);
    }
}
