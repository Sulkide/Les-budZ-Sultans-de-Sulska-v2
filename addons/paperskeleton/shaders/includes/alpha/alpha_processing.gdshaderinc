#if !USE_ALPHA_HASH
	ALPHA = paper_alpha;
	#if USE_ALPHA_SCISSOR
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	#endif
#endif
#if USE_ALPHA_HASH
	vec2 paper_screen_uv = SCREEN_UV * VIEWPORT_SIZE / ((VIEWPORT_SIZE.x + VIEWPORT_SIZE.y) * 0.5) / (alpha_hash_scale);
	float paper_noise = texture(alpha_hash_texture, paper_screen_uv).r;
	#if USE_ALPHA_SCISSOR
		float paper_alpha_threshold = 1.0 - alpha_scissor_threshold;
	#else
		float paper_alpha_threshold = 1.0;
	#endif
	float paper_alpha_dither = smoothstep(0.0, paper_alpha_threshold, paper_noise);

	if (paper_alpha < paper_alpha_dither) {
		discard;
	}
#endif