float calculate_mesh_offset_value(float paper_index_input){
	float paper_idx = float(paper_index_input) - (float(auto_mesh_total_z_indices - 1) * 0.5);
	return paper_idx * abs(auto_mesh_z_offset * auto_mesh_size);
}

float calculate_face_sign(vec3 paper_vertex, vec3 paper_normal, mat4 paper_model_matrix,
						  mat3 paper_model_normal_matrix, vec3 paper_camera_position_world) {
	vec3 world_norm = normalize(paper_model_normal_matrix * paper_normal);
	vec3 view_dir = normalize(paper_camera_position_world - (paper_model_matrix * vec4(paper_vertex, 1.0)).xyz);
	
	return sign(dot(world_norm, view_dir));
}

vec3 calculate_mesh_offset_with_custom_index(vec3 paper_vertex, vec3 paper_normal, mat4 paper_model_matrix,
											 mat3 paper_model_normal_matrix, vec3 paper_camera_position_world,
											 float paper_index_input) {
	float face_sign = calculate_face_sign(paper_vertex, paper_normal, paper_model_matrix,
										  paper_model_normal_matrix, paper_camera_position_world);
	return paper_vertex + paper_normal * calculate_mesh_offset_value(paper_index_input) * face_sign;
}

vec3 calculate_mesh_offset_with_custom_index_int(vec3 paper_vertex, vec3 paper_normal, mat4 paper_model_matrix,
												 mat3 paper_model_normal_matrix, vec3 paper_camera_position_world,
												 int paper_index_input) {
	return calculate_mesh_offset_with_custom_index(paper_vertex, paper_normal, paper_model_matrix,
												   paper_model_normal_matrix, paper_camera_position_world,
												   float(paper_index_input));
}

vec3 calculate_mesh_offset(vec3 paper_vertex, vec3 paper_normal, mat4 paper_model_matrix,
						   mat3 paper_model_normal_matrix, vec3 paper_camera_position_world) {
    return calculate_mesh_offset_with_custom_index_int(paper_vertex, paper_normal, paper_model_matrix,
													   paper_model_normal_matrix, paper_camera_position_world,
													   auto_mesh_z_index);
}