## Class that manages meshes and materials for PaperSkeleton.
extends RefCounted
## A specialized class that manages mesh generation and material handling for [PaperSkeleton].
## This manager handles all mesh-related operations including:
## [br][b]- Mesh creation from [PaperPolygon2D] nodes[/b]
## [br][b]- Material setup and updates[/b]
## [br][b]- Shader parameter management[/b]
## [br][b]- Layer/visibility control[/b]
class_name PaperSkeletonMeshManager

## Reference to the parent [PaperSkeleton] instance.
var skel: PaperSkeleton

## Cached layer space information
var cached_layer_space := 0.0

## Flag for deferred z-index update
var index_update: bool = false

## Initializes the mesh manager with a reference to [PaperSkeleton].
func _init(paper_skeleton: PaperSkeleton):
	skel = paper_skeleton

const INDEX_PARAMS: PackedInt32Array = [
	PaperSkeleton.AutoParam.MESH_INDEX,
	PaperSkeleton.AutoParam.MESH_GROUP_INDEX,
	PaperSkeleton.AutoParam.MESH_GROUP_MICRO_INDEX,
	PaperSkeleton.AutoParam.MESH_TOTAL_INDICES
]

#region PaperPolygon2D and Mesh Management
## Toggles visibility of original [PaperPolygon2D] nodes.
## [br][br]
## Controls visibility through visibility layer to maintain animation compatibility:
## [br][b]- 0[/b]: Hidden
## [br][b]- 1[/b]: Visible
func toggle_polygon_visibility() -> void:
	var vis := 0 if skel.hide_polygons else 1
	for polygon: PaperPolygon2D in skel.name_to_paper_polygon.values():
		polygon.visibility_layer = vis

## Recursively collects [Polygon2D] nodes from a node hierarchy, considering z_as_relative.
## Automatically converts [Polygon2D]s to PaperPolygon2Ds.
## [br][br]
## Can operate in two modes:
## [br][b]- Z-index grouping[/b]: Organizes PaperPolygon2Ds by their effective z-index.
## [br][b]- Name collection[/b]: Stores polygon names instead of references.
## [br]
## [br][param node]: Root node to start collection from.
## [br][param polygons]: Dictionary to store collected PaperPolygon2Ds.
## [br][param put_in_z_groups]: Whether to group by effective z-index.
## [br][param collect_names]: Whether to store names instead of references.
## [br][param apply_skeleton]: Whether to auto-assign [PaperSkeleton] to the PaperPolygon2Ds.
## [br][param parent_effective_z]: Internal parameter to track effective Z-index from parent nodes.
func _collect_polygons(node: Node, polygons: Dictionary, put_in_z_groups: bool = true,
					   apply_skeleton: bool = true, parent_effective_z: int = 0) -> void:
	for child in node.get_children():
		var child_effective_z := parent_effective_z
		if put_in_z_groups and child is CanvasItem:
			if child.is_z_relative():
				child_effective_z += child.get_z_index()
			else:
				child_effective_z = child.get_z_index()
		
		if child is Polygon2D:
			var polygon := convert_polygon_to_paper_polygon(child, apply_skeleton)
			if (apply_skeleton or not child is PaperPolygon2D):
				convert_polygon_to_paper_polygon(child, apply_skeleton)
			if put_in_z_groups:
				var z := clampi(child_effective_z,
								RenderingServer.CANVAS_ITEM_Z_MIN,
								RenderingServer.CANVAS_ITEM_Z_MAX)
				if not polygons.has(z):
					polygons[z] = []
				polygons[z].append(polygon)
			else:
				polygons[polygon] = true
		_collect_polygons(child, polygons, put_in_z_groups, apply_skeleton, child_effective_z)

