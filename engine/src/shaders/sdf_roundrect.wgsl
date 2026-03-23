// SDF rounded rectangle — same vertex shader as rect, but fragment uses SDF for smooth corners.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct RectInstance {
    @location(2) rect: vec4<f32>,
    @location(3) color: vec4<f32>,
    @location(4) radius: f32,
    @location(5) z: f32,               // depth: 0.0 = front, 1.0 = back
    @location(6) _pad1: f32,
    @location(7) _pad2: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) local_pos: vec2<f32>,
    @location(2) rect_size: vec2<f32>,
    @location(3) radius: f32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;

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
    instance: RectInstance,
) -> VertexOutput {
    let quad = QUAD_POS[vertex_index];
    let local = quad * vec2<f32>(instance.rect.z, instance.rect.w);
    let pixel = vec2<f32>(instance.rect.x, instance.rect.y) + local;
    let ndc = vec2<f32>(
        pixel.x / uniforms.screen_size.x * 2.0 - 1.0,
        1.0 - pixel.y / uniforms.screen_size.y * 2.0,
    );

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, instance.z, 1.0);
    out.color = instance.color;
    out.local_pos = local;
    out.rect_size = vec2<f32>(instance.rect.z, instance.rect.w);
    out.radius = instance.radius;
    return out;
}

// SDF for a rounded rectangle centered at origin with half-size `b` and corner radius `r`
fn sdf_rounded_rect(p: vec2<f32>, b: vec2<f32>, r: f32) -> f32 {
    let q = abs(p) - b + vec2<f32>(r, r);
    return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    // Convert local_pos to centered coordinates
    let half_size = in.rect_size * 0.5;
    let centered = in.local_pos - half_size;

    // Clamp radius so it doesn't exceed half the smallest dimension
    let max_radius = min(half_size.x, half_size.y);
    let r = min(in.radius, max_radius);

    let dist = sdf_rounded_rect(centered, half_size, r);

    // Anti-aliased edge: 1px smooth transition
    let alpha = 1.0 - smoothstep(-0.5, 0.5, dist);

    return vec4<f32>(in.color.rgb, in.color.a * alpha);
}
