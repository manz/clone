// Composite a window's offscreen texture onto the screen.
// Each window is a textured quad with SDF rounded-corner mask.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct WindowInstance {
    @location(0) rect: vec4<f32>,       // x, y, w, h in screen pixels (expanded for shadow)
    @location(1) corner_radius: f32,
    @location(2) opacity: f32,
    @location(3) shadow_expand: f32,
    @location(4) _pad1: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) local_pos: vec2<f32>,
    @location(2) rect_size: vec2<f32>,
    @location(3) corner_radius: f32,
    @location(4) opacity: f32,
    @location(5) shadow_expand: f32,
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

    // Original window size (before shadow expansion)
    let orig_size = vec2<f32>(
        instance.rect.z - instance.shadow_expand * 2.0,
        instance.rect.w - instance.shadow_expand * 2.0,
    );

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    // UV for texture sampling: map expanded quad back to original window
    let tex_uv = (quad * vec2<f32>(instance.rect.z, instance.rect.w) - vec2<f32>(instance.shadow_expand)) / orig_size;
    out.uv = tex_uv;
    // local_pos relative to original window (not expanded)
    out.local_pos = local - vec2<f32>(instance.shadow_expand);
    out.rect_size = orig_size;
    out.corner_radius = instance.corner_radius;
    out.opacity = instance.opacity;
    out.shadow_expand = instance.shadow_expand;
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

    // Shadow: soft falloff outside the window bounds
    let shadow_blur = 20.0;
    let shadow_offset = vec2<f32>(0.0, 6.0);
    let shadow_dist = sdf_rounded_rect(centered - shadow_offset, half_size, r);
    let shadow_alpha = (1.0 - smoothstep(0.0, shadow_blur, shadow_dist)) * 0.18 * in.opacity;

    // Sample window texture — clamp UV to valid [0,1] range
    let clamped_uv = clamp(in.uv, vec2<f32>(0.0), vec2<f32>(1.0));
    let color = textureSample(window_texture, window_sampler, clamped_uv);

    // Composite: shadow underneath, then window on top
    let window_alpha = color.a * mask * in.opacity;
    let combined_alpha = window_alpha + shadow_alpha * (1.0 - window_alpha);

    // Premultiplied alpha compositing — output premultiplied RGB
    let combined_rgb = color.rgb * window_alpha + vec3<f32>(0.0) * shadow_alpha * (1.0 - window_alpha);

    return vec4<f32>(combined_rgb, combined_alpha);
}
