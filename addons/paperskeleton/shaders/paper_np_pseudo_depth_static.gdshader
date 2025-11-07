shader_type spatial;

// Alpha properties (Don't add a semicolon to the render mode line)
// You can easily implement your own system. I just made this for easier swapping.
#include "includes/alpha/alpha_property_scissor.gdshaderinc"
render_mode cull_disabled
#include "includes/alpha/alpha_mode_and_uniforms.gdshaderinc"

// Required uniforms and functions
#include "includes/paper_all.gdshaderinc"

// Outline function
#include "includes/next_pass/functions/paper_func_outline.gdshaderinc"

uniform int auto_mesh_z_group = 0;
uniform float auto_mesh_z_group_micro_index = 0.5;
uniform float outline_width = 0;
uniform vec2 outline_direction = vec2(1.0, 1.0);

// Gradient uniforms
uniform vec2 gradient_direction = vec2(0.75, -1.0);
uniform vec4 start_color : source_color = vec4(1);
uniform vec4 end_color : source_color = vec4(0.839, 0.824, 0.796, 1);

// Gradient helper functions
float vmax(vec4 vec) {
	return max(vec.x, max(vec.y, max(vec.z, vec.w)));
}

float random(vec2 seed, float pmin, float pmax) {
	return pmin + fract(sin(dot(seed.xy, vec2(12.9898, 78.233))) * 43758.5453123) * (pmax - pmin);
}

float get_color_count(float range) {
	return ceil(clamp(range, 0.0, 1.0) * 255.0);
}

float get_delta(vec2 uv, vec2 direction) {
	vec2 dir = normalize(direction);
	return (dir.x < 0.0 ? (1.0 - uv.x) : uv.x) * dir.x * dir.x +
		   (dir.y < 0.0 ? (1.0 - uv.y) : uv.y) * dir.y * dir.y;
}

void fragment() {
	bool use_flip_texture = auto_albedo_flip_texture_exists && !FRONT_FACING;
	bool if_texture_exists = (use_flip_texture && auto_albedo_flip_texture_exists)
	                      || (!use_flip_texture && auto_albedo_texture_exists);

	vec2 albedo_uv;
	float outline;

	if(if_texture_exists) {
		bool expanded_outline = outline_width != 0.0;
		if(use_flip_texture) {
			albedo_uv = scale_uv_with_albedo_modifiers(UV, auto_albedo_flip_texture);
			if(expanded_outline)
				outline = generate_outline(auto_albedo_flip_texture, albedo_uv, outline_width);
			else
				outline = texture(auto_albedo_flip_texture, albedo_uv).a * generate_mask_from_uv(albedo_uv);
		}
		else {
			albedo_uv = scale_uv_with_albedo_modifiers(UV, auto_albedo_texture);
			if(expanded_outline)
				outline = generate_outline(auto_albedo_texture, albedo_uv, outline_width);
			else
				outline = texture(auto_albedo_texture, albedo_uv).a * generate_mask_from_uv(albedo_uv);
		}
	}
	else {
		albedo_uv = UV / vec2(768.0);
		outline = 1.0;
	}

	vec4 gradient_color;

	if (outline > 0.0){
		float color_count = get_color_count(vmax(abs(end_color - start_color)));
		float inv_color_count = 1.0 / color_count;

		float color_index = floor(get_delta(albedo_uv, gradient_direction) * color_count);
		vec4 color1 = mix(start_color, end_color, color_index / color_count);
		vec4 color2 = mix(start_color, end_color, (color_index + 1.0) / color_count);

		float ratio = clamp(mod(get_delta(albedo_uv, gradient_direction), inv_color_count) * color_count
		                    + random(albedo_uv, -0.5, 0.5), 0.0, 1.0);
		gradient_color = color1 * (1.0 - ratio) + color2 * ratio;
	}

	// Treat paper_alpha as regular alpha assignment
	float paper_alpha = outline * gradient_color.a;
	#include "includes/alpha/alpha_processing.gdshaderinc"

	ALBEDO = gradient_color.rgb;
}

vec3 rotate_vector_towards_direction(vec3 vec_to_rotate, vec3 target_normal) {
	vec3 n_norm = normalize(target_normal);

	float sz = n_norm.z != 0.0 ? sign(n_norm.z) : 1.0;

	float a = -1.0 / (sz + n_norm.z);
	float b = sz * n_norm.x * n_norm.y * a;

	vec2 xy_norm = n_norm.xy;
	vec2 sz_norm = sz * xy_norm;
	vec2 sq_a_norm = xy_norm * xy_norm * a;

	vec3 tangent = vec3(1.0 + sz * sq_a_norm.x, b, -sz_norm.x);
	vec3 bitangent = vec3(b, sz + sq_a_norm.y, -sz_norm.y);

	return vec_to_rotate.x * tangent + vec_to_rotate.y * bitangent + vec_to_rotate.z * n_norm;
}

void vertex() {
	float adjusted_scale = auto_mesh_size * 0.01;
	float group_index = float(auto_mesh_z_group) - auto_mesh_z_group_micro_index;
	float face_sign = calculate_face_sign(VERTEX, NORMAL, MODEL_MATRIX, MODEL_NORMAL_MATRIX, CAMERA_POSITION_WORLD);
	float z_offset = calculate_mesh_offset_value(group_index) * face_sign;
	vec3 base_adjustment = vec3(outline_direction.x * face_sign * auto_mesh_normal_flip * adjusted_scale,
							    outline_direction.y * adjusted_scale,
							    z_offset);

	VERTEX += rotate_vector_towards_direction(base_adjustment, NORMAL);
	NORMAL = flip_z_normal(NORMAL);
}