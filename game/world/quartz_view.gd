extends Control

const INK := Color("e8edf0")
const MUTED := Color("9caebb")
const GOLD := Color("f5cb7d")
const ACTIVE := Color("85c7ae")
const STOPPED := Color("e8a082")
const BACKGROUND := Color("101e29")
const METAL := Color("647d87")
const DARK_METAL := Color("29424c")
const PIPE := Color("49606e")
const PHASES: Array[String] = ["charge", "fracture", "cooling"]
const PHASE_NAMES: Dictionary = {"charge": "Заряд", "fracture": "Раскол", "cooling": "Охлаждение"}
const REASONS: Dictionary = {
	"no_worker": "Нет оператора — фаза сохранена",
	"no_power": "Не хватает питания — фаза сохранена",
	"disconnected": "Нет связи с кораблём — фаза сохранена",
	"manual_off": "Бур выключен — фаза сохранена",
	"not_discovered": "Район ещё не открыт",
}

var _drill: Dictionary = {}
var _quartz: Dictionary = {}
var _station_id := ""
var _stock := 0.0
var _paused := false
var _render_elapsed := 0.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(360, 300)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_font("font", "Label")
	resized.connect(_request_redraw)
	visibility_changed.connect(_update_processing)
	_update_processing()

func present(state: Dictionary, station_id: String = "") -> void:
	var derived: Dictionary = state.get("derived", {})
	var quartz: Dictionary = derived.get("quartz", {})
	var stations: Dictionary = derived.get("stations", {})
	var selected := station_id
	if selected.is_empty() or str(stations.get(selected, {}).get("kind", "")) != "quartz":
		selected = ""
		for id: String in quartz.get("station_ids", []):
			if stations.has(id):
				selected = id
				break
	var drill: Dictionary = stations.get(selected, {})
	var stock := float(state.get("run", {}).get("wallet", {}).get("quartz", 0.0))
	var paused := bool(state.get("paused", false))
	var changed := _drill != drill or _quartz != quartz or _stock != stock or _paused != paused or _station_id != selected or _render_elapsed > 0.0
	_drill = drill
	_quartz = quartz
	_stock = stock
	_paused = paused
	_station_id = selected
	_render_elapsed = 0.0
	_update_processing(false)
	if changed:
		_request_redraw()

func _request_redraw() -> void:
	if is_visible_in_tree():
		queue_redraw()

func _update_processing(redraw: bool = true) -> void:
	set_process(_can_advance() and _render_elapsed < ContentCatalog.STEP)
	if redraw:
		_request_redraw()

func _can_advance() -> bool:
	return is_visible_in_tree() and not _paused and bool(_drill.get("active", false)) and float(_drill.get("power", 0.0)) > 0.0 and not str(_drill.get("assigned_worker", "")).is_empty() and float(_drill.get("phase_seconds", 0.0)) > 0.0 and float(_drill.get("progress", 0.0)) < 1.0

func _process(delta: float) -> void:
	if not _can_advance():
		set_process(false)
		return
	# Presentation only: never cross a snapshot phase or advance beyond one core step.
	_render_elapsed = minf(_render_elapsed + delta, ContentCatalog.STEP)
	queue_redraw()
	if _render_elapsed >= ContentCatalog.STEP or _progress() >= 1.0:
		set_process(false)

func _progress() -> float:
	var progress := float(_drill.get("progress", 0.0))
	var seconds := float(_drill.get("phase_seconds", 0.0))
	if seconds > 0.0:
		progress += _render_elapsed / seconds
	return clampf(progress, 0.0, 1.0)

func _staff_caption() -> String:
	var worker := str(_drill.get("assigned_worker", ""))
	var pending := str(_drill.get("pending_worker", ""))
	if not worker.is_empty():
		return worker.to_upper() + " на посту"
	if not pending.is_empty():
		return pending.to_upper() + " возвращается из порта · пост зарезервирован"
	return "Пост свободен — назначьте оператора"

func _status_caption() -> String:
	if _paused:
		return "Пауза — все фазы сохранены"
	var reason := str(_drill.get("reason", ""))
	if REASONS.has(reason):
		return str(REASONS[reason])
	match str(_drill.get("phase", "charge")):
		"fracture":
			return "Раскол — кварц поступит в конце фазы"
		"cooling":
			return "Охлаждение — без выдачи кварца"
	return "Набор заряда — кварц ещё не поступает"

