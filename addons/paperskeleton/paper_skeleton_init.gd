@tool
extends EditorPlugin

const SkeletonButtons = preload("uid://paperskelbtn")
const SkeletonGizmo = preload("uid://paperskelgiz")
const SkeletonExport = preload("uid://paperskelexp")

var skel_button: EditorInspectorPlugin = SkeletonButtons.new()
var gizmo_plugin: EditorNode3DGizmoPlugin = SkeletonGizmo.new()
var export_plugin: EditorExportPlugin = SkeletonExport.new()

func _enter_tree() -> void:
	add_custom_type("PaperSkeleton", "Node3D", preload("uid://paperskelgds"), preload("uid://paperskelico"))
	add_custom_type("PaperBone2D", "Node3D", preload("uid://paperbonegds"), preload("uid://paperboneico"))
	add_custom_type("PaperPolygon2D", "Node3D", preload("uid://paperpolygds"), preload("uid://paperpolyico"))
	add_custom_type("PaperBoneAttachment3D", "Node3D", preload("uid://paperatchgds"), preload("uid://paperatchico"))
	add_inspector_plugin(skel_button)
	add_node_3d_gizmo_plugin(gizmo_plugin)
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_custom_type("PaperSkeleton")
	remove_custom_type("PaperBone2D")
	remove_custom_type("PaperPolygon2D")
	remove_custom_type("PaperBoneAttachment3D")
	remove_inspector_plugin(skel_button)
	remove_node_3d_gizmo_plugin(gizmo_plugin)
	remove_export_plugin(export_plugin)
