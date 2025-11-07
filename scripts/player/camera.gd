class_name CameraFlip
extends Camera3D

@export_category("Preset 3D (local au parent)")
@export var preset_pos_3d: Vector3 = Vector3(0, 10, 17)
@export var preset_rot_3d_deg: Vector3 = Vector3(-9, 0, 0)
@export var preset_fov_3d: float = 75.0

@export_category("Transition / Appariement d'échelle")
@export var target_plane_z: float = 0.0
@export var fov_min_deg: float = 1.0
@export var flip_duration: float = 0.8
@export var follow_parent_while_flipping: bool = true
@export var compensate_parent_z: bool = true 
var is_3d: bool = true


var _scale_ref_start: float = 1.0
var _scale_ref_goal: float = 1.0
var _anchor_start_world: Vector3 = Vector3.ZERO
var _anchor_goal_world: Vector3 = Vector3.ZERO

var _anchor_start_local: Vector3 = Vector3.ZERO
var _anchor_goal_local: Vector3 = Vector3.ZERO
var _follow_active: bool = false

var _rot_start_q: Quaternion
var _rot_end_q: Quaternion

var _tween: Tween

func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	position = preset_pos_3d
	rotation_degrees = preset_rot_3d_deg
	fov = preset_fov_3d
	is_3d = true


func _parent_node3d() -> Node3D:
	var p := get_parent()
	return p if p is Node3D else null

func _apply_world_transform(world_xf: Transform3D) -> void:
	var parent := _parent_node3d()
	if parent:
		var inv: Transform3D = parent.global_transform.affine_inverse()
		transform = inv * world_xf
	else:
		global_transform = world_xf

func _world_quat_from_local_euler(rot_deg: Vector3) -> Quaternion:
	var local_q: Quaternion = Basis.from_euler(Vector3(
		deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)
	)).get_rotation_quaternion()
	var parent := _parent_node3d()
	if parent:
		var parent_q: Quaternion = parent.global_transform.basis.get_rotation_quaternion()
		return parent_q * local_q
	return local_q

func _camera_forward_from_quat(q: Quaternion) -> Vector3:
	return -Basis(q).z.normalized()

func _compute_t_for_plane(pos: Vector3, forward: Vector3, plane_z: float) -> float:
	var denom: float = forward.z
	if absf(denom) < 1e-6:
		denom = 1e-6 if denom >= 0.0 else -1e-6
	return (plane_z - pos.z) / denom

func _get_virtual_world_transform() -> Transform3D:
	var parent := _parent_node3d()
	if parent and compensate_parent_z:
		var parent_virtual: Transform3D = parent.global_transform
		parent_virtual.origin.z = target_plane_z
		return parent_virtual * transform
	return global_transform

func _current_anchor_world(alpha: float) -> Vector3:
	var a_start: Vector3 = _anchor_start_world
	var a_goal: Vector3 = _anchor_goal_world
	if _follow_active:
		var parent := _parent_node3d()
		if parent:
			a_start = parent.to_global(_anchor_start_local)
			a_goal  = parent.to_global(_anchor_goal_local)
	var a: Vector3 = a_start.lerp(a_goal, alpha)
	a.z = target_plane_z
	return a


func _build_real_baseline_for_current(f_current: float, q_current: Quaternion) -> void:
	var gt: Transform3D = global_transform
	var p0: Vector3 = gt.origin
	var r0: Vector3 = _camera_forward_from_quat(q_current)
	var t0: float = _compute_t_for_plane(p0, r0, target_plane_z)
	_scale_ref_start = t0 * tan(deg_to_rad(f_current) * 0.5)
	_anchor_start_world = p0 + r0 * t0

func _build_compensated_goal_for_current(f_reference: float, q_reference: Quaternion) -> void:
	var gt_v: Transform3D = _get_virtual_world_transform()
	var p: Vector3 = gt_v.origin
	var r: Vector3 = _camera_forward_from_quat(q_reference)
	var t: float = _compute_t_for_plane(p, r, target_plane_z)
	_scale_ref_goal = t * tan(deg_to_rad(f_reference) * 0.5)
	_anchor_goal_world = p + r * t

func _build_goal_for_preset3d() -> void:
	var parent := _parent_node3d()
	var local_end_xf := Transform3D(
		Basis.from_euler(Vector3(
			deg_to_rad(preset_rot_3d_deg.x), deg_to_rad(preset_rot_3d_deg.y), deg_to_rad(preset_rot_3d_deg.z)
		)),
		preset_pos_3d
	)
	var world_end_xf: Transform3D = parent.global_transform * local_end_xf if parent else local_end_xf
	var p_end: Vector3 = world_end_xf.origin
	var q_end: Quaternion = world_end_xf.basis.get_rotation_quaternion()
	var r_end: Vector3 = _camera_forward_from_quat(q_end)

	var t_end: float = _compute_t_for_plane(p_end, r_end, target_plane_z)
	_scale_ref_goal = t_end * tan(deg_to_rad(preset_fov_3d) * 0.5)
	_anchor_goal_world = p_end + r_end * t_end


