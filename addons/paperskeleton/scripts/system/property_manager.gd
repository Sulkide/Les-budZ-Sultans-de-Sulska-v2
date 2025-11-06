extends RefCounted
## A specialized class that manages properties for [PaperSkeleton].
## This class was created due to the complexity of the property system,
## acting as a central manager for all property-related operations.
class_name PaperSkeletonPropertyManager

## Reference to the parent [PaperSkeleton] instance.
var skel: PaperSkeleton

## Enumeration of supported property types for internal processing.
enum PropertyType {
	BONE_MODIFIER,          ## Properties related to bone transformations
	GLOBAL_SHADER,          ## Global shader parameters
	LOCAL_SHADER_OVERRIDE,  ## Local shader overrides for specific polygons
	GLOBAL_SHADER_OVERRIDE, ## Global shader parameter overrides
	LOCAL_SHADER,           ## Local shader parameters
	UNKNOWN                 ## Miscellaneous property types
}

## Internal class for processing and storing property information.
## This helper class parses property strings and extracts relevant components
## for easier handling of property operations.
class PropertyInfo:
	## The type of property being processed
	var type: PropertyType
	## Array of property path components
	var parts: PackedStringArray
	## Name of the bone (for bone modifiers)
	var bone_name: String = ""
	## Type of euler transformation
	var euler_type: String = ""
	## Name of the polygon
	var polygon_name: String = ""
	## Name of the parameter
	var param_name: StringName = &""
	## Index for next pass shaders/parameters
	var pass_index: int = -1
	## Flag indicating if property is for a next pass shader
	var is_next_pass_shader: bool = false
	
	## Constructs new PropertyInfo by parsing property string.
	## [br][br]
	## The constructor analyzes the property string and sets appropriate
	## fields based on the property path structure.
	func _init(property: String):
		parts = property.split("/")
		var category := parts[0] if parts.size() > 0 else ""
		
		match category:
			"bone_modifiers":
				type = PropertyType.BONE_MODIFIER
				if parts.size() >= 3:
					bone_name = parts[1]
					euler_type = parts[2]
			
			"global_shader_params":
				type = PropertyType.GLOBAL_SHADER
				if parts.size() >= 2:
					param_name = parts[1]
					if param_name == "next_pass_shader":
						is_next_pass_shader = true
						pass_index = 0
					elif param_name.begins_with("next_pass"):
						pass_index = param_name.trim_prefix("next_pass").to_int()
						if parts.size() >= 3:
							param_name = parts[2]
							is_next_pass_shader = param_name == "next_pass_shader"
							if is_next_pass_shader:
								pass_index += 1
			
			"local_shader_overrides":
				type = PropertyType.LOCAL_SHADER_OVERRIDE
				if parts.size() >= 2:
					polygon_name = parts[1]
			
			"override_global_shader_param":
				type = PropertyType.GLOBAL_SHADER_OVERRIDE
				if parts.size() >= 2:
					polygon_name = parts[1]
			
			"local_shader_params":
				type = PropertyType.LOCAL_SHADER
				if parts.size() >= 2:
					polygon_name = parts[1]
					if parts.size() >= 3:
						param_name = parts[2]
						if param_name == "next_pass_shader":
							is_next_pass_shader = true
							pass_index = 0
						elif param_name.begins_with("next_pass"):
							pass_index = param_name.trim_prefix("next_pass").to_int()
							if parts.size() >= 4:
								param_name = parts[3]
								is_next_pass_shader = param_name == "next_pass_shader"
								if is_next_pass_shader:
									pass_index += 1
			_:
				type = PropertyType.UNKNOWN

## Initializes the property manager with a reference to [PaperSkeleton].
func _init(paper_skeleton: PaperSkeleton):
	skel = paper_skeleton