## Converts all [Polygon2D] nodes under the skeleton to [PaperPolygon2D] nodes.
## Automatically applies the [PaperSkeleton] node if [param apply_skeleton] is set to true.
func convert_polygon_to_paper_polygon(polygon: Polygon2D, apply_skeleton: bool = false) -> PaperPolygon2D:
	if not polygon is PaperPolygon2D:
		polygon.set_script(PaperPolygon2D)
		print("Converted Polygon2D instance \"%s\" to PaperPolygon2D" % polygon.name)
	var paper_poly: PaperPolygon2D = polygon
	if apply_skeleton:
		paper_poly.paper_skeleton = skel
	return paper_poly

## Resolves the root polygon in a copy-index chain to prevent circular dependencies.
## Returns the final polygon in the chain or breaks on infinite loops.
func resolve_root(polygon: PaperPolygon2D) -> PaperPolygon2D:
	var visited := []
	var current := polygon
	while current.polygon_to_copy_index_of != null:
		if current in visited:
			push_warning("Cycle detected in polygon_to_copy_index_of chain for %s. Breaking loop." % polygon.name)
			return current
		visited.append(current)
		current = current.polygon_to_copy_index_of
		if not is_instance_valid(current):
			push_warning("Invalid polygon_to_copy_index_of reference in %s. Using itself." % polygon.name)
			break
	return current

## Creates 3D mesh instances for all collected [PaperPolygon2D] nodes.
## [br][br]
## The process:
## [br][b]1.[/b] Collects and sorts PaperPolygon2Ds by z-index
## [br][b]2.[/b] Creates sequential mesh instances while preserving z-order
## [br][b]3.[/b] Maps created meshes to their source PaperPolygon2Ds
## [br][b]4.[/b] Apply materials to meshes
## [br][b]5.[/b] Set visibility
func create_3d_meshes() -> void:
	# Update materials
	for paper_polygon: PaperPolygon2D in skel.name_to_paper_polygon.values():
		create_3d_mesh_from_paper_polygon(paper_polygon)
		var mesh_instance: MeshInstance3D = paper_polygon.mesh_instance_3d
		create_material_from_paper_polygon(mesh_instance, paper_polygon)
		mesh_instance.visible = paper_polygon.is_visible_in_tree()

## Updates a single [PaperPolygon2D]'s mesh
func update_3d_mesh_from_paper_polygon(polygon: PaperPolygon2D) -> void:
	var mesh_instance: MeshInstance3D = polygon.mesh_instance_3d
	
	# Recreate the mesh with updated subdivision
	var skinned_array_mesh: ArrayMesh = create_skinned_array_mesh(polygon)
	mesh_instance.mesh = skinned_array_mesh

