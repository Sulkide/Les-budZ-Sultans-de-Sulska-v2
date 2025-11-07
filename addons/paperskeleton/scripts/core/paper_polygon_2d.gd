@tool
@icon("uid://paperpolyico")
extends Polygon2D
class_name PaperPolygon2D

## Reference to the parent PaperSkeleton
var paper_skeleton: PaperSkeleton = null:
	set(value):
		if paper_skeleton == value:
			return
		paper_skeleton = value
		notify_property_list_changed()

## Reference to the equivalent [MeshInstance3D]
var mesh_instance_3d: MeshInstance3D = null

## Reference to the calculated z-index of the equivalent [member mesh_instance_3d]
var paper_z_index: int = -1

## Reference to the group micro index to reduce z-fighting. Default value is just 0.5.
var group_micro_index: float = 0.5

const TEX_PARAMS: PackedInt32Array = [PaperSkeleton.AutoParam.TEXTURE,
									  PaperSkeleton.AutoParam.TEXTURE_EXISTS]
const TEX_FLIP_PARAMS: PackedInt32Array = [PaperSkeleton.AutoParam.FLIP_TEXTURE,
										   PaperSkeleton.AutoParam.FLIP_TEXTURE_EXISTS]

const TEX_CUSTOM_PARAM_PREFIX = "auto_custom_texture_%d"
const MAX_CUSTOM_TEX : int = 32 # 32 is already an absurd amount of individual texture maps.
								# If you think you need any more than this, please reconsider.

@export_tool_button("Reconstruct 3D Mesh", "MeshInstance3D")
var reconstruct_mesh_action := defer_3d_mesh_reconstruction 

## Controls the level of linear subdivision applied to equivalent mesh. 
## Higher values increase polygon count, but at a performance cost.
## [br][br]
## Generally speaking, unless if you are trying to do some visual
## tricks with vertex shader operations, there's no need to set
## this property to anything other than 0.
## [br][br]
## This value is maxed out at 5 in the inspector for safety reasons.
@export_range(0, 5, 1)
var subdivision_level: int = 0:
	set(value):
		subdivision_level = max(value, 0)
		defer_3d_mesh_reconstruction()

## Flag for deferred 3d mesh update
var mesh_update: bool = false

## Texture for the equivalent [MeshInstance3D] to swap to when the [PaperSkeleton]
## setup is flipped. 
@export
var flip_texture: Texture2D = null:
	set(value):
		if flip_texture == value:
			return
		flip_texture = value
		if paper_skeleton and paper_skeleton.is_ready:
			update_material_auto_params(TEX_FLIP_PARAMS)

## Optional custom textures with the `auto_custom_texture_` prefix for their shader uniforms.
## Helpful for swapping textures if each texture has unique material maps accompanying them.
@export_storage
var custom_texture_maps: Array[Texture2D] = []

## Cached generated [StringName]s for [member custom_texture_maps]
static var custom_texture_map_names: Array[StringName] = []

@export_group("Index Pointers")

## Points to another [PaperPolygon2D], so that a [PaperSkeleton] node can 
## copy its spacing index.
## [br][br]
## This basically exists to decrease needed spacing.
## Only apply this to instances that would logically never intersect/overlap.
@export
var polygon_to_copy_index_of: PaperPolygon2D = null:
	set(value):
		if value == polygon_to_copy_index_of:
			return
		elif !value or value == self:
			polygon_to_copy_index_of = null
		elif value.polygon_to_copy_index_of == self:
			push_error("Please don't attempt to paradoxically reference PaperPolygon2D's indices. " +
					   "You'll cause an infinite loop.")
			return
		else:
			polygon_to_copy_index_of = value
		if paper_skeleton:
			paper_skeleton.mesh_manager.defer_z_index_update()

## Points to another [PaperPolygon2D], so that a [PaperSkeleton] node can 
## take its spacing/group index to apply to an optional shader uniform. 
## [br][br]
## This only really exists for specialized next-pass border implementations.
## Decided that this would probably be easier than manually configuring each 
## instance's shader parameters. The data is sent to the `auto_mesh_z_group`
## shader uniform.
@export
var polygon_to_copy_group_index_of: PaperPolygon2D = null:
	set(value):
		if value == polygon_to_copy_group_index_of:
			return
		elif !value or value == self:
			polygon_to_copy_group_index_of = null
		else:
			polygon_to_copy_group_index_of = value
		if paper_skeleton:
			paper_skeleton.mesh_manager.defer_z_index_update()