func apply_3d_to_2d(time: float) -> void:
	time = clamp(time, 0.0, 1.0)

	var q: Quaternion = _rot_start_q.slerp(_rot_end_q, time)
	var r: Vector3 = _camera_forward_from_quat(q)

	var f: float = lerpf(preset_fov_3d, fov_min_deg, time)
	var half_tan: float = tan(deg_to_rad(f) * 0.5)

	var scale_ref: float = lerpf(_scale_ref_start, _scale_ref_goal, time)
	var anchor: Vector3 = _current_anchor_world(time)

	var t_needed: float = scale_ref / maxf(half_tan, 1e-6)
	var p: Vector3 = anchor - r * t_needed

	projection = PROJECTION_PERSPECTIVE
	fov = f
	_apply_world_transform(Transform3D(Basis(q), p))

func apply_2d_to_3d(time: float) -> void:
	time = clamp(time, 0.0, 1.0)

	var q: Quaternion = _rot_start_q.slerp(_rot_end_q, time)
	var r: Vector3 = _camera_forward_from_quat(q)

	var f: float = lerpf(fov_min_deg, preset_fov_3d, time)
	var half_tan: float = tan(deg_to_rad(f) * 0.5)

	var scale_ref: float = lerpf(_scale_ref_start, _scale_ref_goal, time)
	var anchor: Vector3 = _current_anchor_world(time)

	var t_needed: float = scale_ref / maxf(half_tan, 1e-6)
	var p: Vector3 = anchor - r * t_needed

	projection = PROJECTION_PERSPECTIVE
	fov = f
	_apply_world_transform(Transform3D(Basis(q), p))


func to_2D() -> void:
	if _tween: _tween.kill()

	_rot_start_q = global_transform.basis.get_rotation_quaternion()
	_rot_end_q = _world_quat_from_local_euler(Vector3.ZERO) 
	_build_real_baseline_for_current(preset_fov_3d, _rot_start_q)

	_build_compensated_goal_for_current(preset_fov_3d, _rot_end_q)

	var parent := _parent_node3d()
	if parent:
		_anchor_start_local = parent.to_local(_anchor_start_world)
		_anchor_goal_local  = parent.to_local(_anchor_goal_world)
	_follow_active = follow_parent_while_flipping

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(Callable(self, "apply_3d_to_2d"), 0.0, 1.0, flip_duration)
	_tween.tween_callback(Callable(self, "_finish_2d"))

func _finish_2d() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 2.0 * _scale_ref_goal
	rotation_degrees = Vector3.ZERO
	is_3d = false
	_follow_active = false

func to_3D() -> void:
	if _tween: _tween.kill()

	_rot_start_q = global_transform.basis.get_rotation_quaternion()        
	_rot_end_q   = _world_quat_from_local_euler(preset_rot_3d_deg)         
	_scale_ref_start = size * 0.5
	var gt: Transform3D = global_transform
	var p0: Vector3 = gt.origin
	var r0: Vector3 = _camera_forward_from_quat(_rot_start_q)
	var t0: float = _scale_ref_start / maxf(tan(deg_to_rad(fov_min_deg) * 0.5), 1e-6)
	_anchor_start_world = p0 + r0 * t0

	_build_goal_for_preset3d()

	var parent := _parent_node3d()
	if parent:
		_anchor_start_local = parent.to_local(_anchor_start_world)
		_anchor_goal_local  = parent.to_local(_anchor_goal_world)
	_follow_active = follow_parent_while_flipping

	projection = PROJECTION_PERSPECTIVE
	fov = fov_min_deg

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(Callable(self, "apply_2d_to_3d"), 0.0, 1.0, flip_duration)
	_tween.tween_callback(Callable(self, "_finish_3d"))

func _finish_3d() -> void:
	is_3d = true
	_follow_active = false


func snap_to_3D() -> void:
	projection = PROJECTION_PERSPECTIVE
	position = preset_pos_3d
	rotation_degrees = preset_rot_3d_deg
	fov = preset_fov_3d
	is_3d = true

func snap_to_2D() -> void:
	var q_preset_world: Quaternion = _world_quat_from_local_euler(preset_rot_3d_deg)
	var parent := _parent_node3d()
	var local_end_xf := Transform3D(Basis.from_euler(Vector3(
		deg_to_rad(preset_rot_3d_deg.x), deg_to_rad(preset_rot_3d_deg.y), deg_to_rad(preset_rot_3d_deg.z)
	)), preset_pos_3d)
	var world_end_xf: Transform3D = parent.global_transform * local_end_xf if parent else local_end_xf
	var p0: Vector3 = world_end_xf.origin
	var r0: Vector3 = _camera_forward_from_quat(q_preset_world)
	var t0: float = _compute_t_for_plane(p0, r0, target_plane_z)
	var scale_ref: float = t0 * tan(deg_to_rad(preset_fov_3d) * 0.5)

	projection = PROJECTION_ORTHOGONAL
	size = 2.0 * scale_ref
	rotation_degrees = Vector3.ZERO
	is_3d = false