## Creates a 3D mesh instance from a [PaperPolygon2D].
## [br][br]
## Sets up:
## [br][b]- Mesh geometry and skinning[/b]
## [br][b]- Appropriate scaling[/b]
## [br][b]- Skeleton binding[/b]
## [br]
## [br][param paper_polygon]: Source PaperPolygon2D to create mesh from
## [br][param z_index]: Layer ordering index
func create_3d_mesh_from_paper_polygon(paper_polygon: PaperPolygon2D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = paper_polygon.name + "_3d_mesh"
	paper_polygon.mesh_instance_3d = mesh_instance
	
	var skinned_array_mesh: ArrayMesh = create_skinned_array_mesh(paper_polygon) \
										if skel.is_ready or !skel.stored_meshes.has(paper_polygon.name) \
										else skel.stored_meshes[paper_polygon.name]
	mesh_instance.mesh = skinned_array_mesh
	
	mesh_instance.skeleton = skel.skeleton3d.get_path()
	mesh_instance.cast_shadow = skel.cast_shadow
	mesh_instance.gi_mode = skel.global_illumination_mode
	
	skel.add_child(mesh_instance)

## Returns an [ArrayMesh] constructed from a [PaperPolygon2D], with proper bone weights applied.
## [br][br]
## Handles:
## [br][b]- Vertex data generation[/b]
## [br][b]- Normal calculation[/b]
## [br][b]- UV mapping[/b]
## [br][b]- Bone weight assignment[/b]
## [br][b]- Triangle index generation[/b]
## [br]
## [br][param paper_polygon]: Source [PaperPolygon2D] to create mesh from
func create_skinned_array_mesh(paper_polygon: PaperPolygon2D) -> ArrayMesh:
	# PaperPolygon2D arrays
	var polygon_vertices := paper_polygon.polygon
	var polygon_uvs := paper_polygon.uv
	var polygon_indices := paper_polygon.polygons
	
	var vertex_count: int = polygon_vertices.size()
	var vertex_count_minus_one: int = vertex_count - 1
	
	if polygon_uvs.is_empty():
		polygon_uvs = polygon_vertices
	
	if polygon_indices.size() <= 1 and \
	  (polygon_indices.size() == 0 or polygon_indices[0].is_empty()):
		polygon_indices.resize(1)
		polygon_indices[0] = PackedInt32Array(range(vertex_count))
	
	# Determine if we need to use 4 or 8 bone weights per vertex
	# Also checks if there are any weights to begin with
	var max_bw_count: int = 0
	var is_weighted: bool = false
	var are_weights_below_or_equal_to_4: bool = true
	for i: int in vertex_count:
		var bw_count: int = 0
		for bone in skel.polygon_bone_data.keys():
			if paper_polygon in skel.polygon_bone_data[bone]:
				var weight: float = skel.polygon_bone_data[bone][paper_polygon][i]
				if weight > 0:
					bw_count += 1
					if !is_weighted:
						is_weighted = true
		if bw_count > max_bw_count:
			max_bw_count = bw_count
			if max_bw_count > 4:
				are_weights_below_or_equal_to_4 = false
				break
	var max_bw: int = 4 if are_weights_below_or_equal_to_4 else 8
	
	var transform_modifier := paper_polygon.get_global_transform() \
										   .translated(paper_polygon.offset)
	
	var vertices := PackedVector3Array()
	var normals  := PackedVector3Array()
	var uvs      := PackedVector2Array()
	var bones    := PackedInt32Array()
	var weights  := PackedFloat32Array()
	
	var bone_and_bw_count: int = vertex_count * max_bw
	
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	bones.resize(bone_and_bw_count)
	weights.resize(bone_and_bw_count)
	
	for i in vertex_count:
		var vertex: Vector2 = polygon_vertices[i]
		vertex = transform_modifier * vertex * skel.DEFAULT_SCALE
		
		vertices[i] = Vector3(vertex.x, -vertex.y, 0)
		normals[i] = Vector3.MODEL_FRONT
		uvs[i] = polygon_uvs[i] if polygon_uvs.size() > i else Vector2.ZERO
		
		# Collect bones and weights for this vertex if there are any
		if !is_weighted:
			continue
		
		var bw_start_idx: int = i * max_bw
		var bw_idx: int = bw_start_idx
		var total_weight: float = 0.0
		var bw_count: int = 0
		for bone in skel.polygon_bone_data.keys():
			if paper_polygon in skel.polygon_bone_data[bone]:
				var weight: float = skel.polygon_bone_data[bone][paper_polygon][i]
				if weight > 0:
					# Handle cases with too many bones weights on one vertex.
					if bw_count + 1 > max_bw:
						push_warning("Unable to have more than 8 bones weighted on the same vertex. "
								   + "Please adjust your PaperPolygon2D " + paper_polygon.name + " weights.")
					else:
						bones[bw_idx] = skel.bone_map[bone]
						weights[bw_idx] = weight
						total_weight += weight
						bw_count += 1
						bw_idx += 1
		
		# Normalizing the weights
		for j in range(bw_start_idx, bw_idx):
			weights[j] /= total_weight
		
		# Fill any remaining slots with 0
		for j in range(bw_count, max_bw):
			bones[bw_start_idx + j] = 0
			weights[bw_start_idx + j] = 0.0
	
	# Build indices
	var indices := PackedInt32Array()
	
	var polygon_total_size: int = 0
	for polygon: PackedInt32Array in polygon_indices:
		polygon_total_size += (polygon.size()) * 3
	
	indices.resize(polygon_total_size)
	
	var current_index: int = 0
	for polygon: PackedInt32Array in polygon_indices:
		var arr_size: int = polygon.size() - 1
		for i: int in range(arr_size, -1, -1):
			var a := (polygon[arr_size])
			var b := (polygon[i])
			var c := (polygon[i - 1])
			if a > vertex_count_minus_one or \
			   b > vertex_count_minus_one or \
			   c > vertex_count_minus_one:
				continue
			var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a]).normalized()
			
			indices[current_index] = a
			if normal.z < 0:
				indices[current_index + 1] = c
				indices[current_index + 2] = b
			else:
				indices[current_index + 1] = b
				indices[current_index + 2] = c
			current_index += 3
	
	# Apply subdivision
	if paper_polygon.subdivision_level > 0:
		for _level: int in paper_polygon.subdivision_level:
			var current_vertex_count := vertices.size()
			var current_index_count := indices.size()
			
			var unique_edges : Dictionary[Vector2i, bool] = {}
			for i in range(0, current_index_count, 3):
				var v0 := indices[i]
				var v1 := indices[i+1]
				var v2 := indices[i+2]
				var edges: Array[Vector2i] = [Vector2i(v0, v1),
											  Vector2i(v1, v2),
											  Vector2i(v2, v0)]
				for edge in edges:
					var e0 := mini(edge.x, edge.y)
					var e1 := maxi(edge.x, edge.y)
					unique_edges[Vector2i(e0, e1)] = true
			
			var num_new_vertices := unique_edges.size()
			var new_vertex_count := current_vertex_count + num_new_vertices
			var new_index_count := current_index_count * 4
			
			var new_vertices := PackedVector3Array()
			var new_uvs := PackedVector2Array()
			var new_normals := PackedVector3Array()
			var new_bones := PackedInt32Array()
			var new_weights := PackedFloat32Array()
			var new_indices := PackedInt32Array()
			
			new_vertices.resize(new_vertex_count)
			new_uvs.resize(new_vertex_count)
			new_normals.resize(new_vertex_count)
			new_bones.resize(new_vertex_count * max_bw)
			new_weights.resize(new_vertex_count * max_bw)
			new_indices.resize(new_index_count)
			
			# Copy existing vertex data
			for i in current_vertex_count:
				new_vertices[i] = vertices[i]
				new_uvs[i] = uvs[i]
				new_normals[i] = normals[i]
				if is_weighted:
					var bw_start_idx := i * max_bw
					for j in range(max_bw):
						var bw_idx := bw_start_idx + j
						new_bones[bw_idx] = bones[bw_idx]
						new_weights[bw_idx] = weights[bw_idx]
			
			var edge_map : Dictionary[Vector2i, int] = {}
			var current_new_vertex_idx := current_vertex_count
			
			# Iterate over unique edges to create new vertices and populate their data
			for edge_key: Vector2i in unique_edges.keys():
				var e0 := edge_key.x
				var e1 := edge_key.y
				
				# Calculate midpoint data with interpolated normal and bone weights
				var pos := (vertices[e0] + vertices[e1]) * 0.5
				var uv := (uvs[e0] + uvs[e1]) * 0.5
				var normal := ((normals[e0] + normals[e1]) * 0.5).normalized() # Normalize interpolated normal
				
				# Handle bone weights
				var bone_dict: Dictionary[int, float] = {}
				if is_weighted:
					var bw_start_e0 := e0 * max_bw
					var bw_start_e1 := e1 * max_bw
					for j in range(max_bw):
						var bw_e0 := bw_start_e0 + j
						var bw_e1 := bw_start_e1 + j
						
						var bone_idx0 := bones[bw_e0]
						var weight0 := weights[bw_e0]
						var bone_idx1 := bones[bw_e1]
						var weight1 := weights[bw_e1]
						
						if weight0 > 0.0:
							bone_dict[bone_idx0] = bone_dict.get(bone_idx0, 0.0) + weight0 * 0.5
						if weight1 > 0.0:
							bone_dict[bone_idx1] = bone_dict.get(bone_idx1, 0.0) + weight1 * 0.5
				
				# Store new vertex data
				new_vertices[current_new_vertex_idx] = pos
				new_uvs[current_new_vertex_idx] = uv
				new_normals[current_new_vertex_idx] = normal
				
				# Add bone and weight data
				if is_weighted:
					var bone_array := bone_dict.keys()
					var bw_start_idx := current_new_vertex_idx * max_bw
					for j in max_bw:
						var bw_idx := bw_start_idx + j
						if j < bone_array.size():
							var bone: int = bone_array[j]
							new_bones[bw_idx] = bone
							new_weights[bw_idx] = bone_dict[bone]
						else:
							new_bones[bw_idx] = 0
							new_weights[bw_idx] = 0.0
				
				edge_map[edge_key] = current_new_vertex_idx
				current_new_vertex_idx += 1
			
			var current_new_index_idx := 0
			for i in range(0, current_index_count, 3):
				var a := indices[i]
				var b := indices[i+1]
				var c := indices[i+2]
				
				# Get midpoint indices
				var mab := edge_map[Vector2i(mini(a, b), maxi(a, b))]
				var mbc := edge_map[Vector2i(mini(b, c), maxi(b, c))]
				var mca := edge_map[Vector2i(mini(c, a), maxi(c, a))]
				
				# Create new triangles
				# Triangle 1: a, mab, mca
				new_indices[current_new_index_idx] = a
				new_indices[current_new_index_idx + 1] = mab
				new_indices[current_new_index_idx + 2] = mca
				current_new_index_idx += 3
				
				# Triangle 2: mab, b, mbc
				new_indices[current_new_index_idx] = mab
				new_indices[current_new_index_idx + 1] = b
				new_indices[current_new_index_idx + 2] = mbc
				current_new_index_idx += 3
				
				# Triangle 3: mca, mbc, c
				new_indices[current_new_index_idx] = mca
				new_indices[current_new_index_idx + 1] = mbc
				new_indices[current_new_index_idx + 2] = c
				current_new_index_idx += 3
				
				# Triangle 4: mab, mbc, mca
				new_indices[current_new_index_idx] = mab
				new_indices[current_new_index_idx + 1] = mbc
				new_indices[current_new_index_idx + 2] = mca
				current_new_index_idx += 3
				
			# Update for next iteration
			vertices = new_vertices
			uvs = new_uvs
			normals = new_normals
			bones = new_bones
			weights = new_weights
			indices = new_indices
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	if is_weighted:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	
	# Set mesh flag based on maximum bone weight count
	var mesh_flags: int = 0
	if is_weighted and max_bw > 4:
		mesh_flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	
	var skinned_mesh := ArrayMesh.new()
	skinned_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mesh_flags)
	
	return skinned_mesh

