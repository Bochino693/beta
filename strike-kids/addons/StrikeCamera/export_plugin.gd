@tool
extends EditorPlugin

## Leva o plugin Android da câmera (bin/StrikeCamera.aar) para dentro do APK.
## Fonte Java: tools/android/StrikeCamera (sh construir.sh refaz o .aar).
## Precisa do build Gradle (o GERAR_APK.ps1 já liga sozinho).

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = StrikeCameraExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class StrikeCameraExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "StrikeCamera"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["StrikeCamera/bin/StrikeCamera.aar"])
