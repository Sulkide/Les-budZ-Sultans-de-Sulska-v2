# CameraFlip.gd
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
@export var follow_parent_while_flipping: bool = true   # <<< NOUVEAU

var is_3d: bool = true

# Baseline (monde)
var _scale_ref: float = 1.0
var _anchor_on_plane: Vector3
var _p0: Vector3
var _r0: Vector3
var _t0: float

# Suivi parent pendant le flip
var _anchor_local: Vector3 = Vector3.ZERO   # ancre stockée en local du parent
var _follow_active: bool = false

# Rotation interpolation
var _rot_start_q: Quaternion
var _rot_end_q: Quaternion

var _tween: Tween

func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	position = preset_pos_3d
	rotation_degrees = preset_rot_3d_deg
	fov = preset_fov_3d
	is_3d = true
	_capture_baseline_from_current()

# ---------- Helpers ----------

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

func _camera_forward_from_quat(q: Quaternion) -> Vector3:
	return -Basis(q).z.normalized()

func _compute_t_for_plane(pos: Vector3, forward: Vector3, plane_z: float) -> float:
	var denom: float = forward.z
	if absf(denom) < 1e-6:
		denom = 1e-6 if denom >= 0.0 else -1e-6
	return (plane_z - pos.z) / denom

func _quat_from_euler_deg(rot_deg: Vector3) -> Quaternion:
	var euler_rad := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	return Basis.from_euler(euler_rad).get_rotation_quaternion()

func _capture_baseline_from_current() -> void:
	var gt: Transform3D = global_transform
	_p0 = gt.origin
	_r0 = -gt.basis.z.normalized()
	_t0 = _compute_t_for_plane(_p0, _r0, target_plane_z)
	_scale_ref = _t0 * tan(deg_to_rad(fov) * 0.5)
	_anchor_on_plane = _p0 + _r0 * _t0

# Récupère l'ancre monde à cette frame (suivie du parent si actif)
func _current_anchor_world() -> Vector3:
	if _follow_active:
		var parent := _parent_node3d()
		if parent:
			return parent.to_global(_anchor_local)
	return _anchor_on_plane

# ---------- Paramétrique (time ∈ [0,1]) ----------

func apply_3d_to_2d(time: float) -> void:
	time = clamp(time, 0.0, 1.0)

	var q: Quaternion = _rot_start_q.slerp(_rot_end_q, time)
	var r: Vector3 = _camera_forward_from_quat(q)

	var f: float = lerpf(preset_fov_3d, fov_min_deg, time)
	var half_tan: float = tan(deg_to_rad(f) * 0.5)
	var t_needed: float = _scale_ref / maxf(half_tan, 1e-6)

	var anchor_world: Vector3 = _current_anchor_world()
	var p: Vector3 = anchor_world - r * t_needed

	projection = PROJECTION_PERSPECTIVE
	fov = f
	_apply_world_transform(Transform3D(Basis(q), p))

func apply_2d_to_3d(time: float) -> void:
	time = clamp(time, 0.0, 1.0)

	var q: Quaternion = _rot_start_q.slerp(_rot_end_q, time)
	var r: Vector3 = _camera_forward_from_quat(q)

	var f: float = lerpf(fov_min_deg, preset_fov_3d, time)
	var half_tan: float = tan(deg_to_rad(f) * 0.5)
	var t_needed: float = _scale_ref / maxf(half_tan, 1e-6)

	var anchor_world: Vector3 = _current_anchor_world()
	var p: Vector3 = anchor_world - r * t_needed

	projection = PROJECTION_PERSPECTIVE
	fov = f
	_apply_world_transform(Transform3D(Basis(q), p))

# ---------- Tweens ----------

func to_2D() -> void:
	if _tween: _tween.kill()

	# Baseline depuis l'état courant
	_capture_baseline_from_current()

	# Active le suivi du parent pendant le flip
	var parent := _parent_node3d()
	if parent:
		_anchor_local = parent.to_local(_anchor_on_plane)
	_follow_active = follow_parent_while_flipping

	_rot_start_q = global_transform.basis.get_rotation_quaternion()
	_rot_end_q = _quat_from_euler_deg(Vector3.ZERO)

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(Callable(self, "apply_3d_to_2d"), 0.0, 1.0, flip_duration)
	_tween.tween_callback(Callable(self, "_finish_2d"))

func _finish_2d() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 2.0 * _scale_ref
	rotation_degrees = Vector3.ZERO
	is_3d = false
	_follow_active = false

func to_3D() -> void:
	if _tween: _tween.kill()

	# Part de l'ORTHO courant : size = hauteur totale
	_scale_ref = size * 0.5

	_rot_start_q = global_transform.basis.get_rotation_quaternion()        # ~identité
	_rot_end_q = _quat_from_euler_deg(preset_rot_3d_deg)

	# Détermine l’ancre monde à t=0 (perspective fov_min) en fonction de la position actuelle
	var r_start: Vector3 = _camera_forward_from_quat(_rot_start_q)
	var t_start: float = _scale_ref / maxf(tan(deg_to_rad(fov_min_deg) * 0.5), 1e-6)
	_anchor_on_plane = global_position + r_start * t_start

	# Active le suivi du parent pendant le flip
	var parent := _parent_node3d()
	if parent:
		_anchor_local = parent.to_local(_anchor_on_plane)
	_follow_active = follow_parent_while_flipping

	# Prépare l’instant initial (pas de pop)
	projection = PROJECTION_PERSPECTIVE
	fov = fov_min_deg
	apply_2d_to_3d(0.0)

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(Callable(self, "apply_2d_to_3d"), 0.0, 1.0, flip_duration)
	_tween.tween_callback(Callable(self, "_finish_3d"))

func _finish_3d() -> void:
	# Recalage en LOCAL (évite tout décalage monde)
	projection = PROJECTION_PERSPECTIVE
	position = preset_pos_3d
	rotation_degrees = preset_rot_3d_deg
	fov = preset_fov_3d
	is_3d = true
	_follow_active = false
	_capture_baseline_from_current()

# ---------- Snaps ----------

func snap_to_3D() -> void:
	projection = PROJECTION_PERSPECTIVE
	position = preset_pos_3d
	rotation_degrees = preset_rot_3d_deg
	fov = preset_fov_3d
	is_3d = true
	_capture_baseline_from_current()

func snap_to_2D() -> void:
	snap_to_3D()
	projection = PROJECTION_ORTHOGONAL
	size = 2.0 * _scale_ref
	rotation_degrees = Vector3.ZERO
	is_3d = false
