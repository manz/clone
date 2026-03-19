// Solid rectangle — instanced quad pipeline.
// Each instance is a rect (x, y, w, h) with color.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct RectInstance {
    @location(2) rect: vec4<f32>,      // x, y, w, h
    @location(3) color: vec4<f32>,     // r, g, b, a
    @location(4) radius: f32,
    @location(5) _pad0: f32,
    @location(6) _pad1: f32,
    @location(7) _pad2: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) local_pos: vec2<f32>,  // position within rect [0..w, 0..h]
    @location(2) rect_size: vec2<f32>,  // w, h
    @location(3) radius: f32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;

// Unit quad: positions 0..1
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

    // Local position within the rect
    let local = quad * vec2<f32>(instance.rect.z, instance.rect.w);

    // Screen pixel position
    let pixel = vec2<f32>(instance.rect.x, instance.rect.y) + local;

    // Convert to NDC: [0, screen_size] -> [-1, 1], Y flipped
    let ndc = vec2<f32>(
        pixel.x / uniforms.screen_size.x * 2.0 - 1.0,
        1.0 - pixel.y / uniforms.screen_size.y * 2.0,
    );

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    out.color = instance.color;
    out.local_pos = local;
    out.rect_size = vec2<f32>(instance.rect.z, instance.rect.w);
    out.radius = instance.radius;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return in.color;
}