func _init() -> void:
	set_notify_transform(true)

#region Setters, getters, and updaters

func update_material_auto_param(auto_param: PaperSkeleton.AutoParam) -> void:
	if !paper_skeleton or !paper_skeleton.polygon_group:
		return
	 
	var param: StringName = PaperSkeleton.auto_params.keys()[auto_param]
	var value = (PaperSkeleton.auto_params.values()[auto_param] as Callable).call(self)
	update_material_param(param, value)

func update_material_auto_params(auto_params: PackedInt32Array) -> void:
	if !paper_skeleton or !paper_skeleton.polygon_group:
		return
	 
	var current_mesh_material: ShaderMaterial = get_spatial_material()
	 
	# Update params in all passes
	while current_mesh_material:
		for i:int in auto_params:
			var param: StringName = PaperSkeleton.auto_params.keys()[i]
			var value = (PaperSkeleton.auto_params.values()[i] as Callable).call(self)
			current_mesh_material.set_shader_parameter(param, value)
		 
		current_mesh_material = current_mesh_material.next_pass as ShaderMaterial

func update_material_param(param: StringName, value: Variant) -> void:
	if !mesh_instance_3d:
		return
	 
	var current_mesh_material: ShaderMaterial = get_spatial_material()
	 
	# Update params in all passes
	while current_mesh_material:
		current_mesh_material.set_shader_parameter(param, value)
		current_mesh_material = current_mesh_material.next_pass as ShaderMaterial

func update_material_params(param_values: Dictionary[StringName, Variant]) -> void:
	if !mesh_instance_3d:
		return
	 
	var current_mesh_material: ShaderMaterial = get_spatial_material()
	 
	# Update params in all passes
	while current_mesh_material:
		for param_key in param_values.keys(): # Renamed 'param' to 'param_key' to avoid shadowing
			current_mesh_material.set_shader_parameter(param_key, param_values[param_key])
		 
		current_mesh_material = current_mesh_material.next_pass as ShaderMaterial

func update_color() -> void:
	update_material_auto_param(PaperSkeleton.AutoParam.COLOR)

func set_color_and_update(value: Color) -> void:
	set_color(value)
	update_color()

func update_offset():
	defer_3d_mesh_reconstruction()

func set_offset_and_update(value: Vector2):
	set_offset(value)
	update_offset()

func update_texture() -> void:
	update_material_auto_params(TEX_PARAMS)

func set_texture_and_update(value: Texture2D) -> void:
	set_texture(value)
	update_texture()

func update_texture_offset() -> void:
	update_material_auto_param(PaperSkeleton.AutoParam.OFFSET)

func set_texture_offset_and_update(value: Vector2) -> void:
	set_texture_offset(value)
	update_texture_offset()

func update_texture_scale() -> void:
	update_material_auto_param(PaperSkeleton.AutoParam.SCALE)

func set_texture_scale_and_update(value: Vector2) -> void:
	set_texture_scale(value)
	update_texture_scale()

func update_texture_rotation() -> void:
	update_material_auto_param(PaperSkeleton.AutoParam.ROTATION)
	 
func set_texture_rotation_and_update(value: float) -> void:
	set_texture_rotation(value)
	update_texture_rotation()

func update_z_index() -> void:
	if paper_skeleton and paper_skeleton.is_ready and paper_skeleton.polygon_group:
		paper_skeleton.mesh_manager.defer_z_index_update()

func set_z_index_and_update(value: int) -> void:
	set_z_index(value)
	update_z_index()

func update_z_as_relative() -> void:
	if paper_skeleton and paper_skeleton.is_ready and paper_skeleton.polygon_group:
		paper_skeleton.mesh_manager.defer_z_index_update()

func set_z_as_relative_and_update(value: bool) -> void:
	set_z_as_relative(value)
	update_z_as_relative()

func update_polygon() -> void:
	defer_3d_mesh_reconstruction()

func set_polygon_and_update(value: PackedVector2Array) -> void:
	set_polygon(value)
	update_polygon()

