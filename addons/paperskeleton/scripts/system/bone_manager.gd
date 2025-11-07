extends RefCounted
## A specialized class that manages bone operations for [PaperSkeleton].
## This class was created to handle all bone-related functionality,
## acting as a central manager for bone setup, validation, and updates.
class_name PaperSkeletonBoneManager

## Reference to the parent [PaperSkeleton] instance.
var skel: PaperSkeleton

## Initializes the bone manager with a reference to [PaperSkeleton].
func _init(paper_skeleton: PaperSkeleton):
	skel = paper_skeleton

#region Validation Methods
## Recursively checks [PaperPolygon2D] nodes for validation.
## [br][br]
## This method:
## [br][b]- Checks for duplicate polygon names[/b]
## [br][b]- Identifies [Skeleton2D] references[/b]
## [br][b]- Builds lists of found polygons and skeletons[/b]
## [br][b]- Converts any [Polygon2D] node to PaperPolygon2Ds
func _check_polygons(node: Node, polygon_names: Dictionary, found_skeletons: Array) -> void:
	if node is Polygon2D:
		var paper_polygon := skel.mesh_manager.convert_polygon_to_paper_polygon(node)
		
		# Check for duplicate names
		if polygon_names.has(paper_polygon.name):
			polygon_names[paper_polygon.name] += 1
		else:
			polygon_names[paper_polygon.name] = 1
		
		# Check for Skeleton2D reference
		var skeleton_path = paper_polygon.skeleton
		if not skeleton_path.is_empty():
			var potential_skeleton = paper_polygon.get_node(skeleton_path)
			if potential_skeleton is Skeleton2D:
				if !found_skeletons.has(potential_skeleton):
					found_skeletons.append(potential_skeleton)
	
	for child in node.get_children():
		_check_polygons(child, polygon_names, found_skeletons)

## Recursively checks [Bone2D] nodes for validation.
## [br][br]
## Builds a dictionary of bone names to validate uniqueness.
func _check_bones(skeleton: Node, bone_names: Dictionary) -> void:
	for child in skeleton.get_children():
		if child is Bone2D:
			if bone_names.has(child.name):
				bone_names[child.name] += 1
			else:
				bone_names[child.name] = 1
		_check_bones(child, bone_names)

## Validates the complete skeleton setup.
## [br][br]
## Performs comprehensive validation:
## [br][b]- Checks for [PaperPolygon2D] existence[/b]
## [br][b]- Verifies [Skeleton2D] reference[/b]
## [br][b]- Ensures single skeleton usage[/b]
## [br][b]- Validates name uniqueness[/b]
## [br][b]- Checks transform validity[/b]
## [br][br]
## Returns an [enum AssignmentError] value indicating validation status.
func validate_skeleton_setup(node: Node) -> int:
	# Check if there are any PaperPolygon2D nodes and valid Skeleton2D references
	var polygon_names := {}
	var found_skeletons := []
	
	_check_polygons(node, polygon_names, found_skeletons)
	
	# Check for PaperPolygon2D existence
	if polygon_names.is_empty():
		return skel.AssignmentError.NO_POLYGONS
	
	# Check for Skeleton2D existence
	if found_skeletons.is_empty():
		return skel.AssignmentError.NO_SKELETON
	
	# Check if there's more than one skeleton.
	if found_skeletons.size() > 1:
		return skel.AssignmentError.MULTIPLE_SKELETONS
	
	# Check for duplicate PaperPolygon2D names
	for count in polygon_names.values():
		if count > 1:
			return skel.AssignmentError.POLYGON_NAMES_NOT_UNIQUE
	
	# Check for duplicate bone names
	var bone_names := {}
	_check_bones(found_skeletons[0], bone_names)
	
	for count in bone_names.values():
		if count > 1:
			return skel.AssignmentError.BONE_NAMES_NOT_UNIQUE
	
	# Check if Skeleton2D global transform is equal to identity
	if found_skeletons[0].global_transform != Transform2D.IDENTITY:
		return skel.AssignmentError.SKELETON_TRANSFORM_NOT_IDENTITY
	
	return skel.AssignmentError.PASS
#endregion

#region Skeleton2D Operations
## Finds and sets the [Skeleton2D] reference.
## [br][br]
## Searches for a valid skeleton in the node hierarchy and assigns it.
func set_skeleton() -> void:
	if !skel.is_ready and !skel.stored_skeleton_2d_path.is_empty():
		skel.skeleton2d = skel.get_node_or_null(skel.stored_skeleton_2d_path)
		if skel.skeleton2d:
			return
	if !_find_skeleton_recursive(skel.polygon_group, true):
		push_warning("No Skeleton2D found in any Polygon2D's skeleton property.")

