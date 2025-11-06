@tool
@icon("uid://paperskelico")
extends Node3D
class_name PaperSkeleton

signal skeleton_constructed
signal skeleton_deconstructed

#region Core Properties
## The node that holds all of the [PaperPolygon2D]s that are associated with the [Skeleton2D] rig.
## The most important property needed for [PaperSkeleton] to function.
## [br][br]
## Things to note: [br]
## [b]1.[/b] It is assumed that all of the PaperPolygon2Ds share the same Skeleton2D. Not only
## [i]should[/i] you be doing it like this anyway, it will also not at all function properly if
## there are different Skeleton2Ds, so just don't set it up that way. [br]
## [b]2.[/b] You should probably assign this [i]after[/i] setting up all the PaperPolygon2D nodes
## and rigging it all to the Skeleton2D. The system isn't designed to auto-refresh the 3D meshes
## and keep up with their 2D equivalents. [br]
## [b]3.[/b] Make sure that the Skeleton2D's global transform is equivalent to
## [constant Transform2D.IDENTITY]. Can't really explain it, but it kinda bugs out otherwise.[br]
## [b]4.[/b] Give all of the PaperPolygon2Ds and [Bone2D]s unique names. For technical reasons, I
## need to store shader params under the PaperPolygon2Ds' names instead of the reference to it, as
## it refreshes upon reloading. As for the Bone2Ds, it both has to do with the confusing way that
## their paths are stored that makes them hard to retrieve if the names end up matching, and also
## their [Skeleton3D] bone equivalents need to have unique names anyways.[br]
## [b]5.[/b] Do not have more than 8 bones weighted on the same PaperPolygon2D's vertex. Aside from
## there being little practical applications for this, 3D meshes cannot store more than 8 bone 
## weights per vertex. [br]
## [b]6.[/b] Do not worry if you've set up your rig with regular [Polygon2D]s and [Bone2D]s. Both
## node types will be automatically converted to their relevant child classes. This is of course
## assuming that you aren't using some [i]other[/i] kind of special child classes based off those
## two nodes, which in that case, please don't do that.
@export
var polygon_group: Node = null:
	set(value):
		if is_ready:
			if value == null:
				_clear_paper_skeleton()
				polygon_group = value
			elif validate_polygon_group(value):
				_clear_paper_skeleton()
				polygon_group = value
				setup_paper_skeleton()
			notify_property_list_changed()
			if Engine.is_editor_hint():
				update_gizmos()  
		else:
			polygon_group = value
			
## Hides the [PaperPolygon2D]s by setting the visibility layer to 0.
## A hacky way to do it, but it's so that animations that
## involve toggling visibility remain compatible.
## [br][br]
## If you don't part of your 2D model to be plastered over the
## top-left corner of the screen, I'd advise that you keep this
## enabled during gameplay.
var hide_polygons: bool = true:
	set(value):
		hide_polygons = value
		if is_ready:
			mesh_manager.toggle_polygon_visibility()

## [ConfigFile] that the default shader is retrieved from.
static var config := ConfigFile.new()
static var config_loaded: bool = false

## Currently selected [Node3D] to act as the camera for when billboarding is activated.
var camera: Node3D

## Determines if [method _ready] has been ran yet.
var is_ready: bool = false

## Total amount of spacing indices in the PaperSkeleton setup.
var total_indices: int

## Scales the 3D mesh instances and bones.
## [br][br]
## Since a pixel on a Sprite3D is 0.01 meters, I figured that it would be appropriate
## to scale down the 3D display, as the meshes look massive otherwise.
const DEFAULT_SCALE := 0.01

## Index for the 3D billboard bone. Used for scaling purposes.
var billboard_bone_index: int = -1

## Index for the 3D flip bone. Used for scaling purposes.
var flip_bone_index: int = -1

## Index for the 3D scale bone. Used for scaling purposes.
var scale_bone_index: int = -1

#endregion

#region Property Display Toggles
## Whether or not the bone modifiers are all displayed at once on the
## [PaperSkeleton] node.
## [br][br]
## It's recommended to keep this disabled, as the generated property list can 
## get pretty long with particularly complex armatures. If you want to access
## these properties, it's recommended to just click on the [PaperBone2D] nodes,
## as the PaperSkeleton node transmits its bone mofifier properties onto those
## nodes for ease of access.
var show_bone_modifiers: bool = false:
	set(value):
		show_bone_modifiers = value
		notify_property_list_changed()

## Whether or not the properties for shader properties on individual meshes are
## all displayed at once on the [PaperSkeleton] node.
## [br][br]
## It's recommended to keep this disabled, as the generated property list can
## get pretty long with particularly complex shader configurations. If you want
## to access these properties, it's recommended to just click on the [PaperPolygon2D]
## nodes, as the PaperSkeleton node transmits its local shader properties onto
## those nodes for ease of access.
var show_local_shader_properties: bool = false:
	set(value):
		show_local_shader_properties = value
		notify_property_list_changed()
#endregion

#region Mapping Systems
## Maps names to their respective [PaperPolygon2D]s
var name_to_paper_polygon: Dictionary[StringName, PaperPolygon2D]= {}
## Maps [Bone2D]s to their 3D counterpart's index
var bone_map: Dictionary[Bone2D, int] = {}
#endregion

#region Component Managers
# Collection of specialized managers that contain functions for different 
# aspects of the PaperSkeleton system. The alternative was making this code
# stupidly long and impossible to navigate. If Godot ever provides partial 
# class support for GDScript, this is the first thing I'm changing up.
# "Why not just write it in C#?" Because then people will be forced to use the
# Godot .NET fork to use this, and I want this addon to be accessible as possible.

## Handles property operations
var property_manager := PaperSkeletonPropertyManager.new(self)
## Manages bone-related operations
var bone_manager     := PaperSkeletonBoneManager.new(self)
## Handles mesh generation and updates
var mesh_manager     := PaperSkeletonMeshManager.new(self)
## Controls rotation and billboarding
var rotation_manager := PaperSkeletonRotationManager.new(self)
#endregion

#region External Components
## Helper class to manually retrieve default shader uniform values.
static var shader_parser := ShaderParser.new()
#endregion

#region Skeleton Data Management
## Reference to original 2D skeleton
var skeleton2d: Skeleton2D

## Stores bone weights and influences for [PaperPolygon2D]s
var polygon_bone_data : Dictionary[Bone2D, Dictionary] = {}

## Generated 3D skeleton
var skeleton3d := Skeleton3D.new()
#endregion

#region Caching Systems
# For startup
@export_storage var stored_meshes: Dictionary[StringName, ArrayMesh] = {}
@export_storage var stored_skeleton_2d_path: NodePath
@export_storage var stored_polygon_bone_data: Dictionary[NodePath, Dictionary] = {}

# For frame-by-frame updates
var cached_camera_transform: Transform3D
var cached_skeleton_transform: Transform3D
var force_one_billboard_update: bool = false
var cached_default_shader_param_refresh: Dictionary[Shader, float] = {} # Editor only
var cached_flip_state = false

