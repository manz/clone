// Icon rendering: textured quad sampling from an RGBA texture.
// Each icon has its own texture + bind group.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct IconInstance {
    @location(0) rect: vec4<f32>,   // x, y, w, h in screen pixels
    @location(1) z: f32,            // depth
    @location(2) _pad0: f32,
    @location(3) _pad1: f32,
    @location(4) _pad2: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(1) @binding(0) var icon_texture: texture_2d<f32>;
@group(1) @binding(1) var icon_sampler: sampler;

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
    instance: IconInstance,
) -> VertexOutput {
    let quad = QUAD_POS[vertex_index];

    let pixel = vec2<f32>(instance.rect.x, instance.rect.y) + quad * vec2<f32>(instance.rect.z, instance.rect.w);
    let ndc = vec2<f32>(
        pixel.x / uniforms.screen_size.x * 2.0 - 1.0,
        1.0 - pixel.y / uniforms.screen_size.y * 2.0,
    );

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, instance.z, 1.0);
    out.uv = quad;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let color = textureSample(icon_texture, icon_sampler, in.uv);
    if color.a < 0.01 {
        discard;
    }
    return color;
}
