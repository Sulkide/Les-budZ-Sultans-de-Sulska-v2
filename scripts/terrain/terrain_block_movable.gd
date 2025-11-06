@tool
extends AnimatableBody3D
class_name MovingPlatform

# ------------------ Taille de la plateforme ------------------
@export_category("Plateforme / Taille")
@export var block_size: Vector3 = Vector3.ONE:
	set(value):
		block_size = value
		if is_node_ready():
			_update_size()

# ------------------ Chemin via Markers ------------------
@export_category("Chemin (Markers)")
@export var points: Array[NodePath] = []

# Décalage par défaut quand on ajoute un marker (évite d'empiler au même endroit)
@export var step_offset: Vector3 = Vector3(0, 0, 0)

@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
@export_tool_button("Ajouter un marker (enfant)")
var _btn_add_marker := _add_marker

@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
@export_tool_button("Recharger la liste depuis les enfants")
var _btn_collect := _collect_children_markers

@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
@export_tool_button("Vider la liste (ne supprime pas les nodes)")
var _btn_clear_list := _clear_points_list

# ------------------ Mouvement ------------------
@export_category("Mouvement")
@export var travel_time: float = 2.0
@export var pause_time: float = 0.7
@export var ease_trans: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_mode: Tween.EaseType = Tween.EASE_IN_OUT
@export var loop: bool = true                           # répéter la séquence
@export var ping_pong: bool = true                      # inclure le retour
@export var loop_times: int = 0                         # 0 = infini si loop=true, sinon 1
@export var destroy_on_end: bool = false                # détruire à la fin des loops finies
@export var pause_only_at_cycle_end: bool = true       # pause seulement en fin de cycle
@export var start_on_ready: bool = true
@export var preview_in_editor: bool = false
@export var auto_collect_on_ready: bool = true
@export var auto_create_if_empty: bool = true           # crée un segment par défaut si aucun marker

# ------------------ Runtime ------------------
var _waypoints: Array[Transform3D] = []
var _tween: Tween

# ------------------------------------------------------------------
func _ready() -> void:
	_update_size()

	# Ne pas bouger en éditeur sauf aperçu
	if Engine.is_editor_hint() and not preview_in_editor:
		return

	# Recollecte systématique au runtime pour fiabiliser les NodePath
	if auto_collect_on_ready:
		_collect_children_markers()

	_build_waypoints()

	# Si pas assez de points, crée un fallback
	if _waypoints.size() < 2 and auto_create_if_empty:
		var fallback := global_transform
		fallback.origin += step_offset
		_waypoints.append(fallback)
		push_warning("MovingPlatform: aucun marker détecté, création d'un segment par défaut (+%s)." % [step_offset])

	# Attendre une physics frame avant de lancer le tween
	if start_on_ready and _waypoints.size() >= 2:
		await get_tree().physics_frame
		_move_loop()
	elif _waypoints.size() < 2:
		push_warning("MovingPlatform: au moins 1 Marker requis (plateforme + 1 cible).")

# ------------------------------------------------------------------
func _build_waypoints() -> void:
	_waypoints.clear()

	# 1) Le 1er transform = celui de la plateforme (exigence)
	_waypoints.append(global_transform)

	# 2) Puis, transforms des markers listés
	for p in points:
		var m := get_node_or_null(p)
		if m is Marker3D:
			_waypoints.append(m.global_transform)
		else:
			push_warning("Marker introuvable pour NodePath: %s" % [str(p)])

# ------------------------------------------------------------------
func _move_loop() -> void:
	if _waypoints.size() < 2:
		return

	if _tween and _tween.is_running():
		_tween.kill()

	# Séquence aller (1..N), puis retour si ping-pong
	var sequence: Array[Transform3D] = []
	for i in range(1, _waypoints.size()):
		sequence.append(_waypoints[i])
	if ping_pong:
		for i in range(_waypoints.size() - 2, -1, -1):
			sequence.append(_waypoints[i])

	# Gestion des loops
	var infinite := loop and loop_times == 0
	var loops_remaining := 1
	if loop:
		loops_remaining = loop_times if loop_times > 0 else 1

	while infinite or loops_remaining > 0:
		for target_tr in sequence:
			var from_tr: Transform3D = global_transform
			var to_tr: Transform3D = target_tr

			# skip si delta ~ 0 (évite "immobile")
			if from_tr.origin.distance_to(to_tr.origin) <= 0.0001 and \
					from_tr.basis.is_equal_approx(to_tr.basis):
				continue

			_tween = create_tween()
			_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			_tween.set_trans(ease_trans).set_ease(ease_mode)
			_tween.tween_method(Callable(self, "_apply_lerp").bind(from_tr, to_tr), 0.0, 1.0, travel_time)

			await _tween.finished

			# >>> Pause par segment UNIQUEMENT si on n'a pas choisi "pause en fin de cycle"
			if not pause_only_at_cycle_end and pause_time > 0.0:
				await get_tree().create_timer(pause_time).timeout

		# >>> Pause en fin de cycle si demandé
		if pause_only_at_cycle_end and pause_time > 0.0:
			await get_tree().create_timer(pause_time).timeout

		if not infinite:
			loops_remaining -= 1
			if loops_remaining <= 0:
				break

	# Fin de toutes les loops : destruction optionnelle (évite en éditeur)
	if destroy_on_end and not Engine.is_editor_hint():
		queue_free()

# Méthode appelée par tween_method : w ∈ [0..1]
func _apply_lerp(w: float, from_tr: Transform3D, to_tr: Transform3D) -> void:
	global_transform = from_tr.interpolate_with(to_tr, w)

# ------------------ Boutons d’inspecteur ------------------
func _add_marker() -> void:
	if not is_inside_tree():
		return

	var marker := Marker3D.new()
	marker.name = _next_marker_name()
	add_child(marker)

	# Owner pour la sérialisation dans la scène (sinon "Invalid owner")
	var scene_root := get_tree().edited_scene_root
	if scene_root:
		marker.owner = scene_root

	# Position initiale : dernier point + step_offset, sinon plateforme + step_offset
	var base_tr: Transform3D = global_transform
	if points.size() > 0:
		var last := get_node_or_null(points.back())
		if last is Marker3D:
			base_tr = last.global_transform
	base_tr.origin += step_offset
	marker.global_transform = base_tr

	points.append(marker.get_path())
	_reindex_markers()

func _collect_children_markers() -> void:
	points.clear()
	for c in get_children():
		if c is Marker3D:
			points.append(c.get_path())
	_reindex_markers()

func _clear_points_list() -> void:
	points.clear()

# ------------------ Utilitaires ------------------
func _update_size() -> void:
	if has_node("CollisionShape3D"):
		var c := $CollisionShape3D
		if c.shape is BoxShape3D:
			c.shape.size = block_size
	if has_node("MeshInstance3D"):
		var m := $MeshInstance3D
		if m.mesh is BoxMesh:
			m.mesh.size = block_size

func _next_marker_name() -> String:
	var idx := 0
	while has_node("PathPoint_%02d" % idx):
		idx += 1
	return "PathPoint_%02d" % idx

func _reindex_markers() -> void:
	var i := 0
	for c in get_children():
		if c is Marker3D:
			c.name = "PathPoint_%02d" % i
			i += 1

# Contrôles manuels
func rebuild_and_play() -> void:
	_build_waypoints()
	if _waypoints.size() < 2 and auto_create_if_empty:
		var fallback := global_transform
		fallback.origin += step_offset
		_waypoints.append(fallback)
	_move_loop()

func stop_motion() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