# For name changes
var cached_paper_polygon_to_name: Dictionary[PaperPolygon2D, StringName] = {}
#endregion

#region Shader Configuration
## Default shader
static var default_shader: Shader

## [Shader] uniforms that are automatically applied to each generated [MeshInstance3D].
static var auto_params : Dictionary[StringName, Callable] = {
	&"auto_albedo_texture":				func(polygon: Polygon2D) -> Texture2D: 
											return polygon.texture,
	&"auto_albedo_texture_exists":		func(polygon: Polygon2D) -> bool:
											return polygon.texture != null,
	&"auto_albedo_flip_texture":		func(paper_polygon: PaperPolygon2D)  -> Texture2D:
											return paper_polygon.flip_texture,
	&"auto_albedo_flip_texture_exists": func(paper_polygon: PaperPolygon2D) -> bool:
											return paper_polygon.flip_texture != null,
	&"auto_albedo_color":				func(polygon: Polygon2D) -> Color:
											return polygon.color,
	&"auto_albedo_uv_scale":			func(polygon: Polygon2D) -> Vector2:
											return polygon.texture_scale,
	&"auto_albedo_uv_offset":			func(polygon: Polygon2D) -> Vector2:
											return polygon.texture_offset,
	&"auto_albedo_uv_rotation":			func(polygon: Polygon2D) -> float:
											return polygon.texture_rotation,
	&"auto_mesh_size":					func(paper_polygon: PaperPolygon2D) -> float:
											return paper_polygon.paper_skeleton.size,
	&"auto_mesh_z_offset":				func(paper_polygon: PaperPolygon2D) -> float: 
											return paper_polygon.paper_skeleton.mesh_manager.cached_layer_space,
	&"auto_mesh_z_index":				func(paper_polygon: PaperPolygon2D) -> int:
											return paper_polygon.paper_z_index,
	&"auto_mesh_z_group":				func(paper_polygon: PaperPolygon2D) -> int:
											return paper_polygon.get_group_idx(),
	&"auto_mesh_z_group_micro_index":	func(paper_polygon: PaperPolygon2D) -> float:
											return paper_polygon.group_micro_index,
	&"auto_mesh_total_z_indices":		func(paper_polygon: PaperPolygon2D) -> int:
											return paper_polygon.paper_skeleton.total_indices,
	&"auto_mesh_normal_flip":			func(paper_polygon: PaperPolygon2D) -> float:
											return (-1.0 if paper_polygon.paper_skeleton.flip_model else 1.0) * \
												   signf(paper_polygon.paper_skeleton.size),
}:
	set(value):
		return # You're not supposed to edit this via code.

## Enum for easier parameter access
enum AutoParam {
	TEXTURE,                ## Main texture
	TEXTURE_EXISTS,         ## If there is a main texture
	FLIP_TEXTURE,           ## Flip texture
	FLIP_TEXTURE_EXISTS,    ## If there is a flip texture
	COLOR,                  ## Color tint
	SCALE,                  ## UV scaling
	OFFSET,                 ## UV offset
	ROTATION,               ## UV rotation
	MESH_SIZE,              ## Mesh size
	MESH_OFFSET,            ## Z-depth offset
	MESH_INDEX,             ## Layer ordering
	MESH_GROUP_INDEX,       ## Group layer ordering
	MESH_GROUP_MICRO_INDEX, ## Group layer micro-index
	MESH_TOTAL_INDICES,     ## Total number of layers
	MESH_NORMAL_FLIP,       ## Normal direction control
}
#endregion

enum AssignmentError {
	PASS,
	NO_POLYGONS,
	NO_SKELETON,
	MULTIPLE_SKELETONS,
	POLYGON_NAMES_NOT_UNIQUE,
	BONE_NAMES_NOT_UNIQUE,
	SKELETON_TRANSFORM_NOT_IDENTITY,
}

#region Model Shading Properties
var cast_shadow := GeometryInstance3D.ShadowCastingSetting.SHADOW_CASTING_SETTING_DOUBLE_SIDED:
	set(value):
		if cast_shadow == value:
			return
		cast_shadow = value
		if is_ready:
			for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
				paper_polygon.mesh_instance_3d.cast_shadow = cast_shadow

var global_illumination_mode := GeometryInstance3D.GIMode.GI_MODE_DISABLED:
	set(value):
		if global_illumination_mode == value:
			return
		global_illumination_mode = value
		if is_ready:
			for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
				paper_polygon.mesh_instance_3d.gi_mode = global_illumination_mode
#endregion

#region Model Scaling Properties
## Scale factor for the 3D model
var size: float = 1.0:
	set(value):
		if size == value:
			return
		var was_positive: bool = size > 0
		var is_positive: bool = value > 0
		var was_zero: bool = size == 0
		var is_zero: bool = value == 0
		size = value
		if is_ready and polygon_group:
			if scale_bone_index != -1:
				skeleton3d.set_bone_pose_scale(scale_bone_index, Vector3(size, size, size))
				mesh_manager.update_auto_param_for_all_polygons(AutoParam.MESH_SIZE)
				if was_positive != is_positive or \
				   was_zero != is_zero:
					mesh_manager.update_auto_param_for_all_polygons(AutoParam.MESH_NORMAL_FLIP)
			if Engine.is_editor_hint():
				update_gizmos()

## Distance between mesh layers to prevent Z-fighting
var layer_space: float = 1:
	set(value):
		if layer_space == value:
			return
		layer_space = value
		if is_ready:
			mesh_manager.calc_layer_space()
			mesh_manager.update_auto_param_for_all_polygons(AutoParam.MESH_OFFSET)
#endregion

#region Flip Transformation Properties
## Horizontal model flip
var flip_model: bool = false:
	set(value):
		flip_model = value
		if is_ready:
			rotation_manager.update_flip_transform()
			mesh_manager.update_auto_param_for_all_polygons(AutoParam.MESH_NORMAL_FLIP)
			_cache_flip_state()

## Rotates the model while applying modifiers. 
## Use this to achieve a quick and easy flip animation.
var paper_rotate_flip: float = 0:
	set(value):
		if paper_rotate_flip == value:
			return
		var old_value := paper_rotate_flip
		paper_rotate_flip = value
		if is_ready:
			rotation_manager.update_flip_transform()
			_cache_flip_state()
			if reduce_space:
				mesh_manager.calc_layer_space()
				mesh_manager.update_auto_param_for_all_polygons(AutoParam.MESH_OFFSET)
			if retract_bone_modifiers or (flip_bone_modifiers and signf(cos(paper_rotate_flip)) != signf(cos(old_value))):
				bone_manager.update_all_bone_modifiers()

## Reduce layer spacing during a flip.
## Amount is determined by [member paper_rotate_flip].
var reduce_space: bool = false:
	set(value):
		if reduce_space == value:
			return
		reduce_space = value
		if is_ready:
			mesh_manager.calc_layer_space()
			mesh_manager.update_auto_param_for_all_polygons(AutoParam.MESH_OFFSET)

## Retract bone modifiers during a flip.
## Amount is determined by [member paper_rotate_flip].
var retract_bone_modifiers: bool = true:
	set(value):
		if retract_bone_modifiers == value:
			return
		retract_bone_modifiers = value
		if is_ready:
			bone_manager.update_all_bone_modifiers()

