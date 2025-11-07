## A utility class for parsing shader code and extracting default uniform values.
## This class exists to work around Godot's limitation where get_shader_uniform_list()
## doesn't return default values for shader uniforms. This parser works by manually 
## analyzing the uncompiled shader code. [br]
## ... [br]
## I hated every second of writing this damn thing. [br][br]
## 
## Anyway, if you're doing something weird and the default value isn't being retrieved,
## it's either a bug from this, or you just need to click off the node and go back to it.
## If it's the former, please inform me so that I may first cry, and then attempt to fix it.

extends RefCounted
class_name ShaderParser

## Dictionary storing cached shader information, keyed by shader resource path
static var _shader_cache := {}

## Tracks processed include paths to prevent infinite recursion
var _processed_includes := {}

## Dictionary mapping GDShader types to their corresponding parsing functions
## Each function takes a string value and returns the appropriate typed result
var _type_parsers := {
	# Scalar type parsers
	"float": func(val: String) -> float: return float(val),
	"int": func(val: String) -> int: return int(val),
	"uint": func(val: String) -> int: return int(val),
	
	# Vector type parsers (floating point)
	"vec2": func(val: String) -> Vector2: return _parse_vector(val, "vec2", 2, false),
	"vec3": func(val: String) -> Vector3: return _parse_vector(val, "vec3", 3, false),
	"vec4": func(val: String) -> Vector4: return _parse_vector(val, "vec4", 4, false),
	
	# Integer vector type parsers
	"ivec2": func(val: String) -> Vector2i: return _parse_vector(val, "ivec2", 2, true),
	"ivec3": func(val: String) -> Vector3i: return _parse_vector(val, "ivec3", 3, true),
	"ivec4": func(val: String) -> Vector4i: return _parse_vector(val, "ivec4", 4, true),
	"uvec2": func(val: String) -> Vector2i: return _parse_vector(val, "uvec2", 2, true),
	"uvec3": func(val: String) -> Vector3i: return _parse_vector(val, "uvec3", 3, true),
	"uvec4": func(val: String) -> Vector4i: return _parse_vector(val, "uvec4", 4, true),
	
	# Boolean type parsers
	"bool": func(val: String) -> bool: return _parse_bool(val),
	"bvec2": func(val: String) -> int: return _parse_bool_vector(val, "bvec2", 2),
	"bvec3": func(val: String) -> int: return _parse_bool_vector(val, "bvec3", 3),
	"bvec4": func(val: String) -> int: return _parse_bool_vector(val, "bvec4", 4),
	
	# Matrix type parsers
	"mat2": func(val: String) -> Transform2D: return _parse_matrix(val, 2),
	"mat3": func(val: String) -> Basis: return _parse_matrix(val, 3),
	"mat4": func(val: String) -> Projection: return _parse_matrix(val, 4)
}

## Internal class for caching shader information
class ShaderCache:
	## Dictionary of uniform names to their default values
	var default_values: Dictionary
	## Hash of the shader code for detecting modifications
	var code_hash: int
	
	@warning_ignore("shadowed_global_identifier")
	func _init(hash: int) -> void:
		default_values = {}
		code_hash = hash

## Internal class for handling multiline shader declarations
class MultilineResult:
	var line: String        ## Processed line
	var in_multiline: bool  ## Whether we're in a multiline declaration
	var accumulated: String ## Accumulated multiline content
	
	func _init(l: String = "", im: bool = false, acc: String = "") -> void:
		line = l
		in_multiline = im
		accumulated = acc

## Parses a boolean from a string value and returns it
static func _parse_bool(val: String) -> bool:
	return val.strip_edges().to_lower() == "true"

## Parses a vector type from a string value
## Returns the appropriate Vector2/3/4 or Vector2i/3i/4i
static func _parse_vector(val: String, type: String, dim: int, is_int: bool) -> Variant:
	val = val.trim_prefix(type + "(").trim_suffix(")")
	var components := _expand_vector_components(val.split(","), dim)
	@warning_ignore("incompatible_ternary")
	var parsed_components = PackedInt32Array() if is_int else PackedFloat32Array()
	parsed_components.resize(dim)
	
	for i in range(dim):
		@warning_ignore("incompatible_ternary")
		parsed_components[i] = int(components[i]) if is_int else float(components[i])
	
	match dim:
		@warning_ignore("incompatible_ternary")
		2: return Vector2i(parsed_components[0], parsed_components[1]) if is_int \
		   else Vector2(parsed_components[0], parsed_components[1])
		@warning_ignore("incompatible_ternary")
		3: return Vector3i(parsed_components[0], parsed_components[1], parsed_components[2]) if is_int \
		   else Vector3(parsed_components[0], parsed_components[1], parsed_components[2])
		@warning_ignore("incompatible_ternary")
		4: return Vector4i(parsed_components[0], parsed_components[1], parsed_components[2], parsed_components[3]) if is_int \
		   else Vector4(parsed_components[0], parsed_components[1], parsed_components[2], parsed_components[3])
	return null