func update_uv() -> void:
	defer_3d_mesh_reconstruction()

func set_uv_and_update(value: PackedVector2Array) -> void:
	set_uv(value)
	update_uv()

func update_polygons() -> void:
	defer_3d_mesh_reconstruction()

func set_polygons_and_update(value: Array) -> void:
	set_polygons(value)
	update_polygons()

func get_mesh_instance_3d() -> MeshInstance3D:
	return mesh_instance_3d

func get_spatial_material() -> ShaderMaterial:
	return mesh_instance_3d.material_override as ShaderMaterial \
		if mesh_instance_3d else null

func set_subdivision_level(value: int) -> void:
	subdivision_level = value

func get_subdivision_level() -> int:
	return subdivision_level

func set_flip_texture(value: Texture2D) -> void:
	flip_texture = value

func get_flip_texture() -> Texture2D:
	return flip_texture

static func get_custom_texture_map_name(idx: int) -> StringName:
	var idx_limit: int = absi(idx) + 1
	if idx_limit > MAX_CUSTOM_TEX:
		push_warning("get_custom_texture_map_name(): Custom texture map count cannot exceed %d. Returning the current greatest custom texture map name." % MAX_CUSTOM_TEX)
		return custom_texture_map_names[-1]
	
	var current_size := custom_texture_map_names.size()
	if current_size < idx_limit:
		custom_texture_map_names.resize(idx_limit)
		for i: int in range(current_size, idx_limit):
			custom_texture_map_names[i] = StringName(TEX_CUSTOM_PARAM_PREFIX % i)
	
	return custom_texture_map_names[idx]

func update_custom_texture_map(idx: int):
	var idx_limit := absi(idx) + 1
	if idx_limit > get_custom_texture_map_size():
		push_warning("update_custom_texture_map(): Invalid index %d (size: %d)" % [idx, get_custom_texture_map_size()])
		return
	elif idx_limit > MAX_CUSTOM_TEX:
		push_error("update_custom_texture_map(): Custom texture map count cannot exceed %d." % MAX_CUSTOM_TEX)
		return
	
	var param_name := get_custom_texture_map_name(idx)
	var texture_value := custom_texture_maps[idx]
	update_material_param(param_name, texture_value)

func set_custom_texture_map_and_update(idx: int, new_texture: Texture2D):
	var idx_limit := absi(idx) + 1
	if idx_limit > MAX_CUSTOM_TEX:
		push_error("set_custom_texture_map_and_update(): Custom texture map count cannot exceed %d." % MAX_CUSTOM_TEX)
		return
	
	var size_changed := idx_limit > get_custom_texture_map_size()
	if size_changed:
		custom_texture_maps.resize(idx_limit)
	
	if custom_texture_maps[idx] != new_texture:
		custom_texture_maps[idx] = new_texture
		update_custom_texture_map(idx)
	
	if size_changed:
		notify_property_list_changed()

func get_custom_texture_map(idx: int) -> Texture2D:
	if absi(idx) + 1 > get_custom_texture_map_size():
		push_warning("get_custom_texture_map(): Invalid index for custom texture map array. Returning null value.")
		return null
	return custom_texture_maps[idx]

func set_custom_texture_map_size(size: int):
	if size > MAX_CUSTOM_TEX:
		push_error("set_custom_texture_map_size(): Custom texture map count cannot exceed %d." % MAX_CUSTOM_TEX)
		return
	
	var new_size := maxi(0, size)
	var old_size := get_custom_texture_map_size()
	
	if new_size == old_size:
		return
	
	custom_texture_maps.resize(new_size)
	notify_property_list_changed()
	
	if new_size >= old_size:
		return
	
	for idx: int in range(new_size, old_size):
		var param_name := get_custom_texture_map_name(idx)
		update_material_param(param_name, null)

func get_custom_texture_map_size() -> int:
	return custom_texture_maps.size()

func set_polygon_to_copy_index_of(value: PaperPolygon2D) -> void:
	polygon_to_copy_index_of = value

func get_polygon_to_copy_index_of() -> PaperPolygon2D:
	return polygon_to_copy_index_of

func set_polygon_to_copy_group_index_of(value: PaperPolygon2D) -> void:
	polygon_to_copy_group_index_of = value

