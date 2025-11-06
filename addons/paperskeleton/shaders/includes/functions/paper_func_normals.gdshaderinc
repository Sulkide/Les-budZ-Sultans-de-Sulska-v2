vec3 flip_z_normal(vec3 paper_normal) {
    return paper_normal * auto_mesh_normal_flip;
}