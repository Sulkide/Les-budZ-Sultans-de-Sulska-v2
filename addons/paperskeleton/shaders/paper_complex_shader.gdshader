shader_type spatial;

// This shader is intended to be more of an experimental example shader that exists
// mainly as a way to inform new users of how to add implement more complex features
// with the PaperSkeleton setup. The practive of making your own specialized shader
// that suits your game's own specialized needs is encouraged, rather than just
// relying on this one.

// Alpha properties (Don't add a semicolon to the render mode line)
// You can easily implement your own system. I just made this for easier swapping.
#include "includes/alpha/alpha_property_scissor.gdshaderinc"
render_mode cull_disabled
#include "includes/alpha/alpha_mode_and_uniforms.gdshaderinc"

// Main properties
group_uniforms Metal;
uniform sampler2D metal_texture : repeat_disable;
uniform float metal : hint_range(0, 2) = 0;

group_uniforms Roughness;
uniform sampler2D roughness_texture : repeat_disable;
uniform float roughness : hint_range(0, 2) = 1;

group_uniforms Specular;
uniform sampler2D specular_texture : repeat_disable;
uniform float specular = 0.5;

// Optional properties

// Emissive properties
group_uniforms Optional.Emissive;
uniform bool emissive = false;
uniform sampler2D emissive_texture : source_color, repeat_disable, hint_default_black;
uniform vec4 emissive_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Ambient Occlusion properties
group_uniforms Optional.AmbientOcclusion;
uniform bool ambient_occlusion = false;
uniform sampler2D ambient_occlusion_texture : repeat_disable;
uniform float ambient_occlusion_light_affect : hint_range(0, 2) = 0;

// Normal mapping properties
group_uniforms Optional.Normal;
uniform bool normal = false;
uniform sampler2D normal_map_texture : repeat_disable;
uniform float normal_map_depth = 1;

// Clearcoat properties
group_uniforms Optional.Clearcoat;
uniform bool clearcoat = false;
uniform float clearcoat_value = 0;
uniform float clearcoat_roughness = 0;

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

	vec4 final_color = albedo_tex * auto_albedo_color;
	float final_alpha = final_color.a * (if_texture_exists ? generate_mask_from_uv(albedo_uv) : 1.0);
	vec3 albedo_output = final_color.rgb;

	// Treat paper_alpha as regular alpha assignment
	float paper_alpha = final_alpha;
	#include "includes/alpha/alpha_processing.gdshaderinc"

	// Process other properties
	vec2 metal_uv = scale_uv_with_albedo_modifiers(UV, metal_texture);
	vec4 metal_tex = texture(metal_texture, metal_uv);
	float metal_output = metal_tex.r * metal;

	vec2 roughness_uv = scale_uv_with_albedo_modifiers(UV, roughness_texture);
	vec4 roughness_tex = texture(roughness_texture, roughness_uv);
	float roughness_output = roughness_tex.r * roughness;

	vec2 specular_uv = scale_uv_with_albedo_modifiers(UV, specular_texture);
	vec4 specular_tex = texture(specular_texture, specular_uv);
	float specular_output = specular_tex.r * specular;

	// Process optional features
	if (emissive) {
		vec2 emission_uv = scale_uv_with_albedo_modifiers(UV, emissive_texture);
		vec4 emission_tex = texture(emissive_texture, emission_uv);
		float emission_alpha = emission_tex.a * emissive_color.a;
		EMISSION = emission_tex.rgb * emissive_color.rgb * emission_alpha;
	}

	if (ambient_occlusion) {
		vec2 ao_uv = scale_uv_with_albedo_modifiers(UV, ambient_occlusion_texture);
		vec4 ao_tex = texture(ambient_occlusion_texture, ao_uv);
		AO = ao_tex.r;
		AO_LIGHT_AFFECT = ambient_occlusion_light_affect;
	}

	if (normal) {
		vec2 normal_uv = scale_uv_with_albedo_modifiers(UV, normal_map_texture);
		vec4 normal_tex = texture(normal_map_texture, normal_uv);
		NORMAL_MAP = normal_tex.rgb;
		NORMAL_MAP_DEPTH = normal_map_depth;
	}

	if (clearcoat) {
		CLEARCOAT = clearcoat_value;
		CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	}

	// Final output
	ALBEDO = albedo_output;
	METALLIC = metal_output;
	ROUGHNESS = roughness_output;
	SPECULAR = specular_output;
}

void vertex() {
	VERTEX = calculate_mesh_offset(VERTEX, NORMAL, MODEL_MATRIX, MODEL_NORMAL_MATRIX, CAMERA_POSITION_WORLD);
	NORMAL = flip_z_normal(NORMAL);
}