## Gets a property value based on its type and path structure.
## [br][br]
## This method handles retrieving values for different property types:
## [br][b]- Bone modifiers[/b]: Returns position, rotation, or scale
## [br][b]- Global shader parameters[/b]: Returns shader or next pass values
## [br][b]- Local shader overrides[/b]: Returns polygon-specific shaders
## [br][b]- Shader parameter overrides[/b]: Returns override states
## [br][b]- Local shader parameters[/b]: Returns polygon-specific parameters
func _get(property: StringName) -> Variant:
	if property == &"refresh_indices":
		return skel.mesh_manager.defer_z_index_update
	
	var info := PropertyInfo.new(property)
	
	match info.type:
		PropertyType.BONE_MODIFIER:
			var bone_idx := skel.skeleton3d.find_bone(info.bone_name)
			if bone_idx == -1:
				return null
			
			match info.euler_type:
				"position":
					return skel.get_bone_modifier_position(bone_idx)
				"rotation":
					return skel.get_bone_modifier_rotation(bone_idx)
				"scale":
					return skel.get_bone_modifier_scale(bone_idx)
			
			skel.bone_is_overridden[bone_idx] = true
		
		PropertyType.GLOBAL_SHADER:
			if info.is_next_pass_shader:
				return skel.get_global_next_pass_shader(info.pass_index)
			elif info.pass_index != -1:
				return skel.get_global_next_pass_param(info.pass_index, info.param_name)
			else:
				return skel.get_global_shader_param(info.param_name)
		
		PropertyType.LOCAL_SHADER_OVERRIDE:
			return skel.get_local_shader_override(info.polygon_name)
		
		PropertyType.GLOBAL_SHADER_OVERRIDE:
			return skel.get_global_shader_param_override(info.polygon_name)
		
		PropertyType.LOCAL_SHADER:
			if info.is_next_pass_shader:
				return skel.get_local_next_pass_shader(info.polygon_name, info.pass_index)
			elif info.pass_index != -1:
				return skel.get_local_next_pass_param(info.polygon_name, info.pass_index, info.param_name)
			else:
				return skel.get_local_shader_param(info.polygon_name, info.param_name)
	
	return null

## Sets a property value based on its type and path structure.
## [br][br]
## This method handles setting values for different property types:
## [br][b]- Bone modifiers[/b]: Sets position, rotation, or scale
## [br][b]- Global shader parameters[/b]: Sets shader or next pass values
## [br][b]- Local shader overrides[/b]: Sets polygon-specific shaders
## [br][b]- Shader parameter overrides[/b]: Sets override states
## [br][b]- Local shader parameters[/b]: Sets polygon-specific parameters
## [br][br]
## Returns [code]true[/code] if the property was successfully set.
func _set(property: StringName, value: Variant) -> bool:
	var info := PropertyInfo.new(property)
	
	match info.type:
		PropertyType.BONE_MODIFIER:
			var bone_idx := skel.skeleton3d.find_bone(info.bone_name)
			if bone_idx == -1:
				return false
			
			match info.euler_type:
				"position":
					skel.set_bone_modifier_position(bone_idx, value)
				"rotation":
					skel.set_bone_modifier_rotation(bone_idx, value)
				"scale":
					skel.set_bone_modifier_scale(bone_idx, value)
			return true
		
		PropertyType.GLOBAL_SHADER:
			if info.is_next_pass_shader:
				skel.set_global_next_pass_shader(value, info.pass_index)
			elif info.pass_index != -1:
				skel.set_global_next_pass_param(info.pass_index, info.param_name, value)
			else:
				skel.set_global_shader_param(info.param_name, value)
			return true
		
		PropertyType.LOCAL_SHADER_OVERRIDE:
			return skel.set_local_shader_override(info.polygon_name, value)
		
		PropertyType.GLOBAL_SHADER_OVERRIDE:
			skel.set_global_shader_param_override(info.polygon_name, value)
			return true
		
		PropertyType.LOCAL_SHADER:
			if info.is_next_pass_shader:
				skel.set_local_next_pass_shader(info.polygon_name, value, info.pass_index)
			elif info.pass_index != -1:
				skel.set_local_next_pass_param(info.polygon_name, info.pass_index, info.param_name, value)
			else:
				skel.set_local_shader_param(info.polygon_name, info.param_name, value)
			return true
		
		PropertyType.UNKNOWN:
			match property:
				&"load_shader_preset":
					if value != null:
						(value as PaperSkeletonShaderPreset).apply_to_paper_skeleton(skel)
					return true
	
	return false

