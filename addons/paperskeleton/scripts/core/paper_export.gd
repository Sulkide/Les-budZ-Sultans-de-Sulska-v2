@tool
extends EditorExportPlugin
class_name PaperSkeletonExportPlugin

func _export_begin(features: PackedStringArray, is_debug: bool, export_path: String, flags: int) -> void:
	# Get this script's directory
	var script_path: String = get_script().get_path().get_base_dir()
	# Get the config file's directory
	var config_path: String = script_path.path_join("../../plugin.cfg")
	
	# Check if the plugin.cfg file exists in the project
	if FileAccess.file_exists(config_path):
		# Load the content of the plugin.cfg file
		var file_content: PackedByteArray = FileAccess.get_file_as_bytes(config_path)
		
		# Add the file to the export
		add_file(config_path, file_content, false)
		print("PaperSkeletonExportPlugin: Added 'plugin.cfg' to export.")
	else:
		printerr("PaperSkeletonExportPlugin: Could not find 'plugin.cfg' at ", config_path)
