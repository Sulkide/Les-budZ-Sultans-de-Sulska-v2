@tool
@icon("uid://paperboneico")
extends Bone2D
class_name PaperBone2D

## Reference to the parent PaperSkeleton
var paper_skeleton: PaperSkeleton = null:
	set(value):
		if paper_skeleton == value:
			return
		paper_skeleton = value
		notify_property_list_changed()

func _init() -> void:
	set_notify_local_transform(true)
	
func _notification(what):
	match what:
		NOTIFICATION_LOCAL_TRANSFORM_CHANGED when paper_skeleton and paper_skeleton.polygon_group:
			paper_skeleton.bone_manager.update_bone_transform(self)

func _get_property_list() -> Array:
	if paper_skeleton and paper_skeleton.bone_map.has(self):
		return [
			{
				"name": "bone_modifiers/position",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
			},
			{
				"name": "bone_modifiers/rotation",
				"type": TYPE_VECTOR3,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-360,360,.5,or_greater,or_less,radians_as_degrees",
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
			},
			{
				"name": "bone_modifiers/scale",
				"type": TYPE_VECTOR3,
				"hint_string": ".005",
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
			}
		]
	return []

func _get(property: StringName):
	if not paper_skeleton or not paper_skeleton.bone_map.has(self):
		return null
	
	var bone_idx = paper_skeleton.bone_map[self]
	match property:
		"bone_modifiers/position":
			return paper_skeleton.get_bone_modifier_position(bone_idx)
		"bone_modifiers/rotation":
			return paper_skeleton.get_bone_modifier_rotation(bone_idx)
		"bone_modifiers/scale":
			return paper_skeleton.get_bone_modifier_scale(bone_idx)
	return null

func _set(property: StringName, value) -> bool:
	if not paper_skeleton or not paper_skeleton.bone_map.has(self):
		return false
	
	var bone_idx = paper_skeleton.bone_map[self]
	match property:
		"bone_modifiers/position":
			paper_skeleton.set_bone_modifier_position(bone_idx, value)
			return true
		"bone_modifiers/rotation":
			paper_skeleton.set_bone_modifier_rotation(bone_idx, value)
			return true
		"bone_modifiers/scale":
			paper_skeleton.set_bone_modifier_scale(bone_idx, value)
			return true
	return false

func _property_get_revert(property: StringName) -> Variant:
	match property:
		"bone_modifiers/position":
			return Vector3.ZERO
		"bone_modifiers/rotation":
			return Vector3.ZERO
		"bone_modifiers/scale":
			return Vector3.ONE
	return null

func _property_can_revert(property: StringName) -> bool:
	return _get(property) != _property_get_revert(property)