## Flip bone modifiers after a flip.
## Flip state determined by [member paper_rotate_flip].
var flip_bone_modifiers: bool = true:
	set(value):
		if flip_bone_modifiers == value:
			return
		flip_bone_modifiers = value
		if is_ready:
			bone_manager.update_all_bone_modifiers()
#endregion

#region Bone Modifier Storage
# Bone modifiers for Skeleton3D
var bone_transform_modifiers: Dictionary[int, EulerTransform3D] = {}
@export_storage
var bone_transform_modifiers_storage: Dictionary[int, Array] = {}
#endregion

#region Cylindrical Billboarding Properties
## Controls whether model faces camera
var cylindrical_billboarding: bool = false:
	set(value):
		if cylindrical_billboarding == value:
			return
		cylindrical_billboarding = value
		if is_ready:
			force_one_billboard_update = true
			if cylindrical_billboarding:
				rotation_manager.cache_camera()
			else:
				skeleton3d.set_bone_pose_rotation(billboard_bone_index, Quaternion.IDENTITY)
			notify_property_list_changed()

## Optional camera override path
var camera_override := NodePath():
	set(value):
		if camera_override == value:
			return
		var new_camera = get_node_or_null(value)
		if new_camera is Node3D:
			camera_override = value
			camera = new_camera
		elif !new_camera:
			camera_override = NodePath()
			if is_ready:
				rotation_manager.cache_camera()
		else:
			printerr("Camera override is not a valid Node3D.")

enum RotationType {
	POSITION, ## Rotates to face the camera's position.
	ROTATION  ## Mimics the camera's rotation.
}

## Determines how the model is rotated.
var rotation_type := RotationType.POSITION:
	set(value):
		if rotation_type == value:
			return
		rotation_type = value
		force_one_billboard_update = true
		_is_position = (rotation_type == RotationType.POSITION)

# Since there's only two and it's gonna be checked every frame,
# may as well make it a boolean.
var _is_position: bool = (rotation_type == RotationType.POSITION)
#endregion

#region Shader Properties
## Overrides the default shader with the one put in here.
## Make sure that the shader can accept auto-params to
## allow it to it display properly. Look in the addon's
## "shaders" folder and its subsequent "includes" folder
## for references.
@export_storage
var global_shader_override: Shader:
	set(value):
		if global_shader_override == value:
			return
		if value != null and value.get_mode() != Shader.Mode.MODE_SPATIAL:
			push_warning("Only spatial shaders can be assigned.")
			return
		
		var old_shader = global_shader_override if global_shader_override else default_shader
		global_shader_override = value
		var new_shader = value if value else default_shader
		
		# Update all materials that don't have local overrides
		for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
			if not (local_shader_overrides.has(paper_polygon.name) and
					local_shader_overrides[paper_polygon.name] != null):
				
				# Check each parameter's type compatibility
				var params_to_remove := _get_incompatible_shader_params(old_shader, new_shader)
				
				# Remove incompatible parameters
				for param_name: StringName in params_to_remove:
					global_shader_params.erase(param_name)
				
				var mesh_instance = paper_polygon.mesh_instance_3d
				mesh_manager.create_material_from_paper_polygon(mesh_instance, paper_polygon)
		
		notify_property_list_changed()

## Stores global shader parameters
@export_storage
var global_shader_params: Dictionary[StringName, Variant] = {}

## Stores local shader overrides
@export_storage
var local_shader_overrides: Dictionary[StringName, Shader] = {}

## Stores local shader parameters
@export_storage
var local_shader_params: Dictionary[StringName, Dictionary] = {}

## Stores global param overrides
@export_storage
var global_shader_param_overrides: Dictionary[StringName, bool] = {}

## Stores global next pass shaders
@export_storage
var global_next_pass_shaders: Array[Shader] = []

## Stores global next pass parameters
@export_storage
var global_next_pass_params: Array[Dictionary] = []

## Stores local next pass shaders
@export_storage
var local_next_pass_shaders: Dictionary[StringName, Array] = {}

## Stores local next pass parameters
@export_storage
var local_next_pass_params: Dictionary[StringName, Array] = {}

var default_shader_params: Dictionary[Shader, Dictionary] = {}
#endregion

#region Getter and setter functions
## Returns the [Node] assigned as the polygon group
func set_polygon_group(new_polygon_group: Node) -> void:
	polygon_group = new_polygon_group

## Sets the polygon group directly through a [Node] reference.
## Validates and sets up the skeleton if the node is valid.
func get_polygon_group() -> Node:
	return polygon_group

## Sets the polygon group through a [NodePath].
## Will attempt to get the [Node] at the path and set it as the polygon group.
func set_polygon_group_path(node_path: NodePath) -> void:
	if node_path == null or node_path.is_empty():
		set_polygon_group(null)
		return
	var new_polygon_group := get_node_or_null(node_path)
	if new_polygon_group:
		set_polygon_group(new_polygon_group)
	else:
		printerr("\"" + String(node_path) + "\" is not a valid node path.")

## Returns the [NodePath] to the current polygon group [Node].
## Returns empty string if no polygon group is set.
func get_polygon_group_path() -> NodePath:
	if polygon_group:
		return polygon_group.get_path()
	return ""

## Sets whether [PaperPolygon2D]s should be hidden
func set_hide_polygons(value: bool) -> void:
	hide_polygons = value

## Gets whether [PaperPolygon2D]s are hidden
func get_hide_polygons() -> bool:
	return hide_polygons

## Sets the model size
func set_size(value: float) -> void:
	size = value

## Gets the model size
func get_size() -> float:
	return size

## Sets the space between mesh layers
func set_layer_space(value: float) -> void:
	layer_space = value

## Gets the space between mesh layers
func get_layer_space() -> float:
	return layer_space

## Sets whether model is flipped horizontally
func set_flip_model(value: bool) -> void:
	flip_model = value

## Gets whether model is flipped horizontally
func get_flip_model() -> bool:
	return flip_model

## Sets the paper rotation flip value
func set_paper_rotate_flip(value: float) -> void:
	paper_rotate_flip = value

## Gets the paper rotation flip value
func get_paper_rotate_flip() -> float:
	return paper_rotate_flip

## Sets whether cylindrical billboarding is enabled
func set_cylindrical_billboarding(value: bool) -> void:
	cylindrical_billboarding = value

## Gets whether cylindrical billboarding is enabled
func get_cylindrical_billboarding() -> bool:
	return cylindrical_billboarding

## Sets the camera override path
func set_camera_override(value: NodePath) -> void:
	camera_override = value

## Gets the camera override path
func get_camera_override() -> NodePath:
	return camera_override

## Sets the camera override through passing in a [Node3D].
## Assumes that the node has a valid [NodePath].
func set_camera_override_node(value: Node3D) -> void:
	camera_override = value.get_path()

## Gets the camera override node
func get_camera_override_node() -> Node3D:
	return get_node_or_null(camera_override) as Node3D

