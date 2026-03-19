// Text rendering via glyph atlas.
// Each glyph quad samples from a texture atlas containing rasterized glyphs.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct GlyphInstance {
    @location(0) rect: vec4<f32>,      // x, y, w, h in screen pixels
    @location(1) uv_rect: vec4<f32>,   // u, v, uw, vh in atlas [0..1]
    @location(2) color: vec4<f32>,     // text color
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var atlas_texture: texture_2d<f32>;
@group(0) @binding(2) var atlas_sampler: sampler;

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
    instance: GlyphInstance,
) -> VertexOutput {
    let quad = QUAD_POS[vertex_index];

    // Screen position
    let pixel = vec2<f32>(instance.rect.x, instance.rect.y) + quad * vec2<f32>(instance.rect.z, instance.rect.w);
    let ndc = vec2<f32>(
        pixel.x / uniforms.screen_size.x * 2.0 - 1.0,
        1.0 - pixel.y / uniforms.screen_size.y * 2.0,
    );

    // Atlas UV
    let uv = vec2<f32>(instance.uv_rect.x, instance.uv_rect.y) + quad * vec2<f32>(instance.uv_rect.z, instance.uv_rect.w);

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    out.uv = uv;
    out.color = instance.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let alpha = textureSample(atlas_texture, atlas_sampler, in.uv).r;
    return vec4<f32>(in.color.rgb, in.color.a * alpha);
}
