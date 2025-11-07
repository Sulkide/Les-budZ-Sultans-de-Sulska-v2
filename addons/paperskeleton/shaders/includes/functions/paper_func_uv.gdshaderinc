vec2 rotate_uv(vec2 paper_uv, float paper_uv_rotation) {
	return vec2(
		paper_uv.x * cos(paper_uv_rotation) - paper_uv.y * sin(paper_uv_rotation),
		paper_uv.x * sin(paper_uv_rotation) + paper_uv.y * cos(paper_uv_rotation)
	);
}

vec2 scale_uv_with_scale_modifier(vec2 paper_uv, sampler2D paper_sampler, vec2 paper_uv_scale) {
	ivec2 paper_texture_size = textureSize(paper_sampler, 0);

	// Scale UV coordinates with image size and scale modifier
	paper_uv *= vec2(1.0 / (float(paper_texture_size.x) / paper_uv_scale.x),
					 1.0 / (float(paper_texture_size.y) / paper_uv_scale.y));

	return paper_uv;
}

vec2 scale_uv_with_modifiers(vec2 paper_uv, sampler2D paper_sampler, vec2 paper_uv_offset, vec2 paper_uv_scale, float paper_uv_rotation) {
	return scale_uv_with_scale_modifier(rotate_uv(paper_uv, paper_uv_rotation) + paper_uv_offset, paper_sampler, paper_uv_scale);
}

vec2 scale_uv(vec2 paper_uv, sampler2D paper_sampler) {
	ivec2 paper_texture_size = textureSize(paper_sampler, 0);

	// Scale UV coordinates with image size
	paper_uv *= vec2(1.0 / float(paper_texture_size.x),
					  1.0 / float(paper_texture_size.y));

	return paper_uv;
}

vec2 scale_uv_with_offset_modifier(vec2 paper_uv, sampler2D paper_sampler, vec2 paper_uv_offset) {
	return scale_uv(paper_uv + paper_uv_offset, paper_sampler);
}

vec2 scale_uv_with_rotation_modifier(vec2 paper_uv, sampler2D paper_sampler, float paper_uv_rotation) {
	return scale_uv(rotate_uv(paper_uv, paper_uv_rotation), paper_sampler);
}

vec2 scale_uv_with_offset_and_scale_modifiers(vec2 paper_uv, sampler2D paper_sampler, vec2 paper_uv_offset, vec2 paper_uv_scale) {
	return scale_uv_with_scale_modifier(paper_uv + paper_uv_offset, paper_sampler, paper_uv_scale);
}

vec2 scale_uv_with_offset_and_rotation_modifiers(vec2 paper_uv, sampler2D paper_sampler, vec2 paper_uv_offset, float paper_uv_rotation) {
	return scale_uv_with_offset_modifier(rotate_uv(paper_uv, paper_uv_rotation), paper_sampler, paper_uv_offset);
}

vec2 scale_uv_with_scale_and_rotation_modifiers(vec2 paper_uv, sampler2D paper_sampler, vec2 paper_uv_scale, float paper_uv_rotation) {
	return scale_uv_with_scale_modifier(rotate_uv(paper_uv, paper_uv_rotation), paper_sampler, paper_uv_scale);
}

vec2 scale_uv_with_albedo_modifiers(vec2 paper_uv, sampler2D paper_sampler) {
	return scale_uv_with_modifiers(paper_uv, paper_sampler, auto_albedo_uv_offset, auto_albedo_uv_scale, auto_albedo_uv_rotation);
}