## Returns the default value for a property when reverting.
## [br][br]
## This method determines appropriate default values for:
## [br][b]- Bone modifiers[/b]: Zero for position/rotation, One for scale
## [br][b]- Shader parameters[/b]: Default values from shader metadata
## [br][b]- Override flags[/b]: [code]false[/code]
## [br][b]- Core properties[/b]: Type-specific defaults
func _property_get_revert(property: StringName) -> Variant:
	var info := PropertyInfo.new(property)
	
	match info.type:
		PropertyType.BONE_MODIFIER:
			var bone_idx := skel.skeleton3d.find_bone(info.bone_name)
			if bone_idx == -1:
				return null
			
			match info.euler_type:
				"position":
					return Vector3.ZERO
				"rotation":
					return Vector3.ZERO
				"scale":
					return Vector3.ONE
		
		PropertyType.GLOBAL_SHADER:
			if info.is_next_pass_shader:
				return null
			elif info.pass_index != -1:
				return skel.get_default_global_next_pass_param(info.pass_index, info.param_name)
			else:
				return skel.get_default_global_shader_param(info.param_name)
		
		PropertyType.LOCAL_SHADER_OVERRIDE:
			return null
		
		PropertyType.GLOBAL_SHADER_OVERRIDE:
			return false
		
		PropertyType.LOCAL_SHADER:
			if info.is_next_pass_shader:
				return null
			elif info.pass_index != -1:
				return skel.get_default_local_next_pass_param(info.polygon_name, info.pass_index, info.param_name)
			else:
				return skel.get_default_local_shader_param(info.polygon_name, info.param_name)
		
		PropertyType.UNKNOWN:
			match property:
				&"polygon_group":
					return null
				&"hide_polygons":
					return true
				&"cast_shadow":
					return GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				&"global_illumination_mode":
					return GeometryInstance3D.GIMode.GI_MODE_DISABLED
				&"size":
					return 1.0
				&"layer_space":
					return 1.0
				&"flip_model":
					return false
				&"paper_rotate_flip":
					return 0.0
				&"reduce_space":
					return false
				&"retract_bone_modifiers":
					return true
				&"flip_bone_modifiers":
					return true
				&"cylindrical_billboarding":
					return false
				&"camera_override":
					return null
				&"rotation_type":
					return skel.RotationType.POSITION
				&"frame_skip":
					return false
				&"frame_skip_value":
					return 1
				&"show_bone_modifiers":
					return false
				&"show_local_shader_properties":
					return false
	
	return null

## Determines if a property can be reverted to its default value.
## [br][br]
## Returns [code]true[/code] if the current value differs from the default value.
func _property_can_revert(property: StringName) -> bool:
	return _get(property) != _property_get_revert(property)

## Returns a list of properties for the editor inspector.
## [br][br]
## This method generates the complete property hierarchy including:
## [br][b]- Polygon properties[/b]
## [br][b]- Scale properties[/b]
## [br][b]- Flip properties[/b]
## [br][b]- Billboarding properties[/b]
## [br][b]- Shader properties[/b]
## [br][b]- Performance properties[/b]
func _get_property_list() -> Array:
	var properties = []
	
	# Add different categories of properties if the polygon group is selected.
	if skel.polygon_group:
		_add_polygon_properties(properties)
		_add_shading_properties(properties)
		_add_scale_properties(properties)
		_add_bone_transform_properties(properties)
		_add_flip_properties(properties)
		_add_billboarding_properties(properties)
		_add_shader_properties(properties)
	
	return properties