## Parses a boolean vector into a bit field integer
## Each component is stored as a bit in the result
static func _parse_bool_vector(val: String, type: String, dim: int) -> int:
	val = val.trim_prefix(type + "(").trim_suffix(")")
	var components := _expand_vector_components(val.split(","), dim)
	var result := 0
	for i in range(components.size()):
		if _parse_bool(components[i]):
			result |= (1 << i)
	return result

## Parses a matrix type from a string value
## Returns the appropriate Transform2D/Basis/Projection
static func _parse_matrix(val: String, dim: int) -> Variant:
	var comps := _parse_matrix_components(val, dim)
	match dim:
		2: return Transform2D(Vector2(comps[0], comps[1]),
							  Vector2(comps[2], comps[3]),
							  Vector2.ZERO)
		3: return Basis(Vector3(comps[0], comps[1], comps[2]),
						Vector3(comps[3], comps[4], comps[5]),
						Vector3(comps[6], comps[7], comps[8]))
		4: return Projection(Vector4(comps[0], comps[1], comps[2], comps[3]),
							 Vector4(comps[4], comps[5], comps[6], comps[7]),
							 Vector4(comps[8], comps[9], comps[10], comps[11]),
							 Vector4(comps[12], comps[13], comps[14], comps[15]))
	return null

## Computes a hash of the shader code for cache validation
static func _compute_shader_hash(shader_code: String) -> int:
	return shader_code.hash()

## Clears the cached information for a specific shader
static func clear_shader_cache(shader: Shader) -> void:
	var shader_path := shader.resource_path
	if _shader_cache.has(shader_path):
		_shader_cache.erase(shader_path)

## Main entry point for processing includes
func _process_includes(shader: Shader) -> String:
	_processed_includes.clear() # Reset the tracking for each new shader
	return _process_includes_recursive(shader.code, shader.resource_path.get_base_dir())

## Recursively processes includes, handling nested includes properly
func _process_includes_recursive(code: String, base_dir: String) -> String:
	var processed_code := code
	var include_regex := RegEx.new()
	include_regex.compile('#include\\s*"([^"]+)"')
	
	var matches := include_regex.search_all(code)
	for match_result: RegExMatch in matches:
		var include_path := match_result.get_string(1)
		# Handle relative paths
		if not include_path.begins_with("res://"):
			include_path = base_dir.path_join(include_path)
		
		# Prevent infinite recursion
		if _processed_includes.has(include_path):
			continue
		_processed_includes[include_path] = true
		
		var include_file := FileAccess.open(include_path, FileAccess.READ)
		if include_file:
			var include_content := include_file.get_as_text()
			# Recursively process includes in the included file
			include_content = _process_includes_recursive(include_content, include_path.get_base_dir())
			processed_code = processed_code.replace(match_result.get_string(), include_content)
			include_file.close()
	
	return processed_code

## Retrieves the default value for a shader uniform parameter
## Returns null if the parameter is not found or has no default value
func get_shader_default_value(shader: Shader, param_name: String) -> Variant:
	var shader_path := shader.resource_path
	var shader_code := _process_includes(shader)
	var current_hash := _compute_shader_hash(shader_code)
	
	# Cache validation
	if _shader_cache.has(shader_path):
		var cache: ShaderCache = _shader_cache[shader_path]
		if cache.code_hash != current_hash:
			_shader_cache[shader_path] = ShaderCache.new(current_hash)
		elif cache.default_values.has(param_name):
			return cache.default_values[param_name]
	else:
		_shader_cache[shader_path] = ShaderCache.new(current_hash)
	
	# Parse shader code line by line
	var lines := shader_code.split("\n")
	var in_multiline := false
	var in_comment_block := false
	var accumulated_line := ""
	
	for line in lines:
		line = line.strip_edges()
		
		if _handle_comment_blocks(line, in_comment_block) or line.is_empty():
			continue
		
		line = line.split("//")[0].strip_edges()
		if line.is_empty():
			continue
		
		var multiline_result := _handle_multiline(line, in_multiline, accumulated_line)
		in_multiline = multiline_result.in_multiline
		accumulated_line = multiline_result.accumulated
		
		if multiline_result.line.is_empty():
			continue
		
		line = multiline_result.line
		
		if not _is_uniform_start(line):
			continue
		
		# Process uniform declaration
		var parse_result :=_parse_uniform_line(line)
		var declaration: String = parse_result[0]
		if declaration.is_empty():
			continue
		
		var default_value: String = parse_result[1]
		var declaration_parts := _parse_declaration(declaration)
		var var_type: String = declaration_parts[0]
		var var_name: String = declaration_parts[1]
		
		if var_name != param_name:
			continue
		
		if default_value.is_empty():
			return null
		
		var parsed_value = _parse_value_by_type(var_type, default_value)
		if parsed_value != null:
			_shader_cache[shader_path].default_values[param_name] = parsed_value
		
		return parsed_value
	
	print("No matching parameter found")
	return null

