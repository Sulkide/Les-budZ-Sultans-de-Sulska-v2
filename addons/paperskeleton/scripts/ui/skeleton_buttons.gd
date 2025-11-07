extends EditorInspectorPlugin

const REFRESH_BUTTON_TEXT := "Refresh Polygon Group"
const SAVE_MATERIAL_TEXT := "Save Shader Preset"

const PAPER_SKELETON_CATEGORY := "paper_skeleton.gd"
const SHADER_GROUP := "Shader"

var _active_dialog: EditorFileDialog = null

func _can_handle(object: Object) -> bool:
	return object is PaperSkeleton

func _parse_category(object: Object, category: String) -> void:
	if category == PAPER_SKELETON_CATEGORY and object.polygon_group != null:
		var refresh_btn := Button.new()
		refresh_btn.set_text(REFRESH_BUTTON_TEXT)
		refresh_btn.pressed.connect(_on_refresh_btn_pressed.bind(object))
		add_custom_control(refresh_btn)

func _parse_group(object: Object, group: String) -> void:
	if group == SHADER_GROUP and object.polygon_group != null:
		var save_btn := Button.new()
		save_btn.set_text(SAVE_MATERIAL_TEXT)
		save_btn.pressed.connect(_on_save_material_pressed.bind(object))
		add_custom_control(save_btn)

func _create_file_dialog(save_mode: bool, callback: Callable, filter := ".tres", filter_desc := "", title := "") -> EditorFileDialog:
	_cleanup_dialog()
	
	var dialog := EditorFileDialog.new()
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter(filter, filter_desc)
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if save_mode else EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.title = title
	
	dialog.file_selected.connect(callback)
	dialog.canceled.connect(_cleanup_dialog)
	
	var base_control: Control = EditorInterface.get_base_control()
	base_control.add_child(dialog)
	dialog.popup_centered(Vector2(500, 500))
	
	_active_dialog = dialog
	return dialog

func _cleanup_dialog() -> void:
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null

func _on_refresh_btn_pressed(paper_skeleton: PaperSkeleton) -> void:
	paper_skeleton.refresh_polygon_group()

func _on_save_material_pressed(paper_skeleton: PaperSkeleton) -> void:
	var preset := PaperSkeletonShaderPreset.new()
	preset.save_from_paper_skeleton(paper_skeleton)
	
	_create_file_dialog(true, func(path: String):
		if not path.ends_with(".tres"):
			path += ".tres"
		var error = ResourceSaver.save(preset, path)
		if error != OK:
			printerr("Failed to save shader preset: ", error)
		_cleanup_dialog(), "*.tres", "Shader Preset", SAVE_MATERIAL_TEXT
	)

func _on_load_material_pressed(paper_skeleton: PaperSkeleton) -> void:
	_create_file_dialog(false, func(path: String):
		var preset := load(path) as PaperSkeletonShaderPreset
		if preset:
			preset.apply_to_paper_skeleton(paper_skeleton)
		else:
			printerr("Failed to load shader preset from: ", path)
			_cleanup_dialog()
	)