## Sets the rotation type for billboarding
func set_rotation_type(value: RotationType) -> void:
	rotation_type = value

## Gets the rotation type for billboarding
func get_rotation_type() -> RotationType:
	return rotation_type

## Sets the position modifier for a specific bone.
## Creates a new modifier if none exists.
func set_bone_modifier_position(bone_idx: int, mod_position: Vector3) -> void:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		euler_transform.set_position(mod_position)
	else:
		bone_transform_modifiers[bone_idx] = EulerTransform3D.new(mod_position)
	bone_manager.update_bone_transform(skeleton2d.get_bone(bone_idx - 3))

## Gets the position modifier for a specific bone.
## Returns [constant Vector3.ZERO] if no modifier exists.
func get_bone_modifier_position(bone_idx: int) -> Vector3:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		return euler_transform.get_position()
	return Vector3.ZERO

## Sets the rotation modifier for a specific bone.
## Creates a new modifier if none exists.
func set_bone_modifier_rotation(bone_idx: int, mod_rotation: Vector3) -> void:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		euler_transform.set_rotation(mod_rotation)
	else:
		bone_transform_modifiers[bone_idx] = EulerTransform3D.new(Vector3.ZERO, mod_rotation)
	bone_manager.update_bone_transform(skeleton2d.get_bone(bone_idx - 3))

## Gets the rotation modifier for a specific bone.
## Returns [constant Vector3.ZERO] if no modifier exists.
func get_bone_modifier_rotation(bone_idx: int) -> Vector3:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		return euler_transform.get_rotation()
	return Vector3.ZERO

## Sets the scale modifier for a specific bone.
## Creates a new modifier if none exists.
func set_bone_modifier_scale(bone_idx: int, mod_scale: Vector3) -> void:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		euler_transform.set_scale(mod_scale)
	else:
		bone_transform_modifiers[bone_idx] = EulerTransform3D.new(Vector3.ZERO, Vector3.ZERO, mod_scale)
	bone_manager.update_bone_transform(skeleton2d.get_bone(bone_idx - 3))

## Gets the scale modifier for a specific bone.
## Returns [constant Vector3.ONE] if no modifier exists.
func get_bone_modifier_scale(bone_idx: int) -> Vector3:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		return euler_transform.get_scale()
	return Vector3.ONE

## Sets the complete transform modifier for a specific bone.
## Automatically decomposes the transform into position, rotation, and scale.
func set_bone_modifier_transform(bone_idx: int, transform_3d: Transform3D) -> void:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		euler_transform.set_transform(transform_3d)
	else:
		var mod_position = transform_3d.origin
		var mod_rotation = transform_3d.basis.get_euler()
		var mod_scale = transform_3d.basis.get_scale()
		var euler_transform: EulerTransform3D = EulerTransform3D.new(mod_position, mod_rotation, mod_scale, transform_3d)
		bone_transform_modifiers[bone_idx] = euler_transform
	bone_manager.update_bone_transform(skeleton2d.get_bone(bone_idx - 3))

## Gets the complete transform modifier for a specific bone.
## Returns [constant Transform3D.IDENTITY] if no modifier exists.
func get_bone_modifier_transform(bone_idx: int) -> Transform3D:
	var bone_modifier_exists := bone_transform_modifiers.has(bone_idx)
	if bone_modifier_exists:
		var euler_transform: EulerTransform3D = bone_transform_modifiers[bone_idx]
		return euler_transform.get_transform()
	return Transform3D.IDENTITY

## Sets the global shader override
func set_global_shader_override(value: Shader) -> void:
	global_shader_override = value

## Gets the global shader override
func get_global_shader_override() -> Shader:
	return global_shader_override

## Sets a global shader parameter and updates all applicable materials.
## Will trigger property list update if parameter name starts with "group_".
func set_global_shader_param(param_name: StringName, value: Variant):
	global_shader_params[param_name] = value
	
	# Update materials with the new global parameter, but only for polygons
	# that don't have local overrides or param overrides enabled
	for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
		var material := paper_polygon.get_spatial_material()
		if material:
			# Skip if polygon has local shader override or param override enabled
			if !_is_global_parameter_applicable(paper_polygon.name):
				continue
			material.set_shader_parameter(param_name, value)

## Gets a global shader parameter value.
## Returns default value if parameter doesn't exist.
func get_global_shader_param(param_name: StringName) -> Variant:
	# Check if we have a global value
	if global_shader_params.has(param_name):
		return global_shader_params[param_name]
	else: # Return default value from shader
		return get_default_global_shader_param(param_name)

## Gets the default value for a global shader parameter.
## Returns default value from shader.
func get_default_global_shader_param(param_name: StringName) -> Variant:
	var shader: Shader = global_shader_override if global_shader_override else default_shader
	return get_default_shader_param(shader, param_name)

## Sets a local shader override for a specific [PaperPolygon2D].
## Returns false if shader is invalid.
func set_local_shader_override(polygon_name: StringName, shader: Shader) -> bool:
	if shader != null and shader.get_mode() != Shader.Mode.MODE_SPATIAL:
		push_warning("Only spatial shaders can be assigned.")
		return false
	
	var old_shader = local_shader_overrides.get(polygon_name, global_shader_override if global_shader_override else default_shader)
	local_shader_overrides[polygon_name] = shader
	var new_shader = shader if shader else (global_shader_override if global_shader_override else default_shader)
	
	# When shader override is set and matches global shader
	if shader != null and shader == (global_shader_override if global_shader_override else default_shader):
		# If local param override is enabled, initialize with global params
		if global_shader_param_overrides.get(polygon_name, false):
			if not local_shader_params.has(polygon_name):
				local_shader_params[polygon_name] = {} as Dictionary[StringName, Variant]
			
			# Copy global params to local params
			for param_name: StringName in global_shader_params.keys():
				local_shader_params[polygon_name][param_name] = global_shader_params[param_name]
	
	else:
		# Check existing local parameters for type compatibility
		if local_shader_params.has(polygon_name):
			var params_to_remove := _get_incompatible_shader_params(old_shader, new_shader)
			
			# Remove incompatible parameters
			for param_name: StringName in params_to_remove:
				local_shader_params[polygon_name].erase(param_name)
	
	# When shader override changes, recreate the material
	if name_to_paper_polygon.has(polygon_name):
		var paper_polygon: PaperPolygon2D = name_to_paper_polygon[polygon_name]
		var mesh_instance: MeshInstance3D = paper_polygon.mesh_instance_3d
		mesh_manager.create_material_from_paper_polygon(mesh_instance, paper_polygon)
	
	notify_property_list_changed()
	return true

## Gets the local shader override for a specific [PaperPolygon2D].
func get_local_shader_override(polygon_name: StringName) -> Shader:
	return local_shader_overrides.get(polygon_name)

