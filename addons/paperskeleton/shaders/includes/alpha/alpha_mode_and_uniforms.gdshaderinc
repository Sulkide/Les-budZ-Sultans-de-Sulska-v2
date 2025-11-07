#if (!USE_ALPHA_SCISSOR && !USE_ALPHA_HASH)
	, depth_prepass_alpha;
#else
	;

	#if USE_ALPHA_SCISSOR
		uniform float alpha_scissor_threshold : hint_range(0, 1) = .1;
	#endif

	#if USE_ALPHA_HASH
		uniform float alpha_hash_scale : hint_range(0, 1) = .01;
		uniform sampler2D alpha_hash_texture : hint_default_transparent;
	#endif
#endif