## Expands vector components to fill the required size
## If only one component is provided, it's repeated for all dimensions
static func _expand_vector_components(components: PackedStringArray, size: int) -> PackedStringArray:
	var result := PackedStringArray()
	result.resize(size)
	
	var cleaned_components := PackedStringArray()
	for comp in components:
		cleaned_components.append(_clean_outer_parentheses(comp.strip_edges()))
	
	if cleaned_components.size() == 1:
		for i in range(size):
			result[i] = cleaned_components[0]
		return result
	
	for i in range(min(cleaned_components.size(), size)):
		result[i] = cleaned_components[i]
	
	return result

## Parses matrix components from a string representation
static func _parse_matrix_components(value: String, size: int) -> PackedFloat32Array:
	var components := PackedFloat32Array()
	components.resize(size * size)
	
	value = value.trim_prefix("mat" + str(size) + "(").trim_suffix(")").strip_edges()
	
	# Handle diagonal matrix initialization
	if not ("vec" in value or "," in value):
		var diagonal_value := float(_clean_outer_parentheses(value))
		for i in range(size):
			components[i * size + i] = diagonal_value
		return components
	
	# Handle vector initialization
	if "vec" in value:
		var vectors := _split_respecting_parentheses(value)
		
		for i in range(size):
			if i < vectors.size():
				var vec_str: String = _clean_outer_parentheses(vectors[i])
				vec_str = vec_str.trim_prefix("vec" + str(size) + "(").trim_suffix(")")
				
				var vec_components := _expand_vector_components(vec_str.split(","), size)
				for j in range(size):
					components[i * size + j] = float(vec_components[j])
	
	return components

## Splits a string into components while respecting parentheses
static func _split_respecting_parentheses(value: String) -> Array:
	var result := []
	var current := ""
	var paren_count := 0
	
	for c in value:
		match c:
			'(': paren_count += 1
			')': paren_count -= 1
			',':
				if paren_count == 0:
					result.append(current.strip_edges())
					current = ""
					continue
		current += c
	
	if not current.is_empty():
		result.append(current.strip_edges())
	
	return result

## Removes outer parentheses from a value while preserving inner ones
static func _clean_outer_parentheses(value: String) -> String:
	while value.begins_with("(") and value.ends_with(")"):
		var inner := value.substr(1, value.length() - 2)
		if not _is_balanced_parentheses(inner):
			break
		value = inner
	return value

## Checks if parentheses in a string are properly balanced
static func _is_balanced_parentheses(value: String) -> bool:
	var count := 0
	for c in value:
		match c:
			'(': count += 1
			')': count -= 1
		if count < 0:
			return false
	return count == 0

## Handles comment block markers in shader code
static func _handle_comment_blocks(line: String, in_comment_block: bool) -> bool:
	if "/*" in line:
		in_comment_block = true
		line = line.split("/*")[0].strip_edges()
	if "*/" in line and in_comment_block:
		in_comment_block = false
		line = line.split("*/")[1].strip_edges()
	return in_comment_block

static func _handle_multiline(line: String, in_multiline: bool, accumulated_line: String) -> MultilineResult:
	var result := MultilineResult.new()
	
	var check_line := accumulated_line + line if in_multiline else line
	var total_open := _count_open_parentheses(check_line)
	
	if in_multiline:
		result.accumulated = accumulated_line + " " + line
		if total_open == 0 and ";" in line:
			result.line = result.accumulated
			result.in_multiline = false
		else:
			result.in_multiline = true
	elif total_open > 0 or (not ";" in line and _is_uniform_start(line)):
		result.in_multiline = true
		result.accumulated = line
	else:
		result.line = line
	
	return result

## Check if line starts with any uniform declaration
static func _is_uniform_start(line: String) -> bool:
	line = line.strip_edges()
	return line.begins_with("uniform") or \
		   line.begins_with("global uniform") or \
		   line.begins_with("instance uniform")

## Counts the net number of open parentheses in a string
static func _count_open_parentheses(text: String) -> int:
	var total := 0
	for c in text:
		match c:
			'(': total += 1
			')': total -= 1
	return total

## Parses a uniform declaration line into declaration and default value parts
static func _parse_uniform_line(line: String) -> Array:
	var main_part := line.split(";")[0].strip_edges()
	var parts := main_part.split("=", true, 1)
	
	if parts.size() > 1:
		return [parts[0].strip_edges(), parts[1].strip_edges()]
	
	return [main_part, ""]

## Extracts type and name from a uniform declaration
static func _parse_declaration(declaration: String) -> Array:
	# Remove all possible uniform prefixes
	for prefix in ["uniform ", "global uniform ", "instance uniform "]:
		if declaration.begins_with(prefix):
			declaration = declaration.right(-(prefix.length())).strip_edges()
			break
	
	var decl_parts := declaration.split(":")
	declaration = decl_parts[0].strip_edges()
	
	# Remove precision qualifiers if present
	declaration = declaration.replace("lowp ", "")
	declaration = declaration.replace("mediump ", "")
	declaration = declaration.replace("highp ", "")
	
	var type_and_name := declaration.split(" ")
	return [type_and_name[0], type_and_name[-1]]

## Parses a value string according to its GDShader type
func _parse_value_by_type(var_type: String, default_value: String):
	if var_type not in _type_parsers:
		return null
	var parse_func: Callable = _type_parsers[var_type];
	return parse_func.call(_clean_outer_parentheses(default_value))