func _draw() -> void:
	if not is_visible_in_tree():
		return
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _font == null:
		return
	var inset := 16.0 if size.x < 560.0 else 24.0
	var width := size.x - inset * 2.0
	var built := bool(_drill.get("built", false))
	var title := "Кварцевый бур " + _station_id.trim_prefix("quartz_") if built else "Кварцевые буры"
	_text(title, Vector2(inset, 27), width - 145.0, 19, INK)
	_text("Схема процесса", Vector2(size.x - inset - 140, 27), 140, 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	if not built:
		_draw_unbuilt(inset, width)
		return
	var running := bool(_drill.get("active", false)) and not _paused
	_text(_status_caption(), Vector2(inset, 49), width, 14, ACTIVE if running else STOPPED)
	var power_width := 114.0
	_text(_staff_caption(), Vector2(inset, 69), width - power_width - 12, 13, MUTED)
	_text("Питание %.2f" % float(_drill.get("power", 0.0)), Vector2(size.x - inset - power_width, 69), power_width, 13, ACTIVE if float(_drill.get("power", 0.0)) > 0.0 else STOPPED, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_process(Rect2(Vector2(inset, 85), Vector2(width, size.y - 211.0)), running)
	_draw_lens(inset, width)
	var phase := str(_drill.get("phase", "charge"))
	var label := str(PHASE_NAMES.get(phase, phase)) + " · %.0f%%" % (_progress() * 100.0)
	_text(label, Vector2(inset, size.y - 78), width - 112, 13, INK)
	var remaining := maxf(0.0, float(_drill.get("remaining_seconds", 0.0)) - _render_elapsed)
	_text("%.1f с" % remaining, Vector2(size.x - inset - 100, size.y - 78), 100, 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var rail := Rect2(Vector2(inset, size.y - 68), Vector2(width, 5))
	draw_rect(rail, DARK_METAL)
	rail.size.x *= _progress()
	if rail.size.x > 0.0:
		draw_rect(rail, GOLD if phase == "cooling" else (ACTIVE if running else MUTED))
	_text("+%.0f кварца после раскола" % float(_drill.get("next_output", 0.0)), Vector2(inset, size.y - 42), width * 0.62, 13, INK)
	_text("Запас %.1f" % _stock, Vector2(inset + width * 0.62, size.y - 42), width * 0.38, 15, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("Все фазы, включая охлаждение, требуют питания и оператора", Vector2(inset, size.y - 18), width, 12, MUTED)

func _draw_process(area: Rect2, running: bool) -> void:
	var phase := str(_drill.get("phase", "charge"))
	var progress := _progress()
	var column := area.size.x / 3.0
	var radius := clampf((area.size.y - 42.0) * 0.43, 16.0, 34.0)
	var center_y := area.position.y + (area.size.y - 12.0) * 0.50
	for index: int in range(3):
		var current := PHASES[index]
		var selected := phase == current
		var center := Vector2(area.position.x + column * (index + 0.5), center_y)
		var color := (GOLD if current == "cooling" else ACTIVE) if running else MUTED
		if not selected:
			color = PIPE
		if index < 2:
			var start := center + Vector2(radius + 12, 0)
			var end := center + Vector2(column - radius - 12, 0)
			draw_line(start, end, PIPE, 2.0, true)
			draw_line(end + Vector2(-5, -4), end, PIPE, 2.0, true)
			draw_line(end + Vector2(-5, 4), end, PIPE, 2.0, true)
		draw_circle(center, radius, DARK_METAL, true, -1.0, true)
		draw_arc(center, radius, -PI * 0.5, PI * 1.5, 40, color, 2.0, true)
		if selected and progress > 0.0:
			draw_arc(center, radius + 4, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, color, 3.0, true)
		match current:
			"charge":
				var lens := int(_drill.get("cycle_lens_level", -1))
				var lens_color := GOLD if lens > 0 else METAL
				draw_arc(center, radius * 0.62, 0, TAU, 24, lens_color, 2.0, true)
				if lens > 0:
					draw_arc(center, radius * 0.40, 0, TAU, 24, lens_color, 1.0, true)
				draw_line(center - Vector2(radius * 0.8, 0), center + Vector2(radius * 0.8, 0), color, 2.0, true)
			"fracture":
				var extent := radius * 0.63
				var gap := progress * radius * 0.30 if selected else 0.0
				var left := center - Vector2(gap, 0)
				var right := center + Vector2(gap, 0)
				draw_polyline(PackedVector2Array([left + Vector2(0, -extent), left - Vector2(extent, 0), left + Vector2(0, extent)]), color, 2.0, true)
				draw_polyline(PackedVector2Array([right + Vector2(0, -extent), right + Vector2(extent, 0), right + Vector2(0, extent)]), color, 2.0, true)
			"cooling":
				for offset: int in [-1, 0, 1]:
					var tip := center + Vector2(offset * radius * 0.45, -radius * 0.48)
					draw_line(tip + Vector2(0, radius), tip, color, 2.0, true)
					draw_line(tip + Vector2(-3, 4), tip, color, 1.5, true)
					draw_line(tip + Vector2(3, 4), tip, color, 1.5, true)
		_text(str(PHASE_NAMES[current]), Vector2(area.position.x + index * column, area.end.y - 3), column, 13, INK if selected else MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_lens(inset: float, width: float) -> void:
	var committed := int(_drill.get("cycle_lens_level", -1))
	var level := int(_drill.get("lens_level", 0))
	var charge := float(_drill.get("charge_seconds", 0.0))
	var next_charge := float(_drill.get("next_charge_seconds", 0.0))
	var current := "Цикл: заряд %.1f с · линза %d" % [charge, committed] if committed >= 0 else "Первый заряд ещё не начат"
	var next := "Далее: заряд %.1f с · линза %d" % [next_charge, level]
	if width < 520.0:
		var caption := "Заряд %.1f → %.1f с · линза %d → %d" % [charge, next_charge, committed, level] if committed >= 0 else "Первый заряд %.1f с · линза %d" % [next_charge, level]
		_text(caption, Vector2(inset, size.y - 105), width, 12, GOLD)
	else:
		_text(current, Vector2(inset, size.y - 105), width * 0.5 - 8, 13, MUTED)
		_text(next, Vector2(inset + width * 0.5, size.y - 105), width * 0.5, 13, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_unbuilt(inset: float, width: float) -> void:
	var unlocked := bool(_quartz.get("unlocked", false))
	_text("Буры доступны — постройте первый в панели района" if unlocked else "Добыча кварца пока закрыта", Vector2(inset, 53), width, 14, ACTIVE if unlocked else GOLD)
	if unlocked:
		_text("После строительства назначьте оператора", Vector2(inset, 118), width, 15, INK)
		_text("Подключите район и выделите питание буру", Vector2(inset, 146), width, 13, MUTED)
		_text("Заряд → раскол → охлаждение", Vector2(inset, 190), width, 15, MUTED)
	else:
		var required: Dictionary = _quartz.get("required_stations", {})
		_text("Порт: " + ("построен" if bool(required.get("port", false)) else "нужно построить"), Vector2(inset, 113), width, 14, INK)
		_text("Насосная: " + ("построена" if bool(required.get("oil", false)) else "нужно построить"), Vector2(inset, 139), width, 14, INK)
		var requirements: Dictionary = _quartz.get("requirements", {})
		var row := 0
		for resource: String in ["alloy", "oil"]:
			var requirement: Dictionary = requirements.get(resource, {})
			var name := "Сплав" if resource == "alloy" else "Масло"
			_text("%s: произведено %.1f / %.0f" % [name, float(requirement.get("produced", 0.0)), float(requirement.get("required", 0.0))], Vector2(inset, 177 + row * 25), width, 14, MUTED)
			row += 1
		_text("Условия считают всю добычу, а не текущий запас", Vector2(inset, 228), width, 12, MUTED)
	_text("Кварц в запасе %.1f" % _stock, Vector2(inset, size.y - 42), width, 15, GOLD)
	_text("Один оператор на бур; кварц выдаётся после раскола", Vector2(inset, size.y - 18), width, 12, MUTED)

func _text(text: String, position: Vector2, width: float, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if width <= 0.0:
		return
	var caption := text
	if _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		while caption.length() > 1 and _font.get_string_size(caption + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			caption = caption.left(caption.length() - 1)
		caption += "…"
	draw_string(_font, position, caption, alignment, width, font_size, color)
