// Fullscreen wallpaper — aspect-fill textured quad.

struct Uniforms {
    screen_size: vec2<f32>,
    tex_size: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var wallpaper: texture_2d<f32>;
@group(0) @binding(2) var wallpaper_sampler: sampler;

var<private> FULLSCREEN: array<vec2<f32>, 6> = array<vec2<f32>, 6>(
    vec2<f32>(0.0, 0.0),
    vec2<f32>(1.0, 0.0),
    vec2<f32>(0.0, 1.0),
    vec2<f32>(1.0, 0.0),
    vec2<f32>(1.0, 1.0),
    vec2<f32>(0.0, 1.0),
);

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOutput {
    let quad = FULLSCREEN[idx];
    let ndc = vec2<f32>(quad.x * 2.0 - 1.0, 1.0 - quad.y * 2.0);

    // Aspect-fill UV: scale UV so image covers screen without stretching
    let screen_aspect = uniforms.screen_size.x / uniforms.screen_size.y;
    let tex_aspect = uniforms.tex_size.x / uniforms.tex_size.y;

    var uv = quad;
    if screen_aspect > tex_aspect {
        // Screen wider than image — crop top/bottom
        let scale = tex_aspect / screen_aspect;
        uv.y = (quad.y - 0.5) * scale + 0.5;
    } else {
        // Screen taller than image — crop left/right
        let scale = screen_aspect / tex_aspect;
        uv.x = (quad.x - 0.5) * scale + 0.5;
    }

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    out.uv = uv;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return textureSample(wallpaper, wallpaper_sampler, in.uv);
}
