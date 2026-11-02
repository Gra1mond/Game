extends RefCounted

func test_pause_is_reversible() -> Array:
	var scene: PackedScene = load("res://world/main.tscn")
	var view: Control = scene.instantiate()
	view._ready()
	view._toggle_pause()
	var errors: Array = []
	if not view.paused or view.status.text != "Пауза":
		errors.append("Pause must be visible")
	view._toggle_pause()
	if view.paused:
		errors.append("Resume must clear pause")
	view.free()
	return errors
