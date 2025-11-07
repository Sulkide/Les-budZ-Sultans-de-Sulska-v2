class_name PaperSkeletonGizmoPlugin
extends EditorNode3DGizmoPlugin

func _init():
	_setup_materials()

func _setup_materials() -> void:
	create_material("main", Color(1, 1, 1, 0.9))
	create_icon_material("skeleton_icon", load(get_script().get_path().get_base_dir().path_join("../../paper_skeleton.svg")))

func _get_gizmo_name() -> String:
	return "PaperSkeleton"

func _has_gizmo(node: Node3D) -> bool:
	return node is PaperSkeleton

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var skel: PaperSkeleton = gizmo.get_node_3d()
	var bounds := _calculate_bounds(skel)
	
	if bounds and not bounds.size.is_equal_approx(Vector3.ZERO):
		_create_gizmo_visualization(gizmo, bounds)
	else:
		_create_gizmo_billboard(gizmo)

func _calculate_bounds(skel: PaperSkeleton) -> AABB:
	var aabb := AABB()
	var first := true
	
	for paper_polygon: PaperPolygon2D in skel.name_to_paper_polygon.values():
		var mesh_instance := paper_polygon.mesh_instance_3d
		
		if not mesh_instance:
			continue
		
		var transformed_aabb := _get_transformed_aabb(mesh_instance, skel.size)
		
		if first:
			aabb = transformed_aabb
			first = false
		else:
			aabb = aabb.merge(transformed_aabb)
	
	return aabb if not first else AABB()

func _get_transformed_aabb(mesh_instance: MeshInstance3D, skel_size: float) -> AABB:
	var mesh_aabb := mesh_instance.get_aabb()
	var transformed_corners := _calculate_transformed_corners(mesh_aabb, mesh_instance.transform, skel_size)
	return _create_aabb_from_corners(transformed_corners)

func _calculate_transformed_corners(mesh_aabb: AABB, transform: Transform3D, skel_size: float) -> PackedVector3Array:
	var corners := PackedVector3Array()
	var base_corners := _get_aabb_corners(mesh_aabb)
	
	for corner in base_corners:
		corner.x *= skel_size
		corner.y *= skel_size
		corners.append(transform * (corner))
	
	return corners

func _get_aabb_corners(aabb: AABB) -> Array:
	return [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z)
	]

func _create_aabb_from_corners(corners: PackedVector3Array) -> AABB:
	if corners.is_empty():
		return AABB()
	
	var aabb := AABB(corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		aabb = aabb.expand(corners[i])
	return aabb

func _create_gizmo_visualization(gizmo: EditorNode3DGizmo, aabb: AABB) -> void:
	aabb = aabb.grow(0.05)  # Expand slightly
	var material := get_material("main", gizmo)
	
	var lines := _create_boundary_lines(aabb)
	var collision_mesh := _create_collision_mesh(aabb)
	
	gizmo.add_lines(lines, material)
	gizmo.add_collision_triangles(collision_mesh.generate_triangle_mesh())

func _create_gizmo_billboard(gizmo: EditorNode3DGizmo) -> void:
	var icon_material := get_material("skeleton_icon", gizmo)
	gizmo.add_unscaled_billboard(icon_material, 0.03)

func _create_boundary_lines(aabb: AABB) -> PackedVector3Array:
	var pos := aabb.position
	var size := aabb.size
	
	return PackedVector3Array([
		# Bottom square
		pos, pos + Vector3(size.x, 0, 0),
		pos + Vector3(size.x, 0, 0), pos + Vector3(size.x, 0, size.z),
		pos + Vector3(size.x, 0, size.z), pos + Vector3(0, 0, size.z),
		pos + Vector3(0, 0, size.z), pos,
		
		# Top square
		pos + Vector3(0, size.y, 0), pos + Vector3(size.x, size.y, 0),
		pos + Vector3(size.x, size.y, 0), pos + Vector3(size.x, size.y, size.z),
		pos + Vector3(size.x, size.y, size.z), pos + Vector3(0, size.y, size.z),
		pos + Vector3(0, size.y, size.z), pos + Vector3(0, size.y, 0),
		
		# Vertical lines
		pos, pos + Vector3(0, size.y, 0),
		pos + Vector3(size.x, 0, 0), pos + Vector3(size.x, size.y, 0),
		pos + Vector3(size.x, 0, size.z), pos + Vector3(size.x, size.y, size.z),
		pos + Vector3(0, 0, size.z), pos + Vector3(0, size.y, size.z)
	])

func _create_collision_mesh(aabb: AABB) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_add_face_vertices(mesh, aabb)
	
	mesh.surface_end()
	return mesh

func _add_face_vertices(mesh: ImmediateMesh, aabb: AABB) -> void:
	var pos := aabb.position
	var size := aabb.size
	
	# Front face
	_add_quad_vertices(mesh, pos, Vector3(size.x, 0, 0), Vector3(0, size.y, 0))
	# Back face
	_add_quad_vertices(mesh, pos + Vector3(0, 0, size.z), Vector3(size.x, 0, 0), Vector3(0, size.y, 0))
	# Left face
	_add_quad_vertices(mesh, pos, Vector3(0, size.y, 0), Vector3(0, 0, size.z))
	# Right face
	_add_quad_vertices(mesh, pos + Vector3(size.x, 0, 0), Vector3(0, size.y, 0), Vector3(0, 0, size.z))
	# Top face
	_add_quad_vertices(mesh, pos + Vector3(0, size.y, 0), Vector3(size.x, 0, 0), Vector3(0, 0, size.z))
	# Bottom face
	_add_quad_vertices(mesh, pos, Vector3(size.x, 0, 0), Vector3(0, 0, size.z))

func _add_quad_vertices(mesh: ImmediateMesh, start: Vector3, u: Vector3, v: Vector3) -> void:
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(start + u)
	mesh.surface_add_vertex(start + u + v)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(start + u + v)
	mesh.surface_add_vertex(start + v)