func get_polygon_to_copy_group_index_of() -> PaperPolygon2D:
	return polygon_to_copy_group_index_of

## Gets the group index, falling back to the paper index if not set.
func get_group_idx() -> int:
	var target_polygon := polygon_to_copy_group_index_of \
						  if polygon_to_copy_group_index_of \
						  else self
	return target_polygon.paper_z_index

#endregion

#region Property Management
func _get_property_list() -> Array:
	var properties := []
	
	# Custom texture map properties
	var custom_texture_properties := [
		{
			"name": "Custom Texture Maps",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
			"hint_string": "custom_texture_maps/"
		},
		{
			"name": "custom_texture_maps/count",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,%d,1" % MAX_CUSTOM_TEX
		}
	]
	var ctp_size := get_custom_texture_map_size()
	custom_texture_properties.resize(ctp_size + 2)
	for i: int in ctp_size:
		custom_texture_properties[i + 2] = {
			"name": "custom_texture_maps/texture_%d" % i,
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Texture2D"
		}
	properties.append_array(custom_texture_properties)
	
	if paper_skeleton and paper_skeleton.is_ready and paper_skeleton.polygon_group:
		properties.append({"name": "Shader", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
		paper_skeleton.property_manager._add_polygon_shader_properties(properties, name, false)
	 
	return properties

func _set(property: StringName, value: Variant) -> bool:
	if !paper_skeleton or !paper_skeleton.is_ready or !paper_skeleton.polygon_group:
		if not (property.begins_with("custom_texture_maps/")):
			return false
	
	# Custom texture map properties
	if property == &"custom_texture_maps/count":
		set_custom_texture_map_size(value)
		return true
	
	elif property.begins_with("custom_texture_maps/texture_"):
		var prefix = "custom_texture_maps/texture_"
		var idx_str := property.substr(prefix.length())
		if idx_str.is_valid_int():
			var idx := idx_str.to_int()
			if idx >= 0 and idx < get_custom_texture_map_size():
				var old_texture := custom_texture_maps[idx]
				custom_texture_maps[idx] = value as Texture2D
				if old_texture != custom_texture_maps[idx]: # Only update if changed
					update_custom_texture_map(idx)
				return true
			else: # Count managed incorrectly
				return false 
		else: # Invalid index format
			return false
	
	if !paper_skeleton or !paper_skeleton.is_ready or !paper_skeleton.polygon_group:
		return false
	
	match property:
		&"color":
			set_color_and_update(value)
			return true
		&"offset":
			set_offset_and_update(value)
			return true
		&"texture":
			set_texture_and_update(value)
			return true
		&"texture_offset":
			set_texture_offset_and_update(value)
			return true
		&"texture_scale":
			set_texture_scale_and_update(value)
			return true
		&"texture_rotation":
			set_texture_rotation_and_update(value)
			return true
		&"z_index":
			set_z_index_and_update(value)
			return true
		&"z_as_relative":
			set_z_as_relative_and_update(value)
			return true
		&"polygon":
			set_polygon_and_update(value)
			return true
		&"uv":
			set_uv_and_update(value)
			return true
		&"polygons":
			set_polygons_and_update(value)
			return true
		&"shader_override":
			notify_property_list_changed()
			return paper_skeleton.set_local_shader_override(name, value)
		&"override_global_shader_param":
			paper_skeleton.set_global_shader_param_override(name, value)
			notify_property_list_changed()
			return true
	 
	if property.begins_with("params/"):
		var param_path := property.trim_prefix("params/")
		if param_path == "next_pass_shader":
			paper_skeleton.set_local_next_pass_shader(name, value, 0)
			notify_property_list_changed()
			return true
		elif param_path.begins_with("next_pass"):
			var parts := param_path.split("/")
			var pass_part := parts[0]
			var pass_index := pass_part.trim_prefix("next_pass").to_int()
			if parts.size() > 1:
				if parts[1] == "next_pass_shader":
					paper_skeleton.set_local_next_pass_shader(name, value, pass_index + 1)
					notify_property_list_changed()
					return true
				else:
					paper_skeleton.set_local_next_pass_param(name, pass_index, parts[1], value)
					return true
			else:
				return false
		else:
			paper_skeleton.set_local_shader_param(name, param_path, value)
			return true
	return false

func _get(property: StringName) -> Variant:
	# Custom texture map properties
	if property == &"custom_texture_maps/count":
		return get_custom_texture_map_size()
	
	elif property.begins_with("custom_texture_maps/texture_"):
		var prefix := "custom_texture_maps/texture_"
		var idx_str := property.substr(prefix.length())
		if idx_str.is_valid_int():
			var idx := idx_str.to_int()
			if idx >= 0 and idx < get_custom_texture_map_size():
				return custom_texture_maps[idx]
			else: # Index out of bounds
				return null 
		else: # Invalid index format
			return null
	
	if !paper_skeleton or !paper_skeleton.is_ready or !paper_skeleton.polygon_group:
		return null
	 
	match property: # Use property_path here
		&"shader_override":
			return paper_skeleton.get_local_shader_override(name)
		&"override_global_shader_param":
			return paper_skeleton.get_global_shader_param_override(name)
	 
	if property.begins_with("params/"): # Use property_str for begins_with
		var param_path := property.trim_prefix("params/")
		if param_path == "next_pass_shader":
			return paper_skeleton.get_local_next_pass_shader(name, 0)
		elif param_path.begins_with("next_pass"):
			var parts := param_path.split("/")
			var pass_part := parts[0]
			var pass_index := pass_part.trim_prefix("next_pass").to_int()
			if parts.size() > 1:
				if parts[1] == "next_pass_shader":
					return paper_skeleton.get_local_next_pass_shader(name, pass_index + 1)
				else:
					return paper_skeleton.get_local_next_pass_param(name, pass_index, parts[1])
			else:
				return null
		else:
			return paper_skeleton.get_local_shader_param(name, param_path)
	return null

func _property_get_revert(property: StringName) -> Variant:
	# Custom texture map properties
	if property == &"custom_texture_maps/count":
		return 0 # Default count is 0
	elif property.begins_with("custom_texture_maps/texture_"):
		return null # Default for a texture slot is null
	
	if !paper_skeleton or !paper_skeleton.is_ready or !paper_skeleton.polygon_group:
		return null
	 
	match property:
		&"shader_override":
			return null
		&"override_global_shader_param":
			return false
	 
	if property.begins_with("params/"):
		var param_path := property.trim_prefix("params/")
		if param_path == "next_pass_shader":
			return null
		elif param_path.begins_with("next_pass"):
			var parts := param_path.split("/")
			var pass_part := parts[0]
			var pass_index := pass_part.trim_prefix("next_pass").to_int()
			if parts.size() > 1:
				if parts[1] == "next_pass_shader":
					return null
				else:
					return paper_skeleton.get_default_local_next_pass_param(name, pass_index, parts[1])
			else:
				return null
		else:
			return paper_skeleton.get_default_local_shader_param(name, param_path)
	return null

func _property_can_revert(property: StringName) -> bool:
	# Custom texture maps
	if property == &"custom_texture_maps/count":
		return get_custom_texture_map_size() != 0
	elif property.begins_with("custom_texture_maps/texture_"):
		return _get(property) != null
	
	if !paper_skeleton or !paper_skeleton.is_ready or !paper_skeleton.polygon_group:
		return false
	 
	return _get(property) != _property_get_revert(property)

func _validate_property(property: Dictionary):
	match property.name:
		"reconstruct_mesh_action" when !paper_skeleton or !paper_skeleton.polygon_group:
			property.usage = PROPERTY_USAGE_NO_EDITOR
#endregion

func defer_3d_mesh_reconstruction() -> void:
	if !mesh_update:
		reconstruct_3d_mesh.call_deferred()
		mesh_update = true

func reconstruct_3d_mesh() -> void:
	if paper_skeleton and paper_skeleton.is_ready and paper_skeleton.polygon_group:
		paper_skeleton.mesh_manager.update_3d_mesh_from_paper_polygon.call_deferred(self)
	mesh_update = false

func _notification(what):
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			defer_3d_mesh_reconstruction()
		NOTIFICATION_VISIBILITY_CHANGED when mesh_instance_3d:
			mesh_instance_3d.visible = is_visible_in_tree()