## Recursively searches for a [Skeleton2D] reference.
## [br][br]
## Returns [code]true[/code] if a valid skeleton is found.
## [param should_assign] Whether to assign the found skeleton
func _find_skeleton_recursive(node: Node, should_assign: bool) -> bool:
	# Check current node if it's a PaperPolygon2D
	if node is Polygon2D:
		var skeleton_path = node.skeleton
		if not skeleton_path.is_empty():
			var potential_skeleton = node.get_node(skeleton_path)
			if potential_skeleton is Skeleton2D:
				if should_assign:
					skel.skeleton2d = potential_skeleton
					_convert_bones_to_paperbones(skel.skeleton2d)
				
				return true
	
	# Recursively check children
	for child in node.get_children():
		if _find_skeleton_recursive(child, should_assign):
			return true
	
	return false

## Converts all [Bone2D] nodes under the skeleton to [PaperBone2D] nodes.
func _convert_bones_to_paperbones(skeleton: Skeleton2D):
	var queue: Array[Node] = skeleton.get_children()
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is Bone2D:
			if not node is PaperBone2D:
				node.set_script(PaperBone2D)
				print("Converted Bone2D instance \"%s\" to PaperBone2D" % node.name)
			
		queue.append_array(node.get_children())

## Populates bone data from [Skeleton2D].
## [br][br]
## Processes all [PaperPolygon2D] nodes to build bone weight mappings.
func populate_bone_data() -> void:
	if !skel.is_ready and !skel.stored_polygon_bone_data.is_empty():
		for bone_path: NodePath in skel.stored_polygon_bone_data.keys():
			var path_dict: Dictionary = skel.stored_polygon_bone_data[bone_path]
			var polygon_dict: Dictionary[PaperPolygon2D, PackedFloat32Array] = {}
			for polygon_path: NodePath in path_dict.keys():
				polygon_dict[skel.get_node(polygon_path) as PaperPolygon2D] = path_dict[polygon_path]
			skel.polygon_bone_data[skel.get_node(bone_path) as Bone2D] = polygon_dict
		return
	
	skel.polygon_bone_data.clear()
	if not skel.skeleton2d:
		push_warning("No Skeleton2D set. Cannot populate bone data.")
		return
	
	# Process all PaperPolygon2D nodes in the tree
	_process_polygons(skel.polygon_group)
	#print("Populated bone data for %d bones" % skel.polygon_bone_data.size())

## Recursively processes [PaperPolygon2D] nodes for bone data.
func _process_polygons(node: Node) -> void:
	# Process current node if it's a PaperPolygon2D
	if node is PaperPolygon2D:
		_process_polygon_bones(node)
	
	# Recursively process children
	for child in node.get_children():
		_process_polygons(child)

## Processes bone weights for a specific [PaperPolygon2D].
## [br][br]
## Validates weight counts per vertex and stores normalized weights to [member PaperSkeleton.polygon_bone_data].
func _process_polygon_bones(paper_polygon: PaperPolygon2D) -> void:
	var vertex_count = paper_polygon.polygon.size()
	
	# Process bones in pairs (name and weights)
	for i in range(0, paper_polygon.bones.size(), 2):
		var bone_path: String = paper_polygon.bones[i]
		var weights: PackedFloat32Array = paper_polygon.bones[i + 1]
		
		# Skip if weights are empty or invalid
		if _is_float32_array_empty(weights):
			continue
		
		if weights.size() != vertex_count:
			push_warning("Bone2D '%s' in Polygon2D '%s' has mismatched vertex (%d) and weight (%d) counts." %
						[bone_path, paper_polygon.name, vertex_count, weights.size()])
		
		# Get the bone using its full path relative to the skeleton
		var bone =_get_bone_by_path(bone_path)
		if bone:
			if not skel.polygon_bone_data.has(bone):
				var weight_dict: Dictionary[PaperPolygon2D, PackedFloat32Array] = {}
				skel.polygon_bone_data[bone] = weight_dict
			skel.polygon_bone_data[bone][paper_polygon] = weights
		else:
			push_warning("Bone2D '%s' not found in Skeleton2D." % bone_path)

## Checks if a [PackedFloat32Array] contains only zeros.
static func _is_float32_array_empty(float32_array: PackedFloat32Array) -> bool:
	for f in float32_array:
		if f > 0:
			return false
	return true

