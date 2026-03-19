// Composite a window's offscreen texture onto the screen.
// Each window is a textured quad with SDF rounded-corner mask.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct WindowInstance {
    @location(0) rect: vec4<f32>,       // x, y, w, h in screen pixels
    @location(1) corner_radius: f32,
    @location(2) opacity: f32,
    @location(3) _pad0: f32,
    @location(4) _pad1: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) local_pos: vec2<f32>,
    @location(2) rect_size: vec2<f32>,
    @location(3) corner_radius: f32,
    @location(4) opacity: f32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var window_texture: texture_2d<f32>;
@group(0) @binding(2) var window_sampler: sampler;

var<private> QUAD_POS: array<vec2<f32>, 6> = array<vec2<f32>, 6>(
    vec2<f32>(0.0, 0.0),
    vec2<f32>(1.0, 0.0),
    vec2<f32>(0.0, 1.0),
    vec2<f32>(1.0, 0.0),
    vec2<f32>(1.0, 1.0),
    vec2<f32>(0.0, 1.0),
);

@vertex
fn vs_main(
    @builtin(vertex_index) vertex_index: u32,
    instance: WindowInstance,
) -> VertexOutput {
    let quad = QUAD_POS[vertex_index];
    let local = quad * vec2<f32>(instance.rect.z, instance.rect.w);
    let pixel = vec2<f32>(instance.rect.x, instance.rect.y) + local;
    let ndc = vec2<f32>(
        pixel.x / uniforms.screen_size.x * 2.0 - 1.0,
        1.0 - pixel.y / uniforms.screen_size.y * 2.0,
    );

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    out.uv = quad;
    out.local_pos = local;
    out.rect_size = vec2<f32>(instance.rect.z, instance.rect.w);
    out.corner_radius = instance.corner_radius;
    out.opacity = instance.opacity;
    return out;
}

fn sdf_rounded_rect(p: vec2<f32>, b: vec2<f32>, r: f32) -> f32 {
    let q = abs(p) - b + vec2<f32>(r, r);
    return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let half_size = in.rect_size * 0.5;
    let centered = in.local_pos - half_size;
    let max_r = min(half_size.x, half_size.y);
    let r = min(in.corner_radius, max_r);

    let dist = sdf_rounded_rect(centered, half_size, r);
    let mask = 1.0 - smoothstep(-0.5, 0.5, dist);

    // Sample window texture
    let color = textureSample(window_texture, window_sampler, in.uv);

    return vec4<f32>(color.rgb, color.a * mask * in.opacity);
}
