class_name AudioManagerClass
extends Node

@export_category("Bibliothèques audio")
@export var music_streams: Array[AudioStream] = []
@export var sfx_streams: Array[AudioStream] = []

@export_category("SFX Pool")
@export var sfx_pool_size: int = 16

# --- internes ---
var _music_map: Dictionary = {}
var _sfx_map: Dictionary = {}

var _music_player: AudioStreamPlayer
var _music_loop := false

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_loops: Array[bool] = [] # aligné sur _sfx_players (boucle par player)

func _ready() -> void:
	_build_maps()
	_setup_players()

# ---------- PUBLIC API ----------
## Joue une musique par son nom (clé) depuis la liste "music_streams".
## volume: 0.0..1.0 (linéaire), pitch_min/max: ex 0.95..1.05, loop: true/false
func _play_music(name: String, volume: float = 1.0, pitch_min: float = 1.0, pitch_max: float = 1.0, loop: bool = false) -> void:
	var stream: AudioStream = _music_map.get(name, null)
	if stream == null:
		push_warning("AudioManager: musique '%s' introuvable." % name)
		return

	if pitch_min > pitch_max:
		var t := pitch_min
		pitch_min = pitch_max
		pitch_max = t

	_music_loop = loop
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))
	_music_player.pitch_scale = randf_range(pitch_min, pitch_max)

	if not _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.connect(_on_music_finished)

	_music_player.play()

## Joue un SFX par son nom (clé) depuis la liste "sfx_streams".
## Utilise un player libre du pool (ou "vole" le premier si tout est occupé).
func _play_sfx(name: String, volume: float = 1.0, pitch_min: float = 1.0, pitch_max: float = 1.0, loop: bool = false) -> void:
	var stream: AudioStream = _sfx_map.get(name, null)
	if stream == null:
		push_warning("AudioManager: sfx '%s' introuvable." % name)
		return

	if pitch_min > pitch_max:
		var t := pitch_min
		pitch_min = pitch_max
		pitch_max = t

	var idx := _get_free_sfx_player_index()
	var p: AudioStreamPlayer = _sfx_players[idx]

	p.stop()
	p.stream = stream
	p.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	_sfx_loops[idx] = loop
	p.play()

## Arrête la musique en cours
func stop_music() -> void:
	_music_loop = false
	if is_instance_valid(_music_player):
		_music_player.stop()

## Arrête tous les SFX
func stop_all_sfx() -> void:
	for i in _sfx_players.size():
		_sfx_loops[i] = false
		_sfx_players[i].stop()

# ---------- internes ----------
func _build_maps() -> void:
	_music_map.clear()
	_sfx_map.clear()

	for s in music_streams:
		if s == null:
			continue
		var key := _stream_key(s)
		_music_map[key] = s

	for s in sfx_streams:
		if s == null:
			continue
		var key := _stream_key(s)
		_sfx_map[key] = s

func _setup_players() -> void:
	# Music
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	# SFX pool
	_sfx_players.clear()
	_sfx_loops.clear()
	for i in sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		add_child(p)
		_sfx_players.append(p)
		_sfx_loops.append(false)
		# On connecte avec un bind pour connaître l'index à la fin du son
		if not p.finished.is_connected(Callable(self, "_on_sfx_finished")):
			p.finished.connect(Callable(self, "_on_sfx_finished").bind(i))

func _on_music_finished() -> void:
	if _music_loop and is_instance_valid(_music_player):
		_music_player.play()

func _on_sfx_finished(index: int) -> void:
	if index < 0 or index >= _sfx_players.size():
		return
	if _sfx_loops[index]:
		_sfx_players[index].play()  # relance pour boucler

func _get_free_sfx_player_index() -> int:
	for i in _sfx_players.size():
		if not _sfx_players[i].playing:
			return i
	# Si tous occupés, on "vole" le premier
	return 0

# Crée une clé "lisible" par nom de fichier (sans extension) si possible.
# Si le stream n'a pas de chemin (ressource non sauvegardée), fallback sur hash.
func _stream_key(stream: AudioStream) -> String:
	var p := stream.resource_path
	if p != "":
		return p.get_file().get_basename() # ex: "explosion_big"
	# sans path : nom générique unique
	return "stream_%d" % int(hash(stream))