## Retrieves a [Bone2D] node using its path.
## [br][br]
## Handles both absolute and relative paths to find bones.
func _get_bone_by_path(bone_path: String) -> Bone2D:
	# If it's an absolute path (starts with "/"), make it relative to skeleton
	if bone_path.begins_with("/"):
		bone_path = bone_path.trim_prefix("/")
	
	# Try getting the bone directly using the path
	var bone = skel.skeleton2d.get_node_or_null(bone_path)
	if bone is Bone2D:
		return bone
	
	# If that fails, try to build the path from the skeleton
	var path_parts = bone_path.split("/")
	var current_node = skel.skeleton2d
	
	for part in path_parts:
		var found = false
		for child in current_node.get_children():
			if child.name == part:
				current_node = child
				found = true
				break
		if not found:
			return null
	
	return current_node as Bone2D if current_node is Bone2D else null
#endregion

#region Skeleton3D Operations
## Populates bone modifiers from storage.
## [br][br]
## Reconstructs store bone transformations into [EulerTransform3D] objects.
func populate_bone_modifiers() -> void:
	for bone_idx in skel.bone_transform_modifiers_storage.keys():
		var stored_modifier: Array = skel.bone_transform_modifiers_storage[bone_idx]
		skel.bone_transform_modifiers[bone_idx] = EulerTransform3D.new(
			stored_modifier[0],
			stored_modifier[1],
			stored_modifier[2],
			stored_modifier[3]
		)
	skel.bone_transform_modifiers_storage.clear()

## Adds the [Skeleton3D] node to the scene.
func add_skeleton3d() -> void:
	skel.add_child(skel.skeleton3d)

## Sets up the complete [Skeleton3D] hierarchy.
## [br][br]
## Converts [Skeleton2D] structure to 3D space and establishes bone relationships.
func setup_skeleton3d() -> void:
	skel.skeleton3d.set_transform(transform_2d_to_3d(skel.skeleton2d.global_transform))
	
	# Add root bone
	skel.billboard_bone_index = skel.skeleton3d.add_bone("PaperBillboardBone3D")
	skel.flip_bone_index = skel.skeleton3d.add_bone("PaperFlipBone3D")
	skel.scale_bone_index = skel.skeleton3d.add_bone("PaperScaleBone3D")
	
	for idx: int in [skel.billboard_bone_index, skel.flip_bone_index, skel.scale_bone_index]:
		skel.skeleton3d.set_bone_rest(idx, Transform3D.IDENTITY)
		skel.skeleton3d.reset_bone_pose(idx)
	
	skel.skeleton3d.set_bone_parent(skel.scale_bone_index, skel.flip_bone_index)
	skel.skeleton3d.set_bone_parent(skel.flip_bone_index, skel.billboard_bone_index)
	
	# Recursively gather all bones from Skeleton2D
	_setup_bone_recursive(skel.skeleton2d)
	
	# Set parent relationships
	for bone: Bone2D in skel.bone_map.keys():
		var bone_index: int = skel.bone_map[bone]
		var parent := bone.get_parent()
		if parent is Bone2D and skel.bone_map.has(parent):
			var parent_index: int = skel.bone_map[parent as Bone2D]
			skel.skeleton3d.set_bone_parent(bone_index, parent_index)
		else:
			skel.skeleton3d.set_bone_parent(bone_index, skel.scale_bone_index)
		(bone as PaperBone2D).paper_skeleton = skel 
	
	# Scale the root bone in accordance with the size property 
	skel.skeleton3d.set_bone_pose_scale(skel.scale_bone_index, Vector3(skel.size, skel.size, skel.size))

## Recursively sets up bones in [Skeleton3D].
## [br][br]
## Creates 3D bones corresponding to [Bone2D] nodes.
func _setup_bone_recursive(node: Node) -> void:
	if node is Bone2D:
		var bone_index := skel.skeleton3d.add_bone(node.name)
		var rest: Transform2D = node.rest
		var bone_rest := transform_2d_to_3d(rest)
		
		skel.skeleton3d.set_bone_rest(bone_index, bone_rest)
		skel.skeleton3d.reset_bone_pose(bone_index)
		
		skel.bone_map[node as Bone2D] = bone_index
	
	# Recursively process all children
	for child in node.get_children():
		_setup_bone_recursive(child)

## Updates [Skeleton3D] transform state.
## [br][br]
## Manually updates all bone transforms.
## Normally you shouldn't have to use this, so if this actually helps you,
## well, please let me know so that I can possibly fix whatever bug you're having.
func update_skeleton3d() -> void:
	for bone in skel.bone_map.keys():
		update_bone_transform(bone)

## Updates all bone modifiers.
## [br][br]
## Marks all bones as requiring transform updates.
func update_all_bone_modifiers() -> void:
	for bone_idx in skel.bone_transform_modifiers.keys():
		update_bone_transform(skel.skeleton2d.get_bone(bone_idx - 3))

