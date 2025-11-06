shader_type spatial;

// NOTE: This won't work very well if the mesh wouldn't be big enough to support a texture.
//       So, if you want to implement traditional outlines, I highly recommend adding some
//       extra empty space around the texture in your Polygon2Ds.

// Alpha properties (Don't add a semicolon to the render mode line)
// You can easily implement your own system. I just made this for easier swapping.
#include "includes/alpha/alpha_property_scissor.gdshaderinc"
render_mode cull_disabled
#include "includes/alpha/alpha_mode_and_uniforms.gdshaderinc"

// Required uniforms and functions
#include "includes/paper_all.gdshaderinc"

// Outline function
#include "includes/next_pass/functions/paper_func_outline.gdshaderinc"

uniform float outline_width = 10.0;
uniform vec4 outline_color : source_color = vec4(1.0);

float generate_outline_auto_scale_uv(sampler2D sampler, vec2 uv, float width) {
	return generate_outline(sampler, scale_uv_with_albedo_modifiers(uv, sampler), width);
}

void fragment() {
	bool use_flip_texture = auto_albedo_flip_texture_exists && !FRONT_FACING;
	float outline;
	if(use_flip_texture)
		outline = generate_outline_auto_scale_uv(auto_albedo_flip_texture, UV, outline_width);
	else
		outline = generate_outline_auto_scale_uv(auto_albedo_texture, UV, outline_width);

	// Treat paper_alpha as regular alpha assignment
	float paper_alpha = outline * outline_color.a;
	#include "includes/alpha/alpha_processing.gdshaderinc"

	// Apply outline color
	ALBEDO = outline_color.rgb;
}

void vertex() {
	int border_index = auto_mesh_z_index - auto_mesh_total_z_indices;
	VERTEX = calculate_mesh_offset_with_custom_index_int(VERTEX, NORMAL, MODEL_MATRIX, MODEL_NORMAL_MATRIX, CAMERA_POSITION_WORLD, border_index);
	NORMAL = flip_z_normal(NORMAL);
}