## Sets a local shader parameter for a specific polygon.
## Creates parameter dictionary if none exists.
func set_local_shader_param(polygon_name: StringName, param_name: StringName, value: Variant) -> void:
	if not local_shader_params.has(polygon_name):
		local_shader_params[polygon_name] = {} as Dictionary[StringName, Variant]
	
	local_shader_params[polygon_name][param_name] = value
	
	# Update the specific polygon's material with the new parameter
	if name_to_paper_polygon.has(polygon_name):
		var paper_polygon: PaperPolygon2D = name_to_paper_polygon[polygon_name]
		var material: ShaderMaterial = paper_polygon.get_spatial_material()
		if material:
			material.set_shader_parameter(param_name, value)

## Gets a local shader parameter value.
## Returns default value if parameter doesn't exist.
func get_local_shader_param(polygon_name: StringName, param_name: StringName) -> Variant:
	# Check if we have a local value
	if local_shader_params.has(polygon_name) and local_shader_params[polygon_name].has(param_name):
		return local_shader_params[polygon_name][param_name]
	else: # If not, get default from shader
		return get_default_local_shader_param(polygon_name, param_name);

## Gets the default value for a local shader parameter.
func get_default_local_shader_param(polygon_name: StringName, param_name: StringName) -> Variant:
	var paper_polygon = name_to_paper_polygon[polygon_name]
	var shader = get_shader_for_paper_polygon(paper_polygon.name)
	return get_default_shader_param(shader, param_name)

## Sets whether a polygon uses global shader parameter override.
## Initializes local parameters with global values when enabled.
func set_global_shader_param_override(polygon_name: StringName, value: bool):
	var old_value: bool = get_global_shader_param_override(polygon_name)
	global_shader_param_overrides[polygon_name] = value
	
	var local_shader := get_shader_for_paper_polygon(polygon_name)
	var using_global_shader: bool = local_shader == (global_shader_override
													if global_shader_override
													else default_shader)
	
	if using_global_shader:
		if value and not old_value:
			# Initialize local params dictionary if it doesn't exist
			if not local_shader_params.has(polygon_name):
				local_shader_params[polygon_name] = {} as Dictionary[StringName, Variant]
			
			# Copy global params to local params with proper type handling
			for param_name: StringName in global_shader_params.keys():
				var param_value = global_shader_params[param_name]
				if param_value != null:
					local_shader_params[polygon_name][param_name] = param_value
			
			# Initialize local next pass arrays if they don't exist
			if not local_next_pass_shaders.has(polygon_name):
				local_next_pass_shaders[polygon_name] = [] as Array[Shader]
				local_next_pass_params[polygon_name] = [] as Array[Dictionary]
			
			# Copy global next passes to local next passes
			for i: int in global_next_pass_shaders.size():
				var shader: Shader = global_next_pass_shaders[i]
				var params := global_next_pass_params[i]
				
				while local_next_pass_shaders[polygon_name].size() <= i:
					local_next_pass_shaders[polygon_name].append(null)
					local_next_pass_params[polygon_name].append({} as Dictionary[StringName, Variant])
					
				local_next_pass_shaders[polygon_name][i] = shader
				local_next_pass_params[polygon_name][i] = params.duplicate()
		
		elif not value and old_value:
			# Clear local parameters
			if local_shader_params.has(polygon_name):
				local_shader_params.erase(polygon_name)
			if local_next_pass_shaders.has(polygon_name):
				local_next_pass_shaders.erase(polygon_name)
			if local_next_pass_params.has(polygon_name):
				local_next_pass_params.erase(polygon_name)
			
			if name_to_paper_polygon.has(polygon_name):
				var paper_polygon: PaperPolygon2D = name_to_paper_polygon[polygon_name]
				var mesh_instance: MeshInstance3D = paper_polygon.mesh_instance_3d
				
				# Rebuild material chain from scratch
				var base_material := ShaderMaterial.new()
				base_material.shader = local_shader
				
				# Set up auto params for base material
				mesh_manager.apply_auto_params_to_material(base_material, paper_polygon)
				
				# Set global parameters
				for param_name: StringName in global_shader_params:
					var param_value = global_shader_params[param_name]
					if param_value != null:
						base_material.set_shader_parameter(param_name, param_value)
				
				var current_material := base_material
				
				# Set up next passes
				for i: int in global_next_pass_shaders.size():
					var next_shader := global_next_pass_shaders[i]
					if next_shader == null:
						continue
					
					var next_material := ShaderMaterial.new()
					next_material.shader = next_shader
					
					# Set up auto params for next pass
					mesh_manager.apply_auto_params_to_material(next_material, paper_polygon)
					
					# Set global parameters for next pass
					if i < global_next_pass_params.size():
						for param_name: StringName in global_next_pass_params[i]:
							var param_value = global_next_pass_params[i][param_name]
							if param_value != null:
								next_material.set_shader_parameter(param_name, param_value)
					
					current_material.next_pass = next_material
					current_material = next_material
				
				mesh_instance.material_override = base_material
	
	notify_property_list_changed()

## Gets whether a polygon uses global shader parameter override.
func get_global_shader_param_override(polygon_name: StringName) -> bool:
	return global_shader_param_overrides.get(polygon_name, false);

## Sets a global next pass shader at specified index.
## Updates all materials using global parameters.
func set_global_next_pass_shader(shader: Shader, pass_index: int) -> void:
	while global_next_pass_shaders.size() <= pass_index:
		global_next_pass_shaders.append(null)
		global_next_pass_params.append({} as Dictionary[StringName, Variant])
	
	if shader != null and shader.get_mode() != Shader.MODE_SPATIAL:
		push_warning("Only spatial shaders can be assigned.")
		return
	
	var old_shader := global_next_pass_shaders[pass_index]
	global_next_pass_shaders[pass_index] = shader
	
	# Check parameter compatibility and remove incompatible ones
	if !global_next_pass_params.is_empty() and shader != null and old_shader != null:
		var params_to_remove := _get_incompatible_shader_params(old_shader, shader)
		
		# Remove incompatible parameters
		for param_name: StringName in params_to_remove:
			global_next_pass_params[pass_index].erase(param_name)
	
	# Update all materials that use global parameters
	for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
		if _is_global_parameter_applicable(paper_polygon.name):
			var base_material := paper_polygon.get_spatial_material()
			
			#Rebuild the entire pass chain to ensure clean replacement
			var current_material := base_material
			var current_pass := 0
			
			# Clear all existing next passes first
			while current_material and current_pass <= pass_index:
				var next_pass := current_material.next_pass as ShaderMaterial
				if current_pass == pass_index:
					# Create new material for this pass
					if shader:
						var new_material := ShaderMaterial.new()
						new_material.shader = shader
						
						# Set auto parameters
						mesh_manager.apply_auto_params_to_material(new_material, paper_polygon)
						
						# Set existing parameters from global_next_pass_params
						if pass_index < global_next_pass_params.size():
							for param_name in global_next_pass_params[pass_index]:
								new_material.set_shader_parameter(param_name,
									global_next_pass_params[pass_index][param_name])
						
						# Connect to subsequent passes if they exist
						if next_pass:
							new_material.next_pass = next_pass.next_pass
						
						current_material.next_pass = new_material
					else:
						# If shader is null, connect to subsequent passes
						if next_pass:
							current_material.next_pass = next_pass.next_pass
						else:
							current_material.next_pass = null
					break
				
				current_material = next_pass
				current_pass += 1
	
	notify_property_list_changed()