## Updates transform for a specific bone.
## [br][br]
## Converts 2D bone transform to 3D space and applies modifiers.
func update_bone_transform(bone: Bone2D) -> void:
	var bone_idx: int = skel.bone_map[bone]
	
	var local_2d_transform := bone.get_transform()
	#local_2d_transform = skel.global_transform * local_2d_transform # this is useless because it doesn't work right anyway
	var local_3d_transform := transform_2d_to_3d(local_2d_transform)
	
	if skel.bone_transform_modifiers.has(bone_idx):
		var euler_transform_modifier: EulerTransform3D = skel.bone_transform_modifiers[bone_idx]
		var transform_modifier: Transform3D = euler_transform_modifier.get_transform()
		if transform_modifier != Transform3D.IDENTITY:
			var flip_modifier := cos(skel.paper_rotate_flip)
			
			if skel.flip_bone_modifiers and flip_modifier < 0:
				transform_modifier.basis = (Basis.FLIP_Z * transform_modifier.basis * Basis.FLIP_Z)
				transform_modifier.origin.z *= -1
			
			if !skel.retract_bone_modifiers or absf(flip_modifier) == 1.0:
				local_3d_transform *= transform_modifier
			else:
				var flattened_modifier := local_3d_transform
				
				var modifier_rotation := transform_modifier.basis.get_euler()
				flattened_modifier.basis = flattened_modifier.basis.rotated(Vector3.FORWARD, modifier_rotation.z)
				
				var modifier_scale := transform_modifier.basis.get_scale()
				flattened_modifier.basis = flattened_modifier.basis.scaled(Vector3(modifier_scale.x, modifier_scale.y, 1))
				
				var modifier_position := transform_modifier.origin
				flattened_modifier.origin += Vector3(modifier_position.x, modifier_position.y, 0)
				
				local_3d_transform = flattened_modifier.interpolate_with(local_3d_transform * transform_modifier, absf(flip_modifier))
	
	skel.skeleton3d.set_bone_pose(bone_idx, local_3d_transform)

## Converts a [Transform2D] to [Transform3D].
## [br][br]
## Handles conversion of:
## [br][b]- Rotation[/b]
## [br][b]- Scale[/b]
## [br][b]- Origin[/b]
## [br][b]- Skew (poorly)[/b]
## [param transform_2d] The 2D transform to convert
## [param z_axis] Optional Z-axis offset (default: 0.0)
## Converts a [Transform2D] to [Transform3D].
## [br][br]
## Handles conversion of:
## [br][b]- Rotation[/b]
## [br][b]- Scale[/b]
## [br][b]- Origin[/b]
## [br][b]- Skew (poorly)[/b]
## [param transform_2d] The 2D transform to convert
## [param z_axis] Optional Z-axis offset (default: 0.0)
func transform_2d_to_3d(transform_2d: Transform2D, z_axis: float = 0.0) -> Transform3D:
	var rotation_2d := transform_2d.get_rotation()
	var scale_2d := transform_2d.get_scale()
	var origin_2d := transform_2d.origin
	var skew_2d := transform_2d.get_skew()
	
	var combined_basis := Basis()
	
	# Pseudo-skew
	# This exists because Skeleton3D bones cannot shear properly.
	# This is because they reduce the basis to just rotate and scale.
	# As such, this is kind of a shoddy workaround that you're just gonna
	# have to deal with until:
	# A. They update the Skeleton3D system to support shearing.
	# B. I develop a hacky workaround that involves vertex shaders and a
	#    new bone hierarchy system.
	if skew_2d != 0:
		var skew_matrix := Basis()
		var skew_atan := atan(-skew_2d)
		skew_matrix.x.y = -skew_2d
		
		var skew_inv_lerp_y: float
		if skew_atan > 0:
			skew_inv_lerp_y = inverse_lerp(1,0,skew_atan)
		elif skew_atan < 0:
			skew_inv_lerp_y = inverse_lerp(-1,0,skew_atan)
		
		scale_2d.y *= skew_inv_lerp_y
		scale_2d.x += absf(skew_atan)
		origin_2d.y *= skew_inv_lerp_y
		
		combined_basis = combined_basis * skew_matrix
	
	combined_basis = combined_basis.scaled(Vector3(scale_2d.x, scale_2d.y, 1))
	combined_basis = combined_basis.rotated(Vector3(0, 0, -1), rotation_2d)
	
	var transform_3d := Transform3D(combined_basis)
	transform_3d.origin = Vector3(
		origin_2d.x * skel.DEFAULT_SCALE, 
		-origin_2d.y * skel.DEFAULT_SCALE, 
		z_axis
	)
	
	return transform_3d