#endregion

#region Material Management
## Updates materials for all mesh instances.
func update_all_materials() -> void:
	for paper_polygon: PaperPolygon2D in skel.name_to_paper_polygon.values():
		var mesh_instance: MeshInstance3D = paper_polygon.mesh_instance_3d
		create_material_from_paper_polygon(mesh_instance, paper_polygon)

## Creates and configures a [ShaderMaterial] for a mesh instance based on its source [PaperPolygon2D].
## [br][br]
## This function:
## [br][b]1.[/b] Creates the base material
## [br][b]2.[/b] Sets up shader parameters
## [br][b]3.[/b] Configures material chain
## [br][b]4.[/b] Caches shader data
## [br]
## [br][param mesh_instance]: Target [MeshInstance3D]
## [br][param paper_polygon]: Source PaperPolygon2D for material properties
func create_material_from_paper_polygon(mesh_instance: MeshInstance3D, paper_polygon: PaperPolygon2D) -> void:
	var shader_material: ShaderMaterial = create_base_material(paper_polygon)
	
	# Configure material chain based on parameter scope
	if skel._is_global_parameter_applicable(paper_polygon.name):
		setup_global_material_chain(shader_material, paper_polygon)
	else:
		setup_local_material_chain(shader_material, paper_polygon)
	
	mesh_instance.material_override = shader_material

