shader_type canvas_item;

uniform vec4  u_bg_color: source_color = vec4(0.02, 0.03, 0.03, 1.0); // near-black with slight green bias
uniform vec4  u_grid_color: source_color = vec4(0.35, 0.95, 0.55, 1.0); // terminal-ish green

uniform float u_grid_spacing: hint_range(0.02, 0.50, 0.001) = 0.08; // in warped UV units
uniform float u_grid_thickness: hint_range(0.0005, 0.020, 0.0001) = 0.002;
uniform float u_grid_intensity: hint_range(0.0, 2.0, 0.01) = 0.15;

uniform float u_major_line_every: hint_range(2.0, 10.0, 1.0) = 4.0; // every N lines is "major"
uniform float u_major_boost: hint_range(0.0, 2.0, 0.01) = 0.55; // extra intensity for major lines

uniform float u_horizon_height: hint_range(-0.5, 1.5, 0.01) = 0.15; // where fade starts (screen Y, 0 bottom..1 top)
uniform float u_horizon_fade_strength: hint_range(0.1, 8.0, 0.01) = 8.0; // how quickly it disappears into void

uniform vec2  u_drift_speed = vec2(0.001, 0.003); // slow drift, in grid units/sec

uniform float u_pulse_strength: hint_range(0.0, 0.5, 0.001) = 0.04;
uniform float u_pulse_speed: hint_range(0.0, 2.0, 0.01) = 0.35;

uniform float u_vignette_strength: hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float u_vignette_power: hint_range(0.5, 6.0, 0.01) = 1.65;

uniform float u_grain_strength: hint_range(0.0, 0.15, 0.001) = 0.02;

uniform float u_persp_offset: hint_range(0.02, 2.0, 0.01) = 0.02; // prevents infinity at horizon
uniform float u_persp_scale: hint_range(0.1, 8.0, 0.01) = 1.8; // overall depth scaling

// Cheap hash; good enough for subtle grain.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Returns AA grid lines for a given coordinate pair in "grid space".
float grid_lines(vec2 g, float spacing, float thickness) {
	vec2 cell = g / spacing;
	vec2 a = fract(cell); // 0..1
	vec2 d = min(a, 1.0 - a); // distance to nearest boundary (0 at boundary)

	// Anti-alias width in "cell units"
	vec2 w = fwidth(cell) + vec2(1e-6);

	float lx = 1.0 - smoothstep(thickness / spacing - w.x, thickness / spacing + w.x, d.x);
	float ly = 1.0 - smoothstep(thickness / spacing - w.y, thickness / spacing + w.y, d.y);
	return max(lx, ly);
}

vec2 warp_perspective(vec2 uv_centered) {
	// uv_centered: x,y in [-1..1], where y=-1 is bottom, y=+1 is top
	// Convert to "distance from bottom" in [0..1], where 0 is horizon/top, 1 is bottom/near.
	float z = clamp((1.0 - (-uv_centered.y + 1.0) * 0.5), 0.0, 1.0); // 1 at bottom, 0 at top

	// Projective factor: bigger near horizon => denser lines.
	float p = u_persp_scale / (z + u_persp_offset);

	// Classic floor grid mapping:
	// - X gets scaled by p so verticals converge
	// - Y becomes p so horizontals pack toward horizon
	return vec2(uv_centered.x * p, p);
}

// Vignette centered at screen center.
float vignette(vec2 uv, float strength, float power) {
	vec2 d = uv - vec2(0.5);
	float r = dot(d, d); // 0 at center, ~0.5 at corners
	float v = 1.0 - pow(clamp(r * 2.0, 0.0, 1.0), power);
	return mix(1.0, v, strength);
}

// --- Fragment --------------------------------------------------------------

void fragment() {
	vec2 uv = UV;
	vec3 col = u_bg_color.rgb;

	// Centered coordinates for warping: x in [-1..1], y in [-1..1] with bottom = -1.
	vec2 c = (uv * 2.0) - 1.0;

	// Apply pseudo-perspective warp.
	vec2 w = warp_perspective(c);

	// Slow drift in warped space. Scale drift by spacing so it feels consistent.
	float wrap = u_grid_spacing * max(u_major_line_every, 2.0); // wrap by major-cell size
	vec2 drift = mod(u_drift_speed * TIME, vec2(wrap));
	w += drift;

	// Grid intensity pulse (subtle).
	float pulse = 1.0 + u_pulse_strength * sin(TIME * 6.2831853 * u_pulse_speed);

	// Compute base grid lines.
	float base_grid  = grid_lines(w, u_grid_spacing, u_grid_thickness);

	float major_grid = 0.0;
	if (u_major_boost > 0.001) {
		major_grid = grid_lines(
			w,
			u_grid_spacing * max(u_major_line_every, 2.0),
			u_grid_thickness * 1.25
		);
	}

	// Horizon fade: start fading above u_horizon_height (in screen space).
	// u_horizon_height is in [0..1] where 0 bottom, 1 top.
	float y_from_bottom = uv.y; // 0 top, 1 bottom
	float fade = smoothstep(0.0, 1.0 - u_horizon_height, y_from_bottom);
	fade = pow(clamp(fade, 0.0, 1.0), u_horizon_fade_strength);

	// Additional depth attenuation so "far" grid is dimmer even before fade.
	float depth_dim = clamp(1.0 - (-c.y * 0.5 + 0.5), 0.0, 1.0); // bottom ~1, top ~0
	depth_dim = mix(depth_dim, pow(depth_dim, 1.6), 0.6);

	// Combine grid terms.
	float grid = base_grid + major_grid * u_major_boost;
	// Apply intensity and shaping.
	grid *= u_grid_intensity * pulse;
	grid *= fade;
	grid *= depth_dim;
	// Composite grid
	col += u_grid_color.rgb * grid;

	// Vignette
	col *= vignette(uv, u_vignette_strength, u_vignette_power);

	// Tiny grain (avoid banding; keep subtle).
	float n = hash12(uv * vec2(1920.0, 1080.0) + TIME * 13.37) - 0.5;
	col += n * u_grain_strength;

	COLOR = vec4(col, 1.0);
}
