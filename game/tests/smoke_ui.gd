extends SceneTree

func _initialize() -> void:
	call_deferred("_exercise")

func _exercise() -> void:
	var scene: PackedScene = load("res://world/main.tscn")
	var view: Control = scene.instantiate()
	root.add_child(view)
	await process_frame
	view._toggle_pause()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/lighthouse-t01.png")
	print("SMOKE pause=", view.paused, " viewport=", root.size, " fps=", Engine.get_frames_per_second())
	view._toggle_pause()
	await create_timer(2.0).timeout
	print("SMOKE resume=", not view.paused, " fps=", Engine.get_frames_per_second(), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	quit()
