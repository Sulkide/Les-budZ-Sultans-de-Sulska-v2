float generate_mask_from_uv(vec2 paper_uv){
	vec2 paper_uv_mask = step(vec2(0.0), paper_uv) * step(paper_uv, vec2(1.0));
	return paper_uv_mask.x * paper_uv_mask.y;
}