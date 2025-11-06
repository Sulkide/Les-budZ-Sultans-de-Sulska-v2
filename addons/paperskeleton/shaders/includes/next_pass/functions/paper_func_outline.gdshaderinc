// NOTE: This won't work very well if the mesh wouldn't be big enough to support a texture.
//       So, if you want to implement traditional outlines, I highly recommend adding some
//       empty extra space around the texture in your Polygon2Ds.

float generate_outline(sampler2D paper_sampler, vec2 paper_uv, float paper_width) {
	vec2 paper_size = (1.0 / vec2(textureSize(paper_sampler, 0))) * paper_width;
	vec2 paper_size_trig = paper_size * 0.866;
	vec2 paper_size_half = paper_size * 0.500;

	// Define sampling points
	vec2[12] paper_offsets = vec2[12](
		vec2(     -paper_size.x,  0.0),
		vec2(               0.0,  paper_size.y),
		vec2(      paper_size.x,  0.0),
		vec2(               0.0, -paper_size.y),
		vec2(-paper_size_trig.x,  paper_size_half.y),
		vec2(-paper_size_half.x,  paper_size_trig.y),
		vec2( paper_size_trig.x,  paper_size_half.y),
		vec2( paper_size_half.x,  paper_size_trig.y),
		vec2(-paper_size_trig.x, -paper_size_half.y),
		vec2(-paper_size_half.x, -paper_size_trig.y),
		vec2( paper_size_trig.x, -paper_size_half.y),
		vec2( paper_size_half.x, -paper_size_trig.y)
	);

	float paper_outline = 0.0;

	// Sample using step functions for boundary checking
	for(int i = 0; (i < paper_offsets.length()) && (paper_outline < 1.0); i++) {
		vec2 paper_sample_uv = paper_uv + paper_offsets[i];
		vec2 paper_inside_uv = step(vec2(0.0), paper_sample_uv) * step(paper_sample_uv, vec2(1.0));
		paper_outline += texture(paper_sampler, paper_sample_uv).a * paper_inside_uv.x * paper_inside_uv.y;
	}

	return min(paper_outline, 1.0);
}