shader_type spatial;

// Alpha properties (Don't add a semicolon to the render mode line)
// You can easily implement your own system. I just made this for easier swapping.
#include "includes/alpha/alpha_property_scissor.gdshaderinc"
render_mode cull_disabled
#include "includes/alpha/alpha_mode_and_uniforms.gdshaderinc"

// Required uniforms and functions
#include "includes/paper_all.gdshaderinc"

void fragment() {
	// Process base color
	bool use_flip_texture = auto_albedo_flip_texture_exists && !FRONT_FACING;

	vec2 albedo_uv;
	vec4 albedo_tex;
	bool if_texture_exists;

	if(use_flip_texture) {
		albedo_uv = scale_uv_with_albedo_modifiers(UV, auto_albedo_flip_texture);
		albedo_tex = texture(auto_albedo_flip_texture, albedo_uv);
		if_texture_exists = auto_albedo_flip_texture_exists;
	}
	else {
		albedo_uv = scale_uv_with_albedo_modifiers(UV, auto_albedo_texture);
		albedo_tex = texture(auto_albedo_texture, albedo_uv);
		if_texture_exists = auto_albedo_texture_exists;
	}

	float albedo_bw = (albedo_tex.r + albedo_tex.g + albedo_tex.b) / 3.0;

	vec4 final_color = vec4(albedo_bw, albedo_bw, albedo_bw, albedo_tex.a) * auto_albedo_color;
	float final_alpha = final_color.a * (if_texture_exists ? generate_mask_from_uv(albedo_uv) : 1.0);
	vec3 albedo_output = final_color.rgb;

	// Treat paper_alpha as regular alpha assignment
	float paper_alpha = final_alpha;
	#include "includes/alpha/alpha_processing.gdshaderinc"

	// Final output
	ALBEDO = albedo_output;
}

void vertex() {
	VERTEX = calculate_mesh_offset(VERTEX, NORMAL, MODEL_MATRIX, MODEL_NORMAL_MATRIX, CAMERA_POSITION_WORLD);
	NORMAL = flip_z_normal(NORMAL);
}