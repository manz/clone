// Genie minimize effect: deforms window texture using a subdivided mesh.
// Bottom rows collapse toward the dock icon first, upper rows follow with delay.

struct Uniforms {
    screen_size: vec2<f32>,
    _pad: vec2<f32>,
}

struct WindowInstance {
    @location(0) rect: vec4<f32>,       // x, y, w, h (expanded for shadow)
    @location(1) corner_radius: f32,
    @location(2) opacity: f32,
    @location(3) shadow_expand: f32,
    @location(4) content_u_max: f32,
    @location(5) content_v_max: f32,
    @location(6) genie_progress: f32,
    @location(7) genie_target_x: f32,   // dock icon center X (physical px)
    @location(8) genie_target_y: f32,   // dock icon top Y (physical px)
    @location(9) genie_target_w: f32,   // dock icon width (physical px)
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) local_pos: vec2<f32>,
    @location(2) rect_size: vec2<f32>,
    @location(3) corner_radius: f32,
    @location(4) opacity: f32,
    @location(5) shadow_expand: f32,
    @location(6) genie_progress: f32,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var window_texture: texture_2d<f32>;
@group(0) @binding(2) var window_sampler: sampler;

const ROWS: u32 = 32u;

// Quad vertex positions for each of 6 verts in a cell
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
    let row = vertex_index / 6u;
    let vert_in_cell = vertex_index % 6u;
    let cell_uv = QUAD_POS[vert_in_cell];

    // Normalized UV across full window: u in [0,1], v in [0,1]
    let u = cell_uv.x;
    let v = (f32(row) + cell_uv.y) / f32(ROWS);

    // Original window rect (without shadow expansion)
    let orig_x = instance.rect.x + instance.shadow_expand;
    let orig_y = instance.rect.y + instance.shadow_expand;
    let orig_w = instance.rect.z - instance.shadow_expand * 2.0;
    let orig_h = instance.rect.w - instance.shadow_expand * 2.0;

    // Per-row staggered progress: bottom (v=1) leads, top (v=0) lags
    let delay = (1.0 - v) * 0.6;
    let raw = clamp((instance.genie_progress - delay) / max(1.0 - delay, 0.001), 0.0, 1.0);
    // Smoothstep easing per row
    let eased = raw * raw * (3.0 - 2.0 * raw);

    // Original pixel position for this vertex
    let win_center_x = orig_x + orig_w * 0.5;

    // Horizontal: pinch from window width toward dock icon width
    let current_width = mix(orig_w, instance.genie_target_w, eased);
    let current_center_x = mix(win_center_x, instance.genie_target_x, eased);
    let px_x = current_center_x + (u - 0.5) * current_width;

    // Vertical: slide each row toward dock icon y
    let orig_row_y = orig_y + v * orig_h;
    let px_y = mix(orig_row_y, instance.genie_target_y, eased);

    // Convert to NDC
    let ndc = vec2<f32>(
        px_x / uniforms.screen_size.x * 2.0 - 1.0,
        1.0 - px_y / uniforms.screen_size.y * 2.0,
    );

    // Texture UV scaled to content region
    let tex_uv = vec2<f32>(u * instance.content_u_max, v * instance.content_v_max);

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    out.uv = tex_uv;
    // local_pos in original window space (for SDF mask)
    out.local_pos = vec2<f32>(u * orig_w, v * orig_h);
    out.rect_size = vec2<f32>(orig_w, orig_h);
    out.corner_radius = instance.corner_radius;
    out.opacity = instance.opacity;
    out.shadow_expand = instance.shadow_expand;
    out.genie_progress = instance.genie_progress;
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

    // Shadow fades out during genie animation
    var shadow_alpha = 0.0;
    if in.shadow_expand > 0.0 {
        let shadow_fade = 1.0 - in.genie_progress;
        let shadow_blur = 20.0;
        let shadow_offset = vec2<f32>(0.0, 6.0);
        let shadow_dist = sdf_rounded_rect(centered - shadow_offset, half_size, r);
        shadow_alpha = (1.0 - smoothstep(0.0, shadow_blur, shadow_dist)) * 0.18 * in.opacity * shadow_fade;
    }

    let clamped_uv = clamp(in.uv, vec2<f32>(0.0), vec2<f32>(1.0));
    let color = textureSample(window_texture, window_sampler, clamped_uv);

    let window_alpha = color.a * mask * in.opacity;
    let combined_alpha = window_alpha + shadow_alpha * (1.0 - window_alpha);
    let combined_rgb = color.rgb * window_alpha + vec3<f32>(0.0) * shadow_alpha * (1.0 - window_alpha);

    return vec4<f32>(combined_rgb, combined_alpha);
}
