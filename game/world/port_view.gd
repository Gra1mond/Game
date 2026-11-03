extends Control

const INK := Color("e8edf0")
const MUTED := Color("9caebb")
const GOLD := Color("f5cb7d")
var _state: Dictionary = {}
var _render_elapsed := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(360, 260)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func present(state: Dictionary) -> void:
	_state = state
	_render_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _state.is_empty() or _state.paused or not _physically_powered():
		return
	_render_elapsed = minf(_render_elapsed + delta, ContentCatalog.STEP)
	queue_redraw()

func _physically_powered() -> bool:
	return bool(_state.derived.consumers.get("port", {}).get("active", false))

func _home() -> Vector2:
	return size * Vector2(0.15, 0.66)

func _target(id: String) -> Vector2:
	return size * (Vector2(0.48, 0.31) if id == "near" else Vector2(0.82, 0.50))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101e29"))
	if _state.is_empty():
		return
	var font := ThemeDB.fallback_font
	var home := _home()
	draw_string(font, Vector2(18, 29), "Маршруты сборщиков", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
	for target: String in _state.derived.routes:
		var route: Dictionary = _state.derived.routes[target]
		var destination := _target(target)
		draw_dashed_line(home, destination, Color("49606e"), 1.0, 7.0)
		var hull := PackedVector2Array([destination + Vector2(-28, -13), destination + Vector2(30, -13), destination + Vector2(18, 12), destination + Vector2(-16, 12)])
		draw_colored_polygon(hull, Color("647d87"))
		draw_line(destination + Vector2(-8, -13), destination + Vector2(-8, -33), MUTED, 3.0)
		draw_string(font, destination + Vector2(-80, 37), route.name, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, INK)
		draw_string(font, destination + Vector2(-80, 58), "%.0f груза · %.0f с · %.2f/с" % [route.cargo, route.cycle_seconds, route.rate], HORIZONTAL_ALIGNMENT_CENTER, 160, 13, MUTED)
	var built: bool = _state.run.stations.has("port")
	draw_rect(Rect2(home - Vector2(35, 20), Vector2(56, 44)), Color("38515c") if built else Color("253845"))
	for offset: int in [-24, -4, 16]:
		draw_line(home + Vector2(offset, -24), home + Vector2(offset, 33), Color("81989e"), 4.0)
	draw_string(font, home + Vector2(-55, 57), "Порт" if built else "Площадка порта", HORIZONTAL_ALIGNMENT_CENTER, 140, 15, INK)
	var index := 0
	for id: String in _state.run.workers:
		var worker: Dictionary = _state.run.workers[id]
		var lane := Vector2(0, float(index % 6) * 7.0)
		index += 1
		if worker.assignment != "port":
			continue
		var details: Dictionary = _state.derived.workers[id]
		var progress: float = clampf((float(worker.phase_progress) + (0.0 if _state.paused or not _physically_powered() else _render_elapsed)) / float(details.phase_seconds), 0.0, 1.0)
		var destination := _target(worker.target) + lane
		var position_on_route := destination
		if worker.phase == "outbound":
			position_on_route = (home + lane).lerp(destination, progress)
		elif worker.phase == "returning":
			position_on_route = destination.lerp(home + lane, progress)
		var color: Color = GOLD if worker.cargo > 0 else INK
		draw_circle(position_on_route, 6.0, color)
		draw_string(font, position_on_route + Vector2(10, -9), id.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		if worker.cargo > 0:
			draw_string(font, position_on_route + Vector2(10, 10), "+%.0f в трюме" % worker.cargo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	if _state.paused:
		draw_string(font, Vector2(18, size.y - 45), "ПАУЗА — производство остановлено", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
	elif built and not _physically_powered():
		draw_string(font, Vector2(18, size.y - 45), "Нет питания или связи — груз и фазы сохранены", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
	draw_string(font, Vector2(18, size.y - 20), "Светлая точка — пустой сборщик · золотая — груз в пути", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
