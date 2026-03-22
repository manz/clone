/// GPU-facing data structures.

#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub struct RectVertex {
    pub position: [f32; 2],
    pub uv: [f32; 2],
}

#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub struct RectInstance {
    pub rect: [f32; 4],   // x, y, w, h
    pub color: [f32; 4],  // r, g, b, a
    pub radius: f32,
    pub _pad: [f32; 3],
}

#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Uniforms {
    pub screen_size: [f32; 2],
    pub _pad: [f32; 2],
}

impl RectVertex {
    pub const LAYOUT: wgpu::VertexBufferLayout<'static> = wgpu::VertexBufferLayout {
        array_stride: std::mem::size_of::<RectVertex>() as u64,
        step_mode: wgpu::VertexStepMode::Vertex,
        attributes: &wgpu::vertex_attr_array![0 => Float32x2, 1 => Float32x2],
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rect_vertex_size() {
        assert_eq!(std::mem::size_of::<RectVertex>(), 16);
    }

    #[test]
    fn rect_instance_size() {
        assert_eq!(std::mem::size_of::<RectInstance>(), 48);
    }

    #[test]
    fn uniforms_size() {
        assert_eq!(std::mem::size_of::<Uniforms>(), 16);
    }

    #[test]
    fn bytemuck_cast_rect_vertex() {
        let v = RectVertex {
            position: [1.0, 2.0],
            uv: [0.0, 1.0],
        };
        let bytes: &[u8] = bytemuck::bytes_of(&v);
        assert_eq!(bytes.len(), 16);
    }
}

/// Clamp a scissor rect to fit within the render target bounds.
/// Returns None if the clamped rect has zero area.
pub fn clamp_scissor(
    scissor: Option<(u32, u32, u32, u32)>,
    target_width: u32,
    target_height: u32,
) -> Option<(u32, u32, u32, u32)> {
    scissor.and_then(|(sx, sy, sw, sh)| {
        let cx = sx.min(target_width);
        let cy = sy.min(target_height);
        let cw = sw.min(target_width.saturating_sub(cx));
        let ch = sh.min(target_height.saturating_sub(cy));
        if cw == 0 || ch == 0 { None } else { Some((cx, cy, cw, ch)) }
    })
}
