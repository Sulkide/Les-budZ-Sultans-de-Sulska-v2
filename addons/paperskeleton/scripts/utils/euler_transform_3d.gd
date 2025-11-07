## A utility class for storing Transform3D values as Euler angles.
## This class simplifies 3D transform manipulation by providing an interface
## for position, rotation, and scale values, abstracting away from the complexity
## of Transform3D's internal representation. Primarily used for in-editor menus.
##
## If you are making something that uses this via scripting and don't care for the
## euler values, I'd advise that you just manually modify the Transform3D value
## itself to suit your needs if you're editing anything that's not the position.

class_name EulerTransform3D
extends RefCounted

## The position in 3D space ([color=red]X[/color], [color=green]Y[/color], [color=purple]Z[/color] coordinates).
var position: Vector3:
	set(value):
		set_position(value)
	get():
		return get_position()
var _position: Vector3

## The rotation in Euler angles (in radians).[br]
## [color=red]X[/color] = pitch (around right axis)[br]
## [color=green]Y[/color] = yaw (around up axis)[br]
## [color=purple]Z[/color] = roll (around forward axis)
var rotation: Vector3:
	set(value):
		set_rotation(value)
	get():
		return get_rotation()
var _rotation: Vector3

## The scale factors along each axis.
var scale: Vector3:
	set(value):
		set_scale(value)
	get():
		return get_scale()
var _scale: Vector3

## The resulting [Transform3D] object.
var transform: Transform3D:
	set(value):
		set_transform(value)
	get():
		return get_transform()
var _transform: Transform3D

## Initializes the EulerTransform3D with optional position, rotation, and scale values.[br]
## [param pos] - Initial position (default: [constant Vector3.ZERO])[br]
## [param rot] - Initial rotation in radians (default: [constant Vector3.ZERO])[br]
## [param scl] - Initial scale (default: [constant Vector3.ONE])[br]
## [param transform_override] - The internal [Transform3D], in case if you're just reconstructing the class. (default: [constant null])
func _init(pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, transform_override = null) -> void:
	if transform_override == null:
		update_transform(pos, rot, scl)
	else:
		_position = pos
		_rotation = rot
		_scale = scl
		_transform = transform_override

## Sets the position and updates the transform.[br]
## [param value] - The new position vector
func set_position(value: Vector3) -> void:
	if value == _position:
		return
	if value == null:
		set_position(Vector3.ZERO)
		return
	_position = value
	if _transform:
		_transform = Transform3D(_transform.basis, _position)
	else:
		_make_transform()

## Returns the position.
func get_position() -> Vector3:
	if _position:
		return _position
	else: 
		return Vector3.ZERO

## Sets the rotation and updates the transform.[br]
## [param value] - The new rotation vector (in radians)
func set_rotation(value: Vector3) -> void:
	if value == _rotation:
		return
	if value == null:
		set_rotation(Vector3.ZERO)
		return
	_rotation = value
	_make_transform()

## Returns the rotation.
func get_rotation() -> Vector3:
	if _rotation:
		return _rotation
	else: 
		return Vector3.ZERO

## Sets the scale and updates the transform.[br]
## [param value] - The new scale vector
func set_scale(value: Vector3) -> void:
	if value == _scale:
		return
	if value == null:
		set_scale(Vector3.ONE)
		return
	_scale = value
	_make_transform()

## Returns the scale.
func get_scale() -> Vector3:
	if _scale:
		return _scale
	else: 
		return Vector3.ONE

## Updates the eulers and the internal [Transform3D] based on position, rotation, and scale values.[br]
## [param pos] - Position vector (default: current position)[br]
## [param rot] - Rotation vector in radians (default: current rotation)[br]
## [param scl] - Scale vector (default: current scale)
func update_transform(pos := _position, rot := _rotation, scl := _scale) -> void:
	var position_changed: bool = pos != _position
	var rotation_changed: bool = rot != _rotation
	var scale_changed: bool = scl != _scale
	
	if !(position_changed or rotation_changed or scale_changed):
		return
	
	if position_changed: _position = pos
	if rotation_changed: _rotation = rot
	if scale_changed: _scale = scl
	
	if _transform and !(rotation_changed or scale_changed):
		_transform = Transform3D(_transform.basis, _position)
	else:
		_make_transform()

## Updates the internal [Transform3D] based on position, rotation, and scale values.[br]
## [param pos] - Position vector (default: current position)[br]
## [param rot] - Rotation vector in radians (default: current rotation)[br]
## [param scl] - Scale vector (default: current scale)
func _make_transform(pos := _position, rot := _rotation, scl := _scale) -> void:
	_transform = Transform3D(Basis.from_euler(rot).scaled(scl), pos)

## Replaces the current [Transform3D] and fills in the euler values.[br]
## [param transform] - The [Transform3D] to replace the current one.
func set_transform(transform_3d: Transform3D) -> void:
	if transform_3d == null:
		_transform = Transform3D.IDENTITY
		
		_position = Vector3.ZERO
		_rotation = Vector3.ZERO
		_scale = Vector3.ONE
	else:
		_transform = transform_3d
		
		_position = transform_3d.origin
		_rotation = transform_3d.basis.get_euler()
		_scale = transform_3d.basis.get_scale()

## Returns the current [Transform3D].
func get_transform() -> Transform3D:
	if _transform:
		return _transform
	else:
		return Transform3D.IDENTITY
