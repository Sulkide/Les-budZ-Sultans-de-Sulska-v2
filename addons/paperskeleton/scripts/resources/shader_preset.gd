@tool
extends Resource
class_name PaperSkeletonShaderPreset

## Global shader override
@export var global_shader: Shader

## Global shader parameters
@export var global_params: Dictionary[StringName, Variant] = {}

## Local shader overrides for each polygon
@export var local_shaders: Dictionary[StringName, Shader] = {}

## Local shader parameters for each polygon
@export var local_params: Dictionary[StringName, Dictionary] = {}

## Global parameter override states for each polygon
@export var param_overrides: Dictionary[StringName, bool] = {}

## Global next pass shaders
@export var global_next_pass_shaders: Array[Shader] = []

## Global next pass parameters
@export var global_next_pass_params: Array[Dictionary] = []

## Local next pass shaders
@export var local_next_pass_shaders: Dictionary[StringName, Array] = {}

## Local next pass parameters
@export var local_next_pass_params: Dictionary[StringName, Array] = {}

## Saves current material configuration from a PaperSkeleton
func save_from_paper_skeleton(paper_skeleton: PaperSkeleton) -> void:
	global_shader = paper_skeleton.global_shader_override
	global_params = paper_skeleton.global_shader_params.duplicate(true)
	local_shaders = paper_skeleton.local_shader_overrides.duplicate(true)
	local_params = paper_skeleton.local_shader_params.duplicate(true)
	param_overrides = paper_skeleton.global_shader_param_overrides.duplicate(true)
	global_next_pass_shaders = paper_skeleton.global_next_pass_shaders.duplicate(true)
	global_next_pass_params = paper_skeleton.global_next_pass_params.duplicate(true)
	local_next_pass_shaders = paper_skeleton.local_next_pass_shaders.duplicate(true)
	local_next_pass_params = paper_skeleton.local_next_pass_params.duplicate(true)

## Applies saved configuration to a PaperSkeleton
func apply_to_paper_skeleton(paper_skeleton: PaperSkeleton) -> void:
	# Clear all existing configurations first
	_clear_existing_configuration(paper_skeleton)
	
	# Apply global shader override
	paper_skeleton.global_shader_override = global_shader
	
	# Apply global parameters
	for param: StringName in global_params.keys():
		paper_skeleton.set_global_shader_param(param, global_params[param])
	
	# Apply local overrides and parameters
	for polygon_name: StringName in local_shaders.keys():
		paper_skeleton.set_local_shader_override(polygon_name, local_shaders[polygon_name])
	
	for polygon_name: StringName in local_params:
		for param_name: StringName in local_params[polygon_name].keys():
			paper_skeleton.set_local_shader_param(
				polygon_name,
				param_name,
				local_params[polygon_name][param_name]
			)
	
	# Apply parameter override states
	for polygon_name: StringName in param_overrides.keys():
		paper_skeleton.set_global_shader_param_override(
			polygon_name,
			param_overrides.get(polygon_name, false)
		)
	
	# Apply global next pass configurations
	for i: int in global_next_pass_shaders.size():
		paper_skeleton.set_global_next_pass_shader(
			global_next_pass_shaders[i],
			i
		)
		if i < global_next_pass_params.size():
			for param_name: StringName in global_next_pass_params[i].keys():
				paper_skeleton.set_global_next_pass_param(
					i,
					param_name,
					global_next_pass_params[i][param_name]
				)
	
	# Apply local next pass configurations
	for polygon_name: StringName in local_next_pass_shaders.keys():
		var shaders: Array = local_next_pass_shaders[polygon_name]
		var params: Array = local_next_pass_params[polygon_name]
		for i: int in shaders.size():
			paper_skeleton.set_local_next_pass_shader(
				polygon_name,
				shaders[i],
				i
			)
			if i < params.size():
				for param_name: StringName in params[i].keys():
					paper_skeleton.set_local_next_pass_param(
						polygon_name,
						i,
						param_name,
						params[i][param_name]
					)

## Clears all existing shader configurations from a PaperSkeleton
func _clear_existing_configuration(paper_skeleton: PaperSkeleton) -> void:
	# Clear global shader override
	paper_skeleton.global_shader_override = null
	
	# Clear global parameters
	for param: StringName in paper_skeleton.global_shader_params.keys():
		paper_skeleton.global_shader_params.erase(param)
	
	# Clear local shader overrides and parameters
	for polygon_name: StringName in paper_skeleton.local_shader_overrides.keys():
		paper_skeleton.set_local_shader_override(polygon_name, null)
	
	paper_skeleton.local_shader_params.clear()
	
	# Clear parameter overrides
	for polygon_name: StringName in paper_skeleton.global_shader_param_overrides.keys():
		paper_skeleton.set_global_shader_param_override(polygon_name, false)
	
	# Clear global next passes and their parameters
	for i: int in paper_skeleton.global_next_pass_params.size():
		var params := paper_skeleton.global_next_pass_params[i]
		for param_name: StringName in params.keys():
			paper_skeleton.set_global_next_pass_param(i, param_name, null)
	
	for i: int in paper_skeleton.global_next_pass_shaders.size():
		paper_skeleton.set_global_next_pass_shader(null, i)
	
	# Clear local next passes and their parameters
	for polygon_name: StringName in paper_skeleton.local_next_pass_params.keys():
		var params_array = paper_skeleton.local_next_pass_params[polygon_name]
		for i: int in params_array.size():
			var params = params_array[i]
			for param_name: StringName in params.keys():
				paper_skeleton.set_local_next_pass_param(polygon_name, i, param_name, null)
	
	for polygon_name: StringName in paper_skeleton.local_next_pass_shaders.keys():
		var shaders_array = paper_skeleton.local_next_pass_shaders[polygon_name]
		for i: int in shaders_array.size():
			paper_skeleton.set_local_next_pass_shader(polygon_name, null, i)
	
	# Ensure the arrays are cleared
	paper_skeleton.global_next_pass_shaders.clear()
	paper_skeleton.global_next_pass_params.clear()
	paper_skeleton.local_next_pass_shaders.clear()
	paper_skeleton.local_next_pass_params.clear()