## Creates a base [ShaderMaterial] with appropriate shader assignment.
## [br]
## [br][param paper_polygon]: Source [PaperPolygon2D] for shader determination
func create_base_material(paper_polygon: PaperPolygon2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = skel.get_shader_for_paper_polygon(paper_polygon.name)
	return material

## Configures a material chain using global parameters and passes.
## [br][br]
## Handles:
## [br][b]- Global parameter application[/b]
## [br][b]- Auto-parameter setup[/b]
## [br][b]- Next pass creation[/b]
## [br]
## [br][param base_material]: Starting [ShaderMaterial] in chain
## [br][param mesh_instance]: Target [MeshInstance3D]
## [br][param paper_polygon]: Source [PaperPolygon2D]
func setup_global_material_chain(base_material: ShaderMaterial, paper_polygon: PaperPolygon2D) -> void:
	# Apply base global parameters
	for param_name in skel.global_shader_params:
		var param_value = skel.global_shader_params[param_name]
		if param_value != null:
			base_material.set_shader_parameter(param_name, param_value)
	
	apply_auto_params_to_material(base_material, paper_polygon)
	
	# Create next pass chain
	var current_material := base_material
	for i in range(skel.global_next_pass_shaders.size()):
		current_material = create_next_pass(
			current_material,
			skel.global_next_pass_shaders[i],
			skel.global_next_pass_params[i] if i < skel.global_next_pass_params.size() else {},
			paper_polygon
		)

## Configures a material chain using local parameters and passes.
## [br][br]
## Similar to global chain setup, but uses:
## [br][b]- Local parameter overrides[/b]
## [br][b]- Local pass configurations[/b]
## [br]
## [br][param base_material]: Starting [ShaderMaterial] in chain
## [br][param mesh_instance]: Target [MeshInstance3D]
## [br][param paper_polygon]: Source [PaperPolygon2D]
func setup_local_material_chain(base_material: ShaderMaterial, paper_polygon: PaperPolygon2D) -> void:
	# Apply local parameters if they exist
	if skel.local_shader_params.has(paper_polygon.name):
		for param_name in skel.local_shader_params[paper_polygon.name]:
			var param_value = skel.local_shader_params[paper_polygon.name][param_name]
			if param_value != null:
				base_material.set_shader_parameter(param_name, param_value)
	
	apply_auto_params_to_material(base_material, paper_polygon)
	
	# Create next pass chain if local passes exist
	if skel.local_next_pass_shaders.has(paper_polygon.name):
		var current_material := base_material
		var local_shaders = skel.local_next_pass_shaders[paper_polygon.name]
		var local_params = skel.local_next_pass_params.get(paper_polygon.name, [])
		
		for i in range(local_shaders.size()):
			current_material = create_next_pass(
				current_material,
				local_shaders[i],
				local_params[i] if i < local_params.size() else {},
				paper_polygon
			)

## Creates and configures a next pass material in a material chain.
## [br][br]
## Returns the newly created material, or the current material if shader is null.
## [br]
## [br][param current_material]: Previous material in chain
## [br][param shader]: Shader for new pass
## [br][param params]: Parameter dictionary for new pass
## [br][param mesh_instance]: Target [MeshInstance3D]
## [br][param paper_polygon]: Source [PaperPolygon2D]
func create_next_pass(current_material: ShaderMaterial, shader: Shader,
					  params: Dictionary, paper_polygon: PaperPolygon2D) -> ShaderMaterial:
	if shader == null:
		return current_material
	
	var next_material = ShaderMaterial.new()
	next_material.shader = shader
	
	# Apply pass parameters
	for param_name in params:
		var param_value = params[param_name]
		if param_value != null:
			next_material.set_shader_parameter(param_name, param_value)
	
	# Apply auto parameters
	apply_auto_params_to_material(next_material, paper_polygon)
	
	current_material.next_pass = next_material
	return next_material

## Applies automatic shader auto-parameters to a material.
## [br][br]
## [br][param target_material]: Material to configure
## [br][param paper_polygon]: Source [PaperPolygon2D] for parameters
## [br][param mesh_instance]: Associated [MeshInstance3D]
func apply_auto_params_to_material(target_material: ShaderMaterial, paper_polygon: PaperPolygon2D) -> void:
	for i: int in skel.auto_params.size():
		var param: StringName = PaperSkeleton.auto_params.keys()[i]
		var value = (PaperSkeleton.auto_params.values()[i] as Callable).call(paper_polygon)
		
		target_material.set_shader_parameter(param, value)
	for i: int in paper_polygon.custom_texture_maps.size():
		var param := PaperPolygon2D.get_custom_texture_map_name(i)
		var value := paper_polygon.custom_texture_maps[i]
		
		target_material.set_shader_parameter(param, value)

## Updates all material auto-parameters for a specific [PaperPolygon2D]'s equivalent [MeshInstance3D].
## [br][br]
## [br][param paper_polygon]: Target PaperPolygon2D to update
func update_material_for_polygon(paper_polygon: PaperPolygon2D) -> void:
	paper_polygon.update_material_auto_params(range(skel.auto_params.size()) as PackedInt32Array)
	
	if paper_polygon.custom_texture_maps.is_empty():
		return
	
	var param_values: Dictionary[StringName, Variant] = {}
	for i: int in paper_polygon.custom_texture_maps.size():
		var param := PaperPolygon2D.get_custom_texture_map_name(i)
		var value := paper_polygon.custom_texture_maps[i]
		
		param_values[param] = value
	paper_polygon.update_material_params(param_values)

## Updates z-indices for all meshes based on their [PaperPolygon2D] sources.
func update_z_indices() -> void:
	calculate_z_indices()
	
	# Update all materials with new z-indices
	update_auto_params_for_all_polygons(INDEX_PARAMS)
	
	index_update = false

## Calculates paper-z-indices and group-micro-indices for all [PaperPolygon2D] sources.
## [br][br]
## [br][param assign_names]: Whether or not to assign names and PaperPolygon2Ds to dictionary.
func calculate_z_indices(assign_names: bool = false) -> void:
	var z_index_basket := {}
	_collect_polygons(skel.get_polygon_group(), z_index_basket)
	var sorted_polygons := []
	var sorted_indices := z_index_basket.keys()
	sorted_indices.sort()
	for z in sorted_indices:
		sorted_polygons.append_array(z_index_basket[z])
	
	# Resolve roots and z-basket polygons
	var root_map := {}
	var z_basket_index := 0
	var z_baskets := []
	for polygon: PaperPolygon2D in sorted_polygons:
		var root = resolve_root(polygon)
		if not root_map.has(root):
			root_map[root] = z_basket_index
			z_baskets.append([])
			z_basket_index += 1
		z_baskets[root_map[root]].append(polygon)
	
	# Assign z-basket-based z-indices
	for z_basket_id: int in z_baskets.size():
		for polygon: PaperPolygon2D in z_baskets[z_basket_id]:
			if assign_names:
				skel.name_to_paper_polygon[polygon.name] = polygon
				skel.cached_paper_polygon_to_name[polygon] = polygon.name
				if not polygon.renamed.is_connected(_on_paper_polygon_renamed):
					polygon.renamed.connect(_on_paper_polygon_renamed.bind(polygon))
			polygon.paper_z_index = z_basket_id
	
	# Remember how many shared the same group index
	var group_idx_to_polygon: Dictionary[int, Array]
	for polygon: PaperPolygon2D in sorted_polygons:
		var group_idx := polygon.get_group_idx()
		if !group_idx_to_polygon.has(group_idx):
			group_idx_to_polygon[group_idx] = []
		group_idx_to_polygon[group_idx].append(polygon)
	
	# Assign group micro indices
	for group_idx: int in group_idx_to_polygon.keys():
		var group := group_idx_to_polygon[group_idx]
		var num_polygons_in_group := group.size()
		if num_polygons_in_group == 1:
			var polygon: PaperPolygon2D = group[0]
			polygon.group_micro_index = 0.5
			continue
		for i: int in num_polygons_in_group:
			var polygon: PaperPolygon2D = group[i]
			var normalized_position_in_group: float = float(i) / float(num_polygons_in_group - 1)
			polygon.group_micro_index = 0.4 + (normalized_position_in_group * 0.2)
	
	skel.total_indices = z_basket_index

func _on_paper_polygon_renamed(paper_polygon: PaperPolygon2D) -> void:
	var old_name := skel.cached_paper_polygon_to_name[paper_polygon]
	var new_name := paper_polygon.name
	
	if old_name == new_name:
		return
	
	# Check for duplicate names
	if skel.name_to_paper_polygon.has(new_name):
		var existing_polygon := skel.name_to_paper_polygon[new_name]
		if existing_polygon != paper_polygon:
			# Revert the name change
			paper_polygon.name = old_name
			push_warning("PaperPolygon2D name '%s' is already in use. Reverting to '%s'." 
						% [new_name, old_name])
			return
	
	# Update dictionaries
	skel.name_to_paper_polygon.erase(old_name)
	skel.name_to_paper_polygon[new_name] = paper_polygon
	skel.cached_paper_polygon_to_name[paper_polygon] = new_name
	
	# Update other relevant dictionaries
	var dicts_to_update: Array[Dictionary] = [
		skel.local_shader_overrides, 
		skel.local_shader_params,
		skel.global_shader_param_overrides,
		skel.local_next_pass_shaders,
		skel.local_next_pass_params
	]
	
	for dict: Dictionary in dicts_to_update:
		if dict.has(old_name):
			dict[new_name] = dict[old_name]
			dict.erase(old_name)
	
	# Update mesh instance name
	var mesh_instance := paper_polygon.mesh_instance_3d
	if mesh_instance:
		mesh_instance.name = "%s_3d_mesh" % new_name
	
	if Engine.is_editor_hint():
		paper_polygon.notify_property_list_changed()
		notify_property_list_changed()

func defer_z_index_update():
	if !index_update:
		update_z_indices.call_deferred()
		index_update = true
#endregion

#region Miscellaneous
## Calculates the current layer space value.
## [br][br]
## Considers:
## [br][b]- Base layer space[/b]
## [br][b]- Paper rotation[/b]
## [br][b]- Space inversion[/b]
## [br][br]
## Returns the final calculated spacing between layers.
func calc_layer_space() -> float:
	cached_layer_space = skel.layer_space * skel.DEFAULT_SCALE
	if skel.reduce_space:
		cached_layer_space *= cos(skel.paper_rotate_flip)
	return cached_layer_space
#endregion

func update_auto_param_for_all_polygons(auto_param: PaperSkeleton.AutoParam):
	for paper_polygon: PaperPolygon2D in skel.name_to_paper_polygon.values():
		paper_polygon.update_material_auto_param(auto_param)

func update_auto_params_for_all_polygons(auto_params: PackedInt32Array):
	for paper_polygon: PaperPolygon2D in skel.name_to_paper_polygon.values():
		paper_polygon.update_material_auto_params(auto_params)
