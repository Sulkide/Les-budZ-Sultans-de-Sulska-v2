@tool
@icon("uid://paperatchico")
extends Node3D
class_name PaperBoneAttachment3D

#region Constants
const WARN_NO_EXTERNAL := "External PaperSkeleton is not set."
const WARN_NO_PARENT_SKEL := "No PaperSkeleton found in parent hierarchy."
const WARN_SKELETON_MISSING := "PaperSkeleton's Skeleton3D is not generated."
const WARN_BONE_UNSET := "Bone name/index is not set."
const WARN_BONE_MISSING := "Bone '%s' not found in skeleton."
const WARN_NO_POLY_GROUP := "PaperSkeleton's polygon group hasn't been set."
#endregion

#region Configuration Properties
## The name of the bone to attach to in [member paper_skeleton]'s generated [Skeleton3D]
@export
var bone_name: StringName = &"PaperBillboardBone3D":
	set(value):
		if bone_name == value: 
			return
		bone_name = value
		_update_bone_idx()
		update_configuration_warnings()

## The index of the bone in the [Skeleton3D]. Updated automatically when bone_name changes
@export
var bone_idx: int = -1:
	set(value):
		if bone_idx == value: 
			return
		bone_idx = value
		_update_bone_name()
		update_configuration_warnings()

## When true, uses [member external_paper_skeleton] instead of searching parent hierarchy
@export
var use_external_paper_skeleton: bool = false:
	set(value):
		if use_external_paper_skeleton == value: 
			return
		use_external_paper_skeleton = value
		_find_paper_skeleton()
		notify_property_list_changed()
		update_configuration_warnings()

## Inverts the scale on the X axis when detected as flipped instead of rotating.
@export
var invert_x_scale_when_flipped: bool = false:
	set(value):
		if invert_x_scale_when_flipped == value: 
			return
		invert_x_scale_when_flipped = value

## External [PaperSkeleton] reference when [member use_external_paper_skeleton] is enabled
@export
var external_paper_skeleton: PaperSkeleton = null:
	set(value):
		if external_paper_skeleton == value: 
			return
		external_paper_skeleton = value
		if use_external_paper_skeleton:
			_find_paper_skeleton()
		notify_property_list_changed()
		update_configuration_warnings()
#endregion

#region Internal References
## Reference to target [PaperSkeleton] instance
var paper_skeleton: PaperSkeleton = null:
	set(value):
		if paper_skeleton == value: 
			return
		
		# Disconnect previous skeleton signals
		if paper_skeleton:
			if paper_skeleton.skeleton_constructed.is_connected( _on_skeleton_updated):
				paper_skeleton.skeleton_constructed.disconnect(_on_skeleton_updated)
			if paper_skeleton.skeleton_deconstructed.is_connected(_on_skeleton_updated):
				paper_skeleton.skeleton_deconstructed.disconnect(_on_skeleton_updated)
		
		paper_skeleton = value
		
		# Connect new skeleton signals
		if paper_skeleton:
			paper_skeleton.skeleton_constructed.connect(_on_skeleton_updated)
			paper_skeleton.skeleton_deconstructed.connect(_on_skeleton_updated)
			_cache_skeleton()
		
		_update_bone_idx()

## Reference to [member paper_skeleton]'s generated [Skeleton3D]
var skeleton3d: Skeleton3D = null

## Flag to prevent property update loops
var updating_bone_properties: bool = false
#endregion

#region Lifecycle Methods
func _ready():
	_find_paper_skeleton()

func _process(_delta: float):
	if !paper_skeleton or !skeleton3d or bone_idx == -1:
		return
	
	var bone_pose := skeleton3d.get_bone_global_pose(bone_idx)
	var final_global_bone_transform: Transform3D
	
	var model_x_flip := paper_skeleton.flip_model
	var model_effectively_flipped := paper_skeleton.is_paper_skeleton_flipped()
	
	var flip_det := model_effectively_flipped and (model_x_flip != invert_x_scale_when_flipped)
	var flip_calc := flip_det or (!model_effectively_flipped and model_x_flip)
	
	if flip_calc:
		var base_flip_component_for_node := Transform3D.FLIP_X if model_x_flip else Transform3D.IDENTITY
		var inverse_rotation_component_for_node := Transform3D.IDENTITY.rotated(Vector3.UP, -paper_skeleton.paper_rotate_flip)
		
		var inverse_flip_node_transform := inverse_rotation_component_for_node * base_flip_component_for_node
		var base_transform := skeleton3d.global_transform * inverse_flip_node_transform
		
		if flip_det and not model_x_flip:
			base_transform *= Transform3D.FLIP_X
		
		var rotated_base = base_transform.rotated(Vector3.UP, paper_skeleton.paper_rotate_flip)
		final_global_bone_transform = rotated_base * Transform3D.FLIP_X * bone_pose * Transform3D.FLIP_Z
	else:
		final_global_bone_transform = skeleton3d.global_transform * bone_pose
	
	global_transform = final_global_bone_transform

func _notification(what: int):
	if what == NOTIFICATION_PARENTED and !use_external_paper_skeleton:
		_find_paper_skeleton()
		update_configuration_warnings()
#endregion

#region Skeleton Management
## Caches reference to [member paper_skeleton]'s generated [Skeleton3D]
func _cache_skeleton() -> void:
	skeleton3d = paper_skeleton.skeleton3d if paper_skeleton and paper_skeleton.skeleton3d else null

## Handles skeleton reconstruction events
func _on_skeleton_updated() -> void:
	_update_bone_idx()
	_cache_skeleton()
	update_configuration_warnings()

## Finds parent [PaperSkeleton] in hierarchy when not using external reference
func _find_paper_skeleton() -> void:
	paper_skeleton = external_paper_skeleton if use_external_paper_skeleton else _find_parent_skeleton()
	_update_bone_idx()

## Searches parent nodes for [PaperSkeleton]
func _find_parent_skeleton() -> PaperSkeleton:
	var parent := get_parent()
	while parent:
		if parent is PaperSkeleton:
			return parent
		parent = parent.get_parent()
	return null
#endregion

#region Bone Management
## Updates [member bone_idx] based on current [member bone_name]
func _update_bone_idx() -> void:
	if !paper_skeleton or !skeleton3d:
		bone_idx = -1
		return
	bone_idx = skeleton3d.find_bone(bone_name)

## Updates [member bone_name] based on current [member bone_idx]
func _update_bone_name() -> void:
	if paper_skeleton and skeleton3d and bone_idx != -1:
		bone_name = skeleton3d.get_bone_name(bone_idx)
#endregion

#region Editor Integration
## Provides configuration warnings for common setup issues
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	var target_skel := paper_skeleton if use_external_paper_skeleton else _find_parent_skeleton()
	
	if !target_skel:
		warnings.append(WARN_NO_EXTERNAL if use_external_paper_skeleton else WARN_NO_PARENT_SKEL)
		return warnings
	
	if !target_skel.polygon_group:
		warnings.append(WARN_NO_POLY_GROUP)
		return warnings
	
	var skeleton: Skeleton3D = target_skel.skeleton3d
	if !skeleton:
		warnings.append(WARN_SKELETON_MISSING)
		return warnings
	
	if bone_name.is_empty():
		warnings.append(WARN_BONE_UNSET)
	elif skeleton.find_bone(bone_name) == -1:
		warnings.append(WARN_BONE_MISSING % bone_name)
	
	return warnings

## Controls property visibility and hints in inspector
func _validate_property(property: Dictionary):
	match property.name:
		"external_paper_skeleton" when !use_external_paper_skeleton:
			property.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE
#endregion
