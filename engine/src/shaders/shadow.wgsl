// Drop shadow — Gaussian approximation via SDF.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct ShadowInstance {
    @location(0) rect: vec4<f32>,     // x, y, w, h
    @location(1) color: vec4<f32>,    // shadow color with alpha
    @location(2) params: vec4<f32>,   // radius, blur, offset_x, offset_y
    @location(3) z: f32,             // depth: 0.0 = front, 1.0 = back
    @location(4) _pad0: f32,
    @location(5) _pad1: f32,
    @location(6) _pad2: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) local_pos: vec2<f32>,
    @location(2) rect_size: vec2<f32>,
    @location(3) radius: f32,
    @location(4) blur: f32,
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
    instance: ShadowInstance,
) -> VertexOutput {
    let quad = QUAD_POS[vertex_index];
    let blur_expand = instance.params.y * 1.5; // expand quad to cover blur spread

    let expanded_size = vec2<f32>(
        instance.rect.z + blur_expand * 2.0,
        instance.rect.w + blur_expand * 2.0,
    );
    let offset = vec2<f32>(instance.params.z, instance.params.w);
    let origin = vec2<f32>(instance.rect.x, instance.rect.y) + offset - vec2<f32>(blur_expand, blur_expand);

    let local = quad * expanded_size;
    let pixel = origin + local;
    let ndc = vec2<f32>(
        pixel.x / uniforms.screen_size.x * 2.0 - 1.0,
        1.0 - pixel.y / uniforms.screen_size.y * 2.0,
    );

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, instance.z, 1.0);
    out.color = instance.color;
    out.local_pos = local - vec2<f32>(blur_expand, blur_expand); // relative to rect origin
    out.rect_size = vec2<f32>(instance.rect.z, instance.rect.w);
    out.radius = instance.params.x;
    out.blur = instance.params.y;
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
    let r = min(in.radius, max_r);

    let dist = sdf_rounded_rect(centered, half_size, r);

    // Approximate Gaussian falloff using smoothstep
    let sigma = in.blur * 0.5;
    let alpha = 1.0 - smoothstep(-sigma, sigma * 2.0, dist);

    return vec4<f32>(in.color.rgb, in.color.a * alpha);
}
