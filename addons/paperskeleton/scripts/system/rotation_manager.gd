## A specialized class that manages rotation operations for [PaperSkeleton].
## This class centralizes all rotation-related functionality, including:
## [br][b]- Model flipping transformations[/b]
## [br][b]- Billboarding calculations[/b]
## [br][b]- Camera management[/b]
## [br][b]- Rotation node setup[/b]
extends RefCounted
class_name PaperSkeletonRotationManager

## Reference to the parent [PaperSkeleton] instance.
var skel: PaperSkeleton

## Initializes the rotation manager with a reference to [PaperSkeleton].
func _init(paper_skeleton: PaperSkeleton):
	skel = paper_skeleton

## Updates the flip transformation matrix.
## [br][br]
## This method handles:
## [br][b]- Model flipping[/b]: Applies X-axis flip if enabled
## [br][b]- Scaling[/b]: Applies uniform scaling based on size
## [br][b]- Rotation[/b]: Applies paper rotation around the up axis
func update_flip_transform() -> void:
	var flip_transform: Transform3D = Transform3D.FLIP_X if skel.flip_model else Transform3D.IDENTITY
	
	flip_transform = flip_transform.rotated(Vector3.UP, skel.paper_rotate_flip)
	
	skel.skeleton3d.set_bone_pose(skel.flip_bone_index, flip_transform)

## Updates the billboard transformation matrix.
## [br][br]
## This method manages:
## [br][b]- Cache validation[/b]: Checks if updates are necessary
## [br][b]- Position mode[/b]: Makes model face camera position
## [br][b]- Rotation mode[/b]: Matches camera's rotation
## [br][b]- Space inversion[/b]: Accounts for space inversion if enabled
## [br][br]
## The transformation is cached for performance optimization.
func update_billboard_transform() -> void:
	var camera_transform := skel.camera.global_transform
	var skeleton_transform := skel.global_transform
	
	# Cache check logic
	var did_skeleton_basis_not_change = skel.cached_skeleton_transform.basis == skeleton_transform.basis
	var did_camera_stay_still: bool = skel.cached_camera_transform.origin == camera_transform.origin \
									  if skel._is_position else skel.cached_camera_transform.basis == camera_transform.basis
	var did_skeleton_stay_still: bool = (skel.cached_skeleton_transform.origin == skeleton_transform.origin and did_skeleton_basis_not_change) \
										 if skel._is_position else did_skeleton_basis_not_change
	
	# If cache matches, return unless if an update is allowed.
	if skel.force_one_billboard_update:
		skel.force_one_billboard_update = false
	elif did_camera_stay_still and did_skeleton_stay_still:
		return
	
	# Update caches
	if !did_camera_stay_still:
		skel.cached_camera_transform = camera_transform
	if !did_skeleton_stay_still:
		skel.cached_skeleton_transform = skeleton_transform
	
	var look_target: Vector3
	var final_rotation: Vector3
	
	if skel._is_position:
		look_target = camera_transform.origin - skeleton_transform.origin
		var up_vector := skeleton_transform.basis.orthonormalized().y.normalized()
		var forward := look_target.normalized()
		var right := up_vector.cross(forward).normalized()
		forward = right.cross(up_vector).normalized()
		
		var look_basis := Basis(right, up_vector, forward)
		final_rotation = look_basis.get_euler()
	else:
		look_target = camera_transform.basis.z
		var current_rotation := skel.get_global_rotation()
		var target_yaw := atan2(look_target.x, look_target.z)
		
		final_rotation = Vector3(current_rotation.x, target_yaw, current_rotation.z)
	
	final_rotation -= skel.skeleton3d.global_rotation
	
	skel.skeleton3d.set_bone_pose_rotation(skel.billboard_bone_index, Quaternion.from_euler(final_rotation))

## Updates the camera reference.
## [br][br]
## This method:
## [br][b]- Handles camera override path[/b]
## [br][b]- Falls back to viewport camera[/b]
## [br][b]- Validates camera availability[/b]
## [br][b]- Manages error states[/b]
func cache_camera() -> void:
	if skel.camera_override.is_empty():
		var viewport := skel.get_viewport()
		
		skel.camera = (Engine.get_singleton(&"EditorInterface").get_editor_viewport_3d(0).get_camera_3d()
					   if Engine.is_editor_hint() else viewport.get_camera_3d()) \
					   if viewport else null
		
		if not skel.camera:
			var error_message := "No camera attached to viewport. Please either implement one, or add camera into override."
			if skel.cylindrical_billboarding:
				error_message += " Disabling cylindrical billboarding."
				push_error(error_message)
				skel.cylindrical_billboarding = false
			else:
				push_warning(error_message)
	else:
		skel.camera = skel.get_node_or_null(skel.camera_override)
		if not skel.camera:
			var error_message := "Camera override's path is invalid."
			if skel.cylindrical_billboarding:
				error_message += " Disabling cylindrical billboarding."
				push_error(error_message)
				skel.cylindrical_billboarding = false
			else:
				push_warning(error_message)
