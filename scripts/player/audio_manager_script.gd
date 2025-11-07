class_name AudioManagerClass
extends Node

@export_category("Bibliothèques audio")
@export var music_streams: Array[AudioStream] = []
@export var sfx_streams: Array[AudioStream] = []

@export_category("SFX Pool")
@export var sfx_pool_size: int = 16

var _music_map: Dictionary = {}
var _sfx_map: Dictionary = {}

var _music_player: AudioStreamPlayer
var _music_loop := false

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_loops: Array[bool] = []

func _ready() -> void:
	_build_maps()
	_setup_players()

# -----
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

func stop_music() -> void:
	_music_loop = false
	if is_instance_valid(_music_player):
		_music_player.stop()

func stop_all_sfx() -> void:
	for i in _sfx_players.size():
		_sfx_loops[i] = false
		_sfx_players[i].stop()

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
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	_sfx_players.clear()
	_sfx_loops.clear()
	for i in sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		add_child(p)
		_sfx_players.append(p)
		_sfx_loops.append(false)
		if not p.finished.is_connected(Callable(self, "_on_sfx_finished")):
			p.finished.connect(Callable(self, "_on_sfx_finished").bind(i))

func _on_music_finished() -> void:
	if _music_loop and is_instance_valid(_music_player):
		_music_player.play()

func _on_sfx_finished(index: int) -> void:
	if index < 0 or index >= _sfx_players.size():
		return
	if _sfx_loops[index]:
		_sfx_players[index].play() 

func _get_free_sfx_player_index() -> int:
	for i in _sfx_players.size():
		if not _sfx_players[i].playing:
			return i
	return 0

func _stream_key(stream: AudioStream) -> String:
	var p := stream.resource_path
	if p != "":
		return p.get_file().get_basename()
	return "stream_%d" % int(hash(stream))
