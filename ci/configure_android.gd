@tool
extends EditorScript

func _run() -> void:
    var settings := EditorInterface.get_editor_settings()
    settings.set_setting("export/android/android_sdk_path", OS.get_environment("ANDROID_HOME"))
    settings.set_setting("export/android/java_sdk_path", OS.get_environment("JAVA_HOME"))
    settings.set_setting("export/android/debug_keystore", OS.get_environment("GODOT_ANDROID_KEYSTORE_DEBUG_PATH"))
    settings.set_setting("export/android/debug_keystore_user", "androiddebugkey")
    settings.set_setting("export/android/debug_keystore_pass", "android")
    settings.save()
    print("Configured Android SDK, JDK and temporary debug keystore paths.")
