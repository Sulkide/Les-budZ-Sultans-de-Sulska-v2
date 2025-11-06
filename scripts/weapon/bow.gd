@tool
extends Node3D
class_name Bow

## -------------------- Exports --------------------
@export_group("Spawn")
@export var spawn_at_reticle: bool = true     # instancier directement au niveau du viseur
@export var spawn_offset_back: float = 0.15   # léger recul pour éviter les auto-collisions
@export var reticle_is_screen_space: bool = false  # coche si ton viseur est un Sprite2D/Control overlay


@export_group("Ressources")
@export var arrow_scene: PackedScene            # Assigne Arrow.tscn ici
@export var reticle_texture: Texture2D          # Texture du viseur (Sprite3D/Reticle)

@export_group("Paramètres de tir")
@export var arrow_speed: float = 55.0           # vitesse initiale de la flèche
@export var dead_zone: float = 0.25             # seuil mini du stick pour viser/tirer
@export var reticle_distance: float = 4.0       # distance d'affichage du viseur
@export var clamp_max_pitch_deg: float = 80.0   #
@export var reticle_scale: float = 0.5         # taille du sprite
@export var force_layer_1: bool = true       

@export_group("Noeuds")
@export var shoot_pivot_path: NodePath          # Drag & drop Node3D "ShootPivot"
@export var reticle_path: NodePath              # Drag & drop Sprite3D "Reticle"

@export_group("Inversions (debug)")
@export var invert_x_3d: bool = false
@export var invert_y_3d: bool = true
@export var invert_x_2d: bool = false
@export var invert_y_2d: bool = true

@export_group("Avant de la scène")
@export var forward_is_positive_z: bool = false  # coche si ton 'avant' est +Z




## -------------------- Références runtime --------------------
var _shoot_pivot: Node3D
var _reticle: Sprite3D

func _ready() -> void:
	if shoot_pivot_path != NodePath():
		_shoot_pivot = get_node(shoot_pivot_path) as Node3D

	if reticle_path != NodePath():
		_reticle = get_node(reticle_path) as Sprite3D
	else:
		_reticle = null

	# sécurité : si pas de Sprite3D assigné, on essaie d’en trouver un
	if _reticle == null:
		_reticle = get_node_or_null("Reticle") as Sprite3D
	if _reticle == null:
		push_warning("Bow: aucun Sprite3D 'Reticle' trouvé/assigné → pas d’affichage de viseur.")
		return

	# texture obligatoire pour Sprite3D
	if reticle_texture and _reticle.texture == null:
		_reticle.texture = reticle_texture
	if _reticle.texture == null:
		push_warning("Bow: Reticle n’a pas de texture. Assigne 'reticle_texture' ou une texture sur le node.")

	# init visuel
	_reticle.visible = false
	_reticle.scale = Vector3.ONE * reticle_scale

	# couche par défaut compatible caméra
	if force_layer_1 and _reticle is VisualInstance3D:
		_reticle.layers = 1  # layer 1

func angle_bow_3d(direction: Vector2, shoot: bool=false) -> void:
	var dir2 := direction
	if dir2.length() < dead_zone:
		_hide_reticle()
		return

	# Normalise et applique inversions debug
	dir2 = dir2.normalized()
	if invert_x_3d: dir2.x = -dir2.x
	if invert_y_3d: dir2.y = -dir2.y

	# Mapping plan XZ
	# Godot: avant local = -Z. Si ton jeu utilise +Z comme avant, on inverse le signe de Z.
	var z_comp := -dir2.y
	if forward_is_positive_z:
		z_comp = dir2.y

	var local_dir := Vector3(dir2.x, 0.0, z_comp).normalized()

	var pivot := (_shoot_pivot if _shoot_pivot else self)
	var world_dir := (pivot.global_transform.basis * local_dir).normalized()

	_update_reticle(world_dir)
	if shoot:
		_shoot(world_dir)


func angle_bow_2d(direction: Vector2, shoot: bool=false) -> void:
	var dir2 := direction
	if dir2.length() < dead_zone:
		_hide_reticle()
		return

	dir2 = dir2.normalized()
	if invert_x_2d: dir2.x = -dir2.x
	if invert_y_2d: dir2.y = -dir2.y

	# Plan XY (plateformer) — en général stick haut = +Y monde => on met Y positif
	var local_dir := Vector3(dir2.x, dir2.y, 0.0).normalized()

	var pivot := (_shoot_pivot if _shoot_pivot else self)
	var world_dir := (pivot.global_transform.basis * local_dir).normalized()

	_update_reticle(world_dir)
	if shoot:
		_shoot(world_dir)


## -------------------- Internes --------------------
func _shoot(dir_world: Vector3) -> void:
	if arrow_scene == null:
		push_warning("Bow: arrow_scene non assignée.")
		return
	if dir_world == Vector3.ZERO:
		return

	var pivot := (_shoot_pivot if _shoot_pivot else self)
	var spawn_origin := pivot.global_transform.origin

	if spawn_at_reticle and _reticle and _reticle.visible:
		if not reticle_is_screen_space and _reticle is Node3D:
			# Viseur en 3D dans la scène : on spawn à sa position monde
			spawn_origin = (_reticle as Node3D).global_transform.origin
		else:
			# Viseur overlay 2D : pas de position monde → on spawn "à la distance du viseur"
			spawn_origin = pivot.global_transform.origin + dir_world.normalized() * reticle_distance

		# petit recul pour éviter d'engendrer une collision immédiate
		spawn_origin -= dir_world.normalized() * spawn_offset_back

	# orientation de la flèche (regarder dans la direction de tir)
	var t := Transform3D()
	t = t.looking_at(spawn_origin + dir_world, Vector3.UP)
	t.origin = spawn_origin

	var arrow := arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.global_transform = t

	# Lancement (script Arrow.gd)
	if arrow.has_method("launch"):
		arrow.launch(dir_world, arrow_speed)
	elif "linear_velocity" in arrow:
		arrow.linear_velocity = dir_world * arrow_speed



func _update_reticle(dir_world: Vector3) -> void:
	if _reticle == null:
		return

	# positionner en face du tir
	var origin := (_shoot_pivot if _shoot_pivot else self).global_transform.origin
	_reticle.global_position = origin + dir_world.normalized() * reticle_distance

	# orienter vers la caméra (facultatif mais lisible)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_reticle.look_at(cam.global_transform.origin, Vector3.UP)

	# forcer visibilité si on a bien une dir valide
	_reticle.visible = true

func _hide_reticle() -> void:
	if _reticle:
		_reticle.visible = false