## Adds [PaperPolygon2D]-related properties to the inspector.
## [br][br]
## Currently only handles polygon visibility toggling.
func _add_polygon_properties(properties: Array) -> void:
	properties.append_array([
		{"name": "hide_polygons", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
	])

## Adds [PaperPolygon2D]-related properties to the inspector.
## [br][br]
## Currently only handles polygon visibility toggling.
func _add_shading_properties(properties: Array) -> void:
	properties.append_array([
		{"name": "Model Shading", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{
			"name": "cast_shadow",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Off,On,Double Sided,Shadows Only",
		},
		{
			"name": "global_illumination_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Disabled,Static,Dynamic",
		}
	])

## Adds model scaling properties to the inspector.
## [br][br]
## Includes overall size and layer spacing controls.
func _add_scale_properties(properties: Array) -> void:
	properties.append_array([
		{"name": "Model Scaling", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{"name": "size", "type": TYPE_FLOAT},
		{
			"name": "layer_space",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,100,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "refresh_indices",
			"type": TYPE_CALLABLE,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Recalculate Z-Indices,Sort",
			"usage": PROPERTY_USAGE_EDITOR
		},
	])

## Adds transform properties for each bone in the skeleton.
## [br][br]
## Generates position, rotation, and scale controls for every bone.
func _add_bone_transform_properties(properties: Array) -> void:
	properties.append_array([
		{"name": "Bone Modifiers", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{"name": "show_bone_modifiers", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
	])
	if skel.show_bone_modifiers:
		for bone in skel.polygon_bone_data.keys():
			properties.append_array([
				{
					"name": "bone_modifiers/" + bone.name + "/position",
					"type": TYPE_VECTOR3,
					"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
				},
				{
					"name": "bone_modifiers/" + bone.name + "/rotation",
					"type": TYPE_VECTOR3,
					"hint": PROPERTY_HINT_RANGE,
					"hint_string": "-360,360,.5,or_greater,or_less,radians_as_degrees",
					"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
				},
				{
					"name": "bone_modifiers/" + bone.name + "/scale",
					"type": TYPE_VECTOR3,
					"hint_string": ".005",
					"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
				}
			])

## Adds model flipping and space inversion properties.
## [br][br]
## Controls for various model transformation options.
func _add_flip_properties(properties: Array) -> void:
	properties.append_array([
		{"name": "Flip", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{"name": "flip_model", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "paper_rotate_flip",
		 "type": TYPE_FLOAT,
		 "hint": PROPERTY_HINT_RANGE,
		 "hint_string": "-180,180,.5,or_greater,or_less,radians_as_degrees",
		 "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "Paper Rotate Flip Properties", "type": TYPE_NIL, "usage": PROPERTY_USAGE_SUBGROUP},
		{"name": "reduce_space", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "retract_bone_modifiers", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "flip_bone_modifiers", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
	])

## Adds the complete shader property hierarchy to the inspector.
## [br][br]
## This method handles:
## [br][b]- Global shader override[/b]
## [br][b]- Global shader parameters[/b]
## [br][b]- Local shader overrides[/b]
## [br][b]- Next pass shaders and their parameters[/b]
func _add_shader_properties(properties: Array) -> void:
	# Add main shader group and global shader override
	properties.append_array([
		{
			"name": "Shader",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		},
		{
			"name": "load_shader_preset",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "PaperSkeletonShaderPreset",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "global_shader_override",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string":  "Shader",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "show_local_shader_properties",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		},
	])
	
	# Set up shader parameters based on global override or default shader
	var shader_to_use = skel.global_shader_override if skel.global_shader_override else skel.default_shader
	if shader_to_use:
		_add_global_shader_parameters(properties, shader_to_use)
		if skel.show_local_shader_properties:
			_add_local_shader_properties(properties)

## Adds global shader parameters and next pass configurations.
## [br][br]
## Handles the addition of:
## [br][b]- Next pass shader assignments[/b]
## [br][b]- Next pass parameter groups[/b]
func _add_global_shader_parameters(properties: Array, shader: Shader) -> void:
	# Add next pass shader property
	properties.append({
		"name": "global_shader_params/next_pass_shader",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Shader",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	_add_shader_param_group(properties, shader, "global_shader_params/")
	
	# Handle recursive next pass parameters
	_add_next_pass_parameters(properties, skel.global_next_pass_shaders, "global_shader_params/next_pass")

## Recursively adds parameters for next pass shaders.
## [br][br]
## For each next pass shader:
## [br][b]- Adds its parameters[/b]
## [br][b]- Adds its next pass shader assignment[/b]
## [br][b]- Processes subsequent passes recursively[/b]
func _add_next_pass_parameters(properties: Array, pass_shaders: Array, base_path: String) -> void:
	for i in range(pass_shaders.size()):
		var current_shader: Shader = pass_shaders[i]
		if current_shader == null:
			continue
		
		var current_path := base_path + str(i)
		var concat_path := current_path + "/"
		
		properties.append_array([
			{
				"name": current_path,
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_SUBGROUP,
				"hint_string": concat_path
			},
			{
				"name": current_path + "/next_pass_shader",
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": "Shader",
				"usage": PROPERTY_USAGE_DEFAULT
			}
		])
		
		_add_shader_param_group(properties, current_shader, concat_path)

## Adds a group of shader parameters to the property list.
## [br][br]
## Processes all shader parameters except auto-params, handling:
## [br][b]- Parameter visibility based on group settings[/b]
## [br][b]- Parameter type and hints[/b]
## [br][b]- Usage flags[/b]
func _add_shader_param_group(properties: Array, shader: Shader, path_prefix: String) -> void:
	for param in shader.get_shader_uniform_list(true):
		var name: StringName = param.name
		if !skel.auto_params.has(name) and !name.trim_prefix("auto_custom_texture_").is_valid_int():
			_add_shader_parameter_property(properties, param, path_prefix)

## Adds an individual shader parameter property to the list.
## [br][br]
## [br][b]- Parameter type and hints[/b]
## [br][b]- Property path construction[/b][br][br]
## [param param]: Dictionary containing parameter information[br]
## [param path_prefix]: Prefix for the property path[br]
func _add_shader_parameter_property(properties: Array, param: Dictionary, path_prefix: String) -> void:
	var property: Dictionary
	var name: StringName = param.name
	
	if param.usage in [PROPERTY_USAGE_GROUP, PROPERTY_USAGE_SUBGROUP]:
		property = {
			"name": path_prefix + name.replace("::", "/"),
			"type": param.type,
			"usage": PROPERTY_USAGE_SUBGROUP,
			"hint": param.hint,
			"hint_string": path_prefix
		}
	else:
		property = {
			"name": path_prefix + name,
			"type": param.type,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE,
			"hint": param.hint,
			"hint_string": param.hint_string
		}
	
	properties.append(property)

## Adds local shader properties for each polygon.
## [br][br]
## For each polygon in the skeleton:
## [br][b]- Adds shader override property[/b]
## [br][b]- Adds shader parameters if using local override[/b]
## [br][b]- Sets up next pass configurations[/b]
func _add_local_shader_properties(properties: Array) -> void:
	for paper_polygon_name: String in skel.name_to_paper_polygon.keys():
		_add_polygon_shader_properties(properties, paper_polygon_name)

## Adds shader properties for a specific polygon.
## [br][br]
## Sets up:
## [br][b]- Local shader override[/b]
## [br][b]- Shader parameters if override is active[/b][br][br]
## [param polygon_string]: The name of the polygon to add properties for[br]
## [param is_paper_skeleton]: Whether or not the properties are meant for the [PaperSkeleton] node
func _add_polygon_shader_properties(properties: Array, polygon_string: String, is_paper_skeleton: bool = true) -> void:
	var property_name := "local_shader_overrides/" + polygon_string if is_paper_skeleton else "shader_override"
	properties.append({
		"name": property_name,
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Shader",
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE,
	})
	
	var local_shader = skel.get_shader_for_paper_polygon(polygon_string)
	if local_shader:
		_add_local_shader_parameters(properties, polygon_string, local_shader, is_paper_skeleton)

## Adds local shader parameters for a specific polygon.
## [br][br]
## Handles:
## [br][b]- Global parameter override toggle[/b]
## [br][b]- Local parameter setup[/b]
## [br][b]- Next pass configurations[/b][br][br]
## [param polygon_string]: The name of the polygon to add parameters for[br]
## [param local_shader]: The shader to extract parameters from
## [param is_paper_skeleton]: Whether or not the properties are meant for the [PaperSkeleton] node
func _add_local_shader_parameters(properties: Array, polygon_string: String, local_shader: Shader, is_paper_skeleton: bool = true) -> void:
	var property_name := "override_global_shader_param/" + polygon_string if is_paper_skeleton else "override_global_shader_param"
	properties.append({
		"name": property_name,
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
	})
	
	var param_property_prefix := "local_shader_params/" + polygon_string + "/" if is_paper_skeleton else "params/"
	var has_local_override = (skel.local_shader_overrides.has(polygon_string) and
							  skel.local_shader_overrides[polygon_string] != null)
	if skel.global_shader_param_overrides.get(polygon_string, false) or has_local_override:
		properties.append({
			"name": param_property_prefix + "next_pass_shader",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Shader",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NONE
		})
		
		_add_shader_param_group(properties, local_shader,
								param_property_prefix)
		
		if skel.local_next_pass_shaders.has(polygon_string):
			_add_next_pass_parameters(
				properties,
				skel.local_next_pass_shaders[polygon_string],
				param_property_prefix + "next_pass"
			)

## Adds cylindrical billboarding properties to the inspector.
## [br][br]
## Sets up:
## [br][b]- Billboarding toggle[/b]: Enables/disables model rotation towards camera
## [br][b]- Camera override[/b]: Optional specific camera path
## [br][b]- Rotation type[/b]: Position-based or rotation-based (only when billboarding is enabled)
## [br][br]
## When billboarding is enabled, the model will either:
## [br][b]- Face the camera's position[/b] (Position mode)
## [br][b]- Match the camera's rotation[/b] (Rotation mode)
func _add_billboarding_properties(properties: Array) -> void:
	properties.append_array([
		{"name": "Billboarding", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP},
		{"name": "cylindrical_billboarding", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "camera_override", "type": TYPE_NODE_PATH, "usage": PROPERTY_USAGE_DEFAULT},
	])
	
	if skel.cylindrical_billboarding:
		properties.append({
			"name": "rotation_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Position,Rotation",
		})