## Gets a global next pass shader at specified index.
func get_global_next_pass_shader(pass_index: int) -> Shader:
	if pass_index < global_next_pass_shaders.size():
		return global_next_pass_shaders[pass_index]
	return null

## Sets a global next pass parameter.
## Updates all materials using global parameters.
func set_global_next_pass_param(pass_index: int, param_name: StringName, value: Variant) -> void:
	while global_next_pass_params.size() <= pass_index:
		global_next_pass_params.append({} as Dictionary[StringName, Variant])
	
	global_next_pass_params[pass_index][param_name] = value
	
	# Update all materials that use global parameters
	for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
		if _is_global_parameter_applicable(paper_polygon.name):
			var current_material := paper_polygon.get_spatial_material()
			var current_pass := 0
			
			# Navigate to the specific pass we want to modify
			while current_material and current_pass < pass_index:
				current_material = current_material.next_pass as ShaderMaterial
				current_pass += 1
			
			# Set parameter only on the specific pass
			if current_material and current_material.next_pass:
				var pass_material := current_material.next_pass as ShaderMaterial
				if pass_material:
					pass_material.set_shader_parameter(param_name, value)

## Gets a global next pass parameter value.
func get_global_next_pass_param(pass_index: int, param_name: StringName) -> Variant:
	if pass_index < global_next_pass_params.size():
		var params := global_next_pass_params[pass_index]
		if params.has(param_name):
			return params[param_name]
	return get_default_global_next_pass_param(pass_index, param_name)

## Gets the default value for a global next pass parameter.
func get_default_global_next_pass_param(pass_index: int, param_name: StringName) -> Variant:
	if pass_index < global_next_pass_shaders.size():
		var shader = global_next_pass_shaders[pass_index]
		if shader:
			return get_default_shader_param(shader, param_name)
	return null

## Sets a local next pass shader for specific polygon.
func set_local_next_pass_shader(polygon_name: StringName, shader: Shader, pass_index: int) -> void:
	if !local_next_pass_shaders.has(polygon_name):
		local_next_pass_shaders[polygon_name] = [] as Array[Shader]
		local_next_pass_params[polygon_name] = [] as Array[Dictionary]
	
	var shaders := local_next_pass_shaders[polygon_name]
	var params := local_next_pass_params[polygon_name]
	
	while shaders.size() <= pass_index:
		shaders.append(null)
		params.append({} as Dictionary[StringName, Variant])
	
	if shader != null and shader.get_mode() != Shader.MODE_SPATIAL:
		push_warning("Only spatial shaders can be assigned.")
		return
	
	var old_shader: Shader = shaders[pass_index]
	shaders[pass_index] = shader
	
	# Check parameter compatibility and remove incompatible ones
	if shader != null and old_shader != null:
		var params_to_remove := _get_incompatible_shader_params(old_shader, shader)
			
		# Remove incompatible parameters
		for param_name: StringName in params_to_remove:
			params[pass_index].erase(param_name)
	
	if name_to_paper_polygon.has(polygon_name):
		var paper_polygon: PaperPolygon2D = name_to_paper_polygon[polygon_name]
		var mesh_instance: MeshInstance3D = paper_polygon.mesh_instance_3d
		var base_material := mesh_instance.material_override as ShaderMaterial
		
		#Rebuild the entire pass chain
		var current_material := base_material
		var current_pass := 0
		
		# Clear all existing next passes first
		while current_material and current_pass <= pass_index:
			var next_pass := current_material.next_pass as ShaderMaterial
			if current_pass == pass_index:
				# Create new material for this pass
				if shader:
					var new_material := ShaderMaterial.new()
					new_material.shader = shader
					
					# Set auto parameters
					mesh_manager.apply_auto_params_to_material(new_material, paper_polygon)
					
					# Set existing parameters from local_next_pass_params
					if pass_index < params.size():
						for param_name in params[pass_index]:
							new_material.set_shader_parameter(param_name,
															  params[pass_index][param_name])
					
					# Connect to subsequent passes if they exist
					if next_pass:
						new_material.next_pass = next_pass.next_pass
					
					current_material.next_pass = new_material
				else:
					# If shader is null, connect to subsequent passes
					if next_pass:
						current_material.next_pass = next_pass.next_pass
					else:
						current_material.next_pass = null
				break
			
			current_material = next_pass
			current_pass += 1
	
	notify_property_list_changed()

## Gets a local next pass shader for specific polygon.
func get_local_next_pass_shader(polygon_name: StringName, pass_index: int) -> Shader:
	if local_next_pass_shaders.has(polygon_name):
		var shaders = local_next_pass_shaders[polygon_name]
		if pass_index < shaders.size():
			return shaders[pass_index]
	return null

## Sets a local next pass parameter for specific polygon.
func set_local_next_pass_param(polygon_name: StringName, pass_index: int, param_name: StringName, value: Variant) -> void:
	if !local_next_pass_params.has(polygon_name):
		local_next_pass_params[polygon_name] = []
	
	var params := local_next_pass_params[polygon_name]
	
	while params.size() <= pass_index:
		params.append({} as Dictionary[StringName, Variant])
	
	params[pass_index][param_name] = value
	
	# Update the specific polygon's material
	if name_to_paper_polygon.has(polygon_name):
		var paper_polygon: PaperPolygon2D = name_to_paper_polygon[polygon_name]
		var current_material := paper_polygon.get_spatial_material()
		var current_pass := 0
		
		# Navigate to the specific pass we want to modify
		while current_material and current_pass < pass_index:
			current_material = current_material.next_pass as ShaderMaterial
			current_pass += 1
		
		# Set parameter only on the specific pass
		if current_material and current_material.next_pass:
			var pass_material := current_material.next_pass as ShaderMaterial
			if pass_material:
				pass_material.set_shader_parameter(param_name, value)

## Gets a local next pass parameter value for specific polygon.
func get_local_next_pass_param(polygon_name: StringName, pass_index: int, param_name: StringName) -> Variant:
	if local_next_pass_params.has(polygon_name):
		var params := local_next_pass_params[polygon_name]
		if pass_index < params.size():
			var param_dict = params[pass_index]
			if param_dict.has(param_name):
				return param_dict[param_name]
	return get_default_local_next_pass_param(polygon_name, pass_index, param_name)

## Gets the default value for a local next pass parameter.
func get_default_local_next_pass_param(polygon_name: StringName, pass_index: int, param_name: StringName) -> Variant:
	if local_next_pass_shaders.has(polygon_name):
		var shaders := local_next_pass_shaders[polygon_name]
		if pass_index < shaders.size():
			var shader: Shader = shaders[pass_index]
			if shader:
				return get_default_shader_param(shader, param_name)
	return null

## Gets the number of global next passes.
func get_global_next_pass_count() -> int:
	return global_next_pass_shaders.size()

## Gets the number of local next passes for a specific polygon.
func get_local_next_pass_count(polygon_name: StringName) -> int:
	if local_next_pass_shaders.has(polygon_name):
		return local_next_pass_shaders[polygon_name].size()
	return 0

