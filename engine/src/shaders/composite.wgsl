// Composite shader — blends a blurred background with a tint overlay
// through an SDF rounded-rect mask.

struct CompositeUniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct CompositeInstance {
    @location(0) rect: vec4<f32>,     // x, y, w, h
    @location(1) tint: vec4<f32>,     // tint color (overlaid on blur)
    @location(2) params: vec4<f32>,   // radius, blur_amount, 0, 0
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) tint: vec4<f32>,
    @location(1) local_pos: vec2<f32>,
    @location(2) rect_size: vec2<f32>,
    @location(3) radius: f32,
    @location(4) screen_uv: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: CompositeUniforms;
@group(0) @binding(1) var blurred_texture: texture_2d<f32>;
@group(0) @binding(2) var blur_sampler: sampler;

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
    instance: CompositeInstance,
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
    out.tint = instance.tint;
    out.local_pos = local;
    out.rect_size = vec2<f32>(instance.rect.z, instance.rect.w);
    out.radius = instance.params.x;
    out.screen_uv = vec2<f32>(
        pixel.x / uniforms.screen_size.x,
        pixel.y / uniforms.screen_size.y,
    );
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
    let mask = 1.0 - smoothstep(-0.5, 0.5, dist);

    // Sample blurred background
    let blurred = textureSample(blurred_texture, blur_sampler, in.screen_uv);

    // Blend: blurred background + tint overlay
    let combined = blurred.rgb * (1.0 - in.tint.a) + in.tint.rgb * in.tint.a;

    return vec4<f32>(combined, mask);
}
