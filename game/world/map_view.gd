extends Control

signal region_selected(region: String)

const INK := Color("e8edf0")
const MUTED := Color("9caebb")
const GOLD := Color("f5cb7d")
const ACTIVE := Color("85c7ae")
const STOPPED := Color("e8a082")
const REGION_STATES: Dictionary = {
	"working": "сеть работает", "not_built": "реле не построено",
	"manual_off": "выключено вручную", "no_power": "не хватает питания",
	"disconnected": "нет связи с кораблём", "not_discovered": "туман",
}

var _state: Dictionary = {}
var _selected := "port"
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var _drag_distance := 0.0
var _world_bounds := Rect2(Vector2.ZERO, Vector2.ZERO)

func _ready() -> void:
	custom_minimum_size = Vector2(360, 260)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func present(state: Dictionary) -> void:
	_state = state
	_world_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for id: String in state.derived.regions:
		_world_bounds = _world_bounds.expand(_world_position(state.derived.regions[id]))
	queue_redraw()

func select_region(region: String) -> bool:
	if _state.is_empty() or not _state.derived.regions.has(region):
		return false
	if not _state.derived.regions[region].discovered:
		return false
	_selected = region
	queue_redraw()
	return true

func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	queue_redraw()

func change_zoom(factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	_zoom = clampf(_zoom * factor, 0.55, 2.5)
	queue_redraw()

func pan_by(offset: Vector2) -> void:
	_pan += offset
	queue_redraw()

func get_zoom() -> float:
	return _zoom

func get_visible_links() -> Array:
	return _state.get("derived", {}).get("links", []).duplicate(true)

func region_screen_position(region: String) -> Vector2:
	if _state.is_empty() or not _state.derived.regions.has(region):
		return Vector2.ZERO
	return _to_screen(_world_position(_state.derived.regions[region]))

func _world_position(region: Dictionary) -> Vector2:
	return Vector2(float(region.position[0]), float(region.position[1]))

func _bounds() -> Rect2:
	return _world_bounds

func _scale() -> float:
	if _state.is_empty():
		return _zoom
	var extent := _bounds().size
	return maxf(0.25, minf((size.x - 170.0) / maxf(extent.x, 1.0), (size.y - 140.0) / maxf(extent.y, 1.0))) * _zoom

func _to_screen(point: Vector2) -> Vector2:
	return size * 0.5 + (point - _bounds().get_center()) * _scale() + _pan

func _choose_next(direction: int) -> void:
	var ids: Array[String] = []
	for id: String in _state.derived.regions:
		if _state.derived.regions[id].discovered:
			ids.append(id)
	if ids.is_empty():
		return
	var index := ids.find(_selected)
	var next: String = ids[posmod(index + direction, ids.size())]
	select_region(next)
	region_selected.emit(next)

func _gui_input(event: InputEvent) -> void:
	if _state.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			change_zoom(1.2)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			change_zoom(1.0 / 1.2)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				grab_focus()
				_dragging = true
				_drag_distance = 0.0
			else:
				_dragging = false
				if event.button_index == MOUSE_BUTTON_LEFT and _drag_distance < 6.0:
					for id: String in _state.derived.regions:
						if _state.derived.regions[id].discovered and event.position.distance_to(region_screen_position(id)) <= 35.0:
							select_region(id)
							region_selected.emit(id)
							break
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_distance += event.relative.length()
		pan_by(event.relative)
		accept_event()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _choose_next(-1)
			KEY_RIGHT: _choose_next(1)
			KEY_A: pan_by(Vector2(35, 0))
			KEY_D: pan_by(Vector2(-35, 0))
			KEY_W: pan_by(Vector2(0, 35))
			KEY_S: pan_by(Vector2(0, -35))
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: change_zoom(1.2)
			KEY_MINUS, KEY_KP_SUBTRACT: change_zoom(1.0 / 1.2)
			KEY_HOME: reset_view()
			_: return
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101e29"))
	if _state.is_empty():
		return
	var font := ThemeDB.fallback_font
	for link: Array in _state.derived.links:
		var start := region_screen_position(str(link[0]))
		var end := region_screen_position(str(link[1]))
		draw_line(start, end, ACTIVE, 2.0, true)
	for id: String in _state.derived.regions:
		var region: Dictionary = _state.derived.regions[id]
		var point := region_screen_position(id)
		if not region.discovered:
			draw_circle(point, 14.0, Color("263946"))
			draw_string(font, point + Vector2(-5, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
			continue
		var color: Color = ACTIVE if region.active else (STOPPED if region.built else MUTED)
		var shape := PackedVector2Array([point + Vector2(-27, 6), point + Vector2(-17, -16), point + Vector2(12, -19), point + Vector2(29, 0), point + Vector2(15, 16), point + Vector2(-15, 19)])
		draw_colored_polygon(shape, Color("29424c") if region.unlocked else Color("24333e"))
		if id == _selected:
			draw_arc(point, 33, 0, TAU, 40, GOLD, 2.0, true)
		if region.built:
			draw_rect(Rect2(point - Vector2(6, 9), Vector2(12, 18)), color)
		else:
			draw_circle(point, 7, color, false, 2.0, true)
		var label_y := -44.0 if id in ["ship", "quartz"] else 42.0
		draw_string(font, point + Vector2(-84, label_y), str(region.name), HORIZONTAL_ALIGNMENT_CENTER, 168, 15, INK)
		var caption: String = "Корабль · источник" if id == "ship" else str(REGION_STATES.get(region.reason, region.reason))
		draw_string(font, point + Vector2(-90, label_y + 19), caption, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, color)
	if has_focus():
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), GOLD, false, 1.0)