## Gets the appropriate shader for a specific polygon.
## Considers local and global overrides.
func get_shader_for_paper_polygon(polygon_name: StringName) -> Shader:
	if local_shader_overrides.has(polygon_name):
		var local_override: Shader = local_shader_overrides[polygon_name]
		if local_override != null:
			return local_override
	
	if global_shader_override != null:
		return global_shader_override
	
	return default_shader

## Internal helper to check if global parameters apply to a polygon
func _is_global_parameter_applicable(polygon_2d_name: String) -> bool:
	return !(local_shader_overrides.get(polygon_2d_name) != null or
			 global_shader_param_overrides.get(polygon_2d_name, false))

## Compares two [Shader]s, and returns an [Array] of parameters that do not have the same type.
func _get_incompatible_shader_params(old_shader: Shader, new_shader: Shader) -> Array[StringName]:
	if not old_shader or not new_shader:
		return []
	
	var params_to_remove: Array[StringName] = []
	var new_param_types: Dictionary[StringName, int] = {}
	
	# Build lookup table for new shader params
	for param: Dictionary in new_shader.get_shader_uniform_list():
		new_param_types[param.name] = param.type
	
	# Single pass through old shader params
	for param: Dictionary in old_shader.get_shader_uniform_list():
		var new_type: int = new_param_types.get(param.name, TYPE_NIL)
		if new_type == TYPE_NIL or new_type != param.type:
			params_to_remove.append(param.name)
	
	return params_to_remove

## Retrieves the default shader param from a stored dictionary. Runs
## [method _populate_default_shader_params] if it is not already stored, or
## if it is being run in the editor to ensure that code changes are properly
## accounted for.
func get_default_shader_param(shader: Shader, param_name: StringName) -> Variant:
	# Only check for refresh in editor
	if Engine.is_editor_hint():
		# Initialize refresh time if not set
		if !cached_default_shader_param_refresh.has(shader):
			cached_default_shader_param_refresh[shader] = Time.get_unix_time_from_system()
			
		# Check if 2 seconds has passed since last refresh
		var current_time := Time.get_unix_time_from_system()
		var should_refresh: bool = current_time - cached_default_shader_param_refresh[shader] > 2
		
		if should_refresh or !default_shader_params.has(shader):
			_populate_default_shader_params(shader)
			cached_default_shader_param_refresh[shader] = current_time
	# In game, just populate if not already stored
	elif !default_shader_params.has(shader):
		_populate_default_shader_params(shader)
	
	return default_shader_params[shader].get(param_name, null)

## Populates the default shader parameters dictionary for a specific shader.
## The dictionary is organized hierarchically by shader and parameter name.
## [param shader] Shader to extract parameters from
func _populate_default_shader_params(shader: Shader) -> void:
	if !default_shader_params.has(shader):
		default_shader_params[shader] = {} as Dictionary[StringName, Variant]
	
	for param in shader.get_shader_uniform_list():
		var param_type: Variant.Type = param.type
		var param_default = null
		
		# Handle default value extraction for supported types
		if param_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT,
						 TYPE_VECTOR2, TYPE_VECTOR2I,
						 TYPE_VECTOR3, TYPE_VECTOR3I,
						 TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR,
						 TYPE_BASIS, TYPE_TRANSFORM2D, TYPE_PROJECTION]:
			param_default = shader_parser.get_shader_default_value(shader, param.name)
			
			# Special handling for color parameters
			if param_type == TYPE_COLOR:
				var param_color := Color(param_default.x, param_default.y, param_default.z)
				if param.hint != PropertyHint.PROPERTY_HINT_COLOR_NO_ALPHA:
					param_color.a = param_default.w
				param_default = param_color
		
		# Store just the default value
		default_shader_params[shader][param.name] = param_default

#endregion

#region Property getter and setter functions
## Handles property list generation for the editor.
func _get_property_list():
	return property_manager._get_property_list()

## Handles property setting from the editor.
func _set(property: StringName, value: Variant) -> bool:
	return property_manager._set(property, value)

## Handles property getting from the editor.
func _get(property: StringName) -> Variant:
	return property_manager._get(property)

## Handles property revert value getting.
func _property_get_revert(property: StringName) -> Variant:
	return property_manager._property_get_revert(property)

## Handles property revert possibility checking.
func _property_can_revert(property: StringName) -> bool:
	return property_manager._property_can_revert(property)
#endregion

#region Lifecycle Methods
## Initializes the node and loads configuration.
func _init() -> void:
	_assign_config_values()
	_cache_flip_state()

## Loads configuration values from [code]plugin.cfg[/code] to initialize the default shader.
## This method reads the shader UID/path from the config and loads it, displaying errors if failed.
func _assign_config_values() -> void:
	if !config_loaded:
		# Get this script's directory
		var script_path: String = get_script().get_path().get_base_dir()
		
		# Load the config file (UIDs don't work for config files apparently)
		var error := config.load(script_path.path_join("../../plugin.cfg"))
		if error != OK:
			push_error("Failed to load config and default shader. Make sure there is a properly defined \"plugin.cfg\" file in the root of the PaperSkeleton addon folder.")
			config_loaded = false
			return
		else:
			config_loaded = true
	
	if !default_shader:
		# Load the shader
		var default_shader_uid: String = config.get_value("default", "paper_shader")
		if not default_shader_uid:
			push_error("Failed to load default shader. Please ensure that \"paper_shader\" is defined in the \"[default]\" section of \"plugin.cfg\"")
			return
		
		var is_uid := default_shader_uid.begins_with("uid://")
		if is_uid:
			default_shader = load(default_shader_uid);
		else:
			default_shader = load(default_shader_uid) if default_shader_uid.begins_with("res://") else load(default_shader_uid.path_join("../../" + default_shader_uid))
		if not default_shader:
			push_error("Failed to load default shader. Please ensure that '" + default_shader_uid + \
					   "' exists or has a properly defined UID or path in the \"[default]\" section of \"plugin.cfg\".")

## Sets up the node when entering scene tree.
func _ready() -> void:
	bone_manager.populate_bone_modifiers()
	_add_children()
	if polygon_group != null:
		setup_paper_skeleton()
	stored_meshes.clear()
	stored_polygon_bone_data.clear()
	is_ready = true

## Adds required child nodes.
func _add_children() -> void:
	bone_manager.add_skeleton3d()

## Handles per-frame updates.
func _process(_delta: float) -> void:
	if polygon_group and cylindrical_billboarding and camera:
		rotation_manager.update_billboard_transform()

## Sets up the complete paper skeleton system.
func setup_paper_skeleton() -> void:
	polygon_group.child_order_changed.connect(mesh_manager.defer_z_index_update)
	bone_manager.set_skeleton()
	bone_manager.populate_bone_data()
	bone_manager.setup_skeleton3d()
	mesh_manager.calc_layer_space()
	mesh_manager.calculate_z_indices(true)
	mesh_manager.create_3d_meshes()
	bone_manager.update_skeleton3d()
	rotation_manager.cache_camera()
	rotation_manager.update_flip_transform()
	mesh_manager.toggle_polygon_visibility()
	skeleton_constructed.emit()

