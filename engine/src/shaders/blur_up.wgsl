// Dual-Kawase blur — upsample pass.
// Samples 8 points from the lower-resolution texture
// and writes to a double-resolution target.

struct BlurUniforms {
    texel_size: vec2<f32>,  // 1.0 / source_resolution
    _pad: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: BlurUniforms;
@group(0) @binding(1) var source_texture: texture_2d<f32>;
@group(0) @binding(2) var source_sampler: sampler;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

var<private> FULLSCREEN_QUAD: array<vec2<f32>, 6> = array<vec2<f32>, 6>(
    vec2<f32>(-1.0, -1.0),
    vec2<f32>( 1.0, -1.0),
    vec2<f32>(-1.0,  1.0),
    vec2<f32>( 1.0, -1.0),
    vec2<f32>( 1.0,  1.0),
    vec2<f32>(-1.0,  1.0),
);

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    let pos = FULLSCREEN_QUAD[vertex_index];
    var out: VertexOutput;
    out.position = vec4<f32>(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let t = uniforms.texel_size;
    let ht = t * 0.5;

    var color = textureSample(source_texture, source_sampler, in.uv + vec2<f32>(-t.x, 0.0));
    color += textureSample(source_texture, source_sampler, in.uv + vec2<f32>( t.x, 0.0));
    color += textureSample(source_texture, source_sampler, in.uv + vec2<f32>(0.0, -t.y));
    color += textureSample(source_texture, source_sampler, in.uv + vec2<f32>(0.0,  t.y));
    color *= 2.0;

    color += textureSample(source_texture, source_sampler, in.uv + vec2<f32>(-ht.x, -ht.y));
    color += textureSample(source_texture, source_sampler, in.uv + vec2<f32>( ht.x, -ht.y));
    color += textureSample(source_texture, source_sampler, in.uv + vec2<f32>(-ht.x,  ht.y));
    color += textureSample(source_texture, source_sampler, in.uv + vec2<f32>( ht.x,  ht.y));

    return color / 12.0;
}