## Refreshes the polygon group, also handling deletions of now unused storage data.
func refresh_polygon_group() -> void:
	if validate_polygon_group(polygon_group):
		# Cache the currently existing polygon and bone names
		var polygons_to_remove: Array[StringName] = []
		var current_bone_names: Dictionary[StringName, bool] = {}
		
		for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
			if !is_instance_valid(paper_polygon):
				polygons_to_remove.append(paper_polygon.name)
		
		# Collect current bone names
		for bone: Bone2D in bone_map.keys():
			if is_instance_valid(bone):
				current_bone_names[bone.name] = true
		
		for polygon_name: StringName in polygons_to_remove:
			local_shader_overrides.erase(polygon_name)
			local_shader_params.erase(polygon_name)
			global_shader_param_overrides.erase(polygon_name)
			local_next_pass_shaders.erase(polygon_name)
			local_next_pass_params.erase(polygon_name)
			print(polygon_name + " has been killed.")
		
		# Clean up deleted bones from bone modifiers
		var bones_to_remove: Array[int] = []
		for bone_idx: int in bone_transform_modifiers.keys():
			var bone_name: String = skeleton3d.get_bone_name(bone_idx)
			if not current_bone_names.has(bone_name):
				bones_to_remove.append(bone_idx)
				print(bone_name + " has been killed.")
		
		for bone_idx: int in bones_to_remove:
			bone_transform_modifiers.erase(bone_idx)
		
		# Get rid of session data and reconstruct the rig.
		_clear_session_data()
		setup_paper_skeleton()
	else:
		push_warning("Refreshing was prevented due to the \"" + polygon_group.name
				   + "\" Polygon Group now being detected as invalid. Please solve the error.")

## Clears the entire paper skeleton setup.
func _clear_paper_skeleton() -> void:
	_clear_session_data()
	_clear_storage_data()
	skeleton_deconstructed.emit()

## Clears session-specific data.
func _clear_session_data() -> void:
	# Disconnect z-index update function
	if polygon_group and polygon_group.child_order_changed.is_connected(mesh_manager.defer_z_index_update):
		polygon_group.child_order_changed.disconnect(mesh_manager.defer_z_index_update)
	
	# Clear mesh instances
	for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
		var mesh_instance := paper_polygon.mesh_instance_3d
		paper_polygon.mesh_instance_3d = null
		paper_polygon.paper_z_index = -1
		mesh_instance.free()
		paper_polygon.renamed.disconnect(mesh_manager._on_paper_polygon_renamed)
	
	# Clear bones
	skeleton3d.clear_bones()
	
	# Make sure to unhide Polygon2Ds
	if hide_polygons:
		hide_polygons = false
		is_ready = false
		hide_polygons = true
		is_ready = true
	
	# Clear all dictionaries
	name_to_paper_polygon.clear()
	cached_paper_polygon_to_name.clear()
	polygon_bone_data.clear()
	bone_map.clear()

## Clears stored configuration data.
func _clear_storage_data() -> void:
	# Clear all dictionaries
	bone_transform_modifiers_storage.clear()
	bone_transform_modifiers.clear()
	global_shader_params.clear()
	local_shader_overrides.clear()
	local_shader_params.clear()
	global_shader_param_overrides.clear()
	global_next_pass_shaders.clear()
	global_next_pass_params.clear()
	local_next_pass_shaders.clear()
	local_next_pass_params.clear()

## Validates polygon group setup.
func validate_polygon_group(node: Node) -> bool:
	var err := bone_manager.validate_skeleton_setup(node)
	if err == AssignmentError.PASS:
		return true
	else:
		var error_message := "If you get this message, the developer forgot to write the error message for this error. Please inform him."
		match err:
			AssignmentError.NO_POLYGONS:
				error_message = "No Polygon2Ds detected within the \"" + node.name + "\" node."
			AssignmentError.NO_SKELETON:
				error_message = "No Skeleton2D assigned to any of the Polygon2Ds within the \"" + node.name + "\" node."
			AssignmentError.MULTIPLE_SKELETONS:
				error_message = "There can only be one Skeleton2D assigned to the group of Polygon2Ds within the \"" + node.name + "\" node."
			AssignmentError.POLYGON_NAMES_NOT_UNIQUE:
				error_message = "The Polygon2Ds' names within the \"" + node.name + "\" node need to be unique."
			AssignmentError.BONE_NAMES_NOT_UNIQUE:
				error_message = "The Bone2Ds' names within the Skeleton2D need to be unique."
			AssignmentError.SKELETON_TRANSFORM_NOT_IDENTITY:
				error_message = "The Skeleton2D's global transform needs to be equal to identity."
		push_error(error_message)
		return false

## Stores whether or not the model is flipped. Returns if it changed or not.
func _cache_flip_state() -> bool:
	var new_flip_state := _is_paper_skeleton_flipped()
	if cached_flip_state == new_flip_state:
		return false
	cached_flip_state = new_flip_state
	return true

## Returns stored flipped state.
func is_paper_skeleton_flipped() -> bool:
	return cached_flip_state

## Determines if the current setup is flipped.
func _is_paper_skeleton_flipped() -> bool:
	return (flip_model) != (cos(paper_rotate_flip) < 0)

## Handles editor notifications.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			# Couldn't really figure out how to load EulerTransform3Ds after serializing
			# them (I think it's a bug), so this is a bit of a hacky workaround.
			for bone_idx in bone_transform_modifiers.keys():
				var euler_transform: EulerTransform3D = bone_transform_modifiers.get(bone_idx)
				if !euler_transform or \
					euler_transform.get_transform() == Transform3D.IDENTITY:
					continue
				bone_transform_modifiers_storage[bone_idx] = [
					euler_transform.get_position(),
					euler_transform.get_rotation(),
					euler_transform.get_scale(),
					euler_transform.get_transform()
				]
			
			# Cache generated data for loading during startup, instead of generating during runtime.
			
			# Cache meshes
			for paper_polygon: PaperPolygon2D in name_to_paper_polygon.values():
				var mesh_instance := paper_polygon.mesh_instance_3d
				stored_meshes[paper_polygon.name] = mesh_instance.mesh as ArrayMesh
			
			# Cache Skeleton2D node path
			stored_skeleton_2d_path = get_path_to(skeleton2d) if skeleton2d else ^""
			
			# Cache polygon bone data with node paths for keys
			for bone: Bone2D in polygon_bone_data.keys():
				var path_dict: Dictionary[NodePath, PackedFloat32Array] = {}
				var polygon_dict: Dictionary[PaperPolygon2D, PackedFloat32Array] = polygon_bone_data[bone]
				for polygon: PaperPolygon2D in polygon_dict.keys():
					path_dict[get_path_to(polygon)] = polygon_dict[polygon]
				stored_polygon_bone_data[get_path_to(bone)] = path_dict
		NOTIFICATION_EDITOR_POST_SAVE:
			bone_transform_modifiers_storage.clear()
			stored_meshes.clear()
			stored_polygon_bone_data.clear()
#endregion
