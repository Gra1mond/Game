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
const MODE_NAMES: Dictionary = {"steady": "ровный ход", "overdrive": "форсаж"}
const REASONS: Dictionary = {
	"not_built": "Станция не построена — добычи нет",
	"no_worker": "Нет работника — партия ждёт",
	"no_power": "Не хватает питания — работа сохранена",
	"disconnected": "Нет связи с кораблём — работа сохранена",
	"manual_off": "Станция выключена — работа сохранена",
	"cooling": "Автоохлаждение — добычи нет",
}

var _state: Dictionary = {}
var _oil: Dictionary = {}
var _render_elapsed := 0.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(360, 260)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_font("font", "Label")
	resized.connect(queue_redraw)
	visibility_changed.connect(_update_processing)
	_update_processing()

func present(state: Dictionary) -> void:
	_state = state
	_oil = state.derived.stations.oil
	_render_elapsed = 0.0
	_update_processing()
	if is_visible_in_tree():
		queue_redraw()

func _update_processing() -> void:
	set_process(is_visible_in_tree() and _can_advance() and _render_elapsed < ContentCatalog.STEP)
	if is_visible_in_tree():
		queue_redraw()

func _can_advance() -> bool:
	if _state.is_empty() or _oil.is_empty() or bool(_state.paused) or not bool(_oil.built):
		return false
	# Cooling is passive: a disconnected or unstaffed pump still loses heat.
	if str(_oil.phase) == "cooling":
		return float(_oil.cooling_seconds) > 0.0
	return bool(_oil.active) and float(_oil.progress) < 1.0 and float(_oil.phase_seconds) > 0.0

func _process(delta: float) -> void:
	_render_elapsed = minf(_render_elapsed + delta, ContentCatalog.STEP)
	queue_redraw()
	if _render_elapsed >= ContentCatalog.STEP or _progress() >= 1.0:
		set_process(false)

func _progress() -> float:
	var progress := float(_oil.progress)
	if _can_advance() and float(_oil.phase_seconds) > 0.0:
		progress += _render_elapsed / float(_oil.phase_seconds)
	return clampf(progress, 0.0, 1.0)

func _pressure() -> float:
	var pressure := float(_oil.pressure)
	if str(_oil.phase) == "pressure" and _can_advance() and float(_oil.phase_seconds) > 0.0:
		pressure += _render_elapsed / float(_oil.phase_seconds)
	return clampf(pressure, 0.0, 1.0)

func _heat() -> float:
	var heat := float(_oil.heat)
	if str(_oil.phase) == "cooling" and _can_advance():
		heat *= maxf(0.0, 1.0 - _render_elapsed / float(_oil.cooling_seconds))
	return heat

func _remaining_seconds() -> float:
	if str(_oil.phase) == "cooling":
		return maxf(0.0, float(_oil.cooling_seconds) - (_render_elapsed if _can_advance() else 0.0))
	return maxf(0.0, (1.0 - _progress()) * float(_oil.phase_seconds))

func _mode_caption() -> String:
	var selected := str(_oil.mode)
	var committed := str(_oil.cycle_mode)
	if committed.is_empty():
		committed = selected
	var caption := str(MODE_NAMES[committed])
	if selected != committed:
		caption += " → " + str(MODE_NAMES[selected]) + " со след. партии"
	return caption

func _staff_caption() -> String:
	var assigned := str(_oil.assigned_worker)
	var pending := str(_oil.pending_worker)
	if not assigned.is_empty():
		return assigned.to_upper() + " на посту"
	if not pending.is_empty():
		return pending.to_upper() + " в пути из порта"
	return "Пост свободен"

func _status_caption() -> String:
	if bool(_state.paused):
		return "Пауза — работа и охлаждение остановлены"
	if not bool(_oil.built):
		return str(REASONS.not_built)
	# Cooling must remain visible even when the power/worker reason takes precedence.
	if str(_oil.phase) == "cooling":
		var reason := str(_oil.reason)
		if reason in ["disconnected", "no_power", "manual_off", "no_worker"]:
			var short_reason: Dictionary = {
				"disconnected": "нет связи", "no_power": "нет питания",
				"manual_off": "выключено", "no_worker": "нет работника",
			}
			return "Охлаждение без добычи · " + str(short_reason[reason])
		return str(REASONS.cooling)
	if str(_oil.reason) != "working":
		return str(REASONS.get(_oil.reason, "Работа остановлена"))
	return "Набор давления — масло ещё не поступает" if str(_oil.phase) == "pressure" else "Откачка — партия поступит по завершении"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _state.is_empty() or _font == null:
		return
	var built := bool(_oil.built)
	var compact := size.x < 560.0
	var inset := 16.0 if compact else 24.0
	var width := size.x - inset * 2.0
	_text("Насосная станция", Vector2(inset, 27), width, 19, INK)
	if not compact:
		_text("Схема процесса", Vector2(size.x - inset - 150, 27), 150, 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var status_color := ACTIVE if bool(_oil.active) else STOPPED
	if bool(_state.paused) or str(_oil.phase) == "cooling":
		status_color = GOLD
	_text(_status_caption(), Vector2(inset, 49), width, 14, status_color)
	if built:
		if compact:
			_text(_staff_caption() + " · " + _mode_caption().replace(" со след. партии", ""), Vector2(inset, 69), width, 12, MUTED)
		else:
			_text(_staff_caption(), Vector2(inset, 69), width * 0.4, 13, MUTED)
			_text(_mode_caption(), Vector2(inset + width * 0.4, 69), width * 0.6, 13, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_text("Постройте станцию и назначьте работника", Vector2(inset, 69), width, 13, MUTED)
	var diagram := Rect2(Vector2(inset, 82), Vector2(width, size.y - 165.0))
	if not built:
		_draw_unbuilt(diagram)
		_draw_stock(Vector2(size.x - inset - 126, size.y - 46), 126, 16)
		_text("Контур — площадка, не работающая машина", Vector2(inset, size.y - 15), width, 12, MUTED)
		return
	_draw_process(diagram)
	_draw_phase_strip(inset, width)
	_draw_heat(inset, width, compact)
	var legend := "Давление → откачка → запас · нагрев снизу"
	if str(_oil.phase) == "cooling":
		legend = "Остывает без питания; пауза останавливает" if compact else "Остывает без питания и работника; пауза замораживает"
	elif str(_oil.mode) != str(_oil.cycle_mode) and not str(_oil.cycle_mode).is_empty():
		legend = "Новый режим — со следующей партии"
	_text(legend, Vector2(inset, size.y - 15), width, 12, MUTED)

func _draw_process(area: Rect2) -> void:
	var center_y := area.position.y + area.size.y * 0.50
	var pressure_center := Vector2(area.position.x + area.size.x * 0.15, center_y)
	var pump_center := Vector2(area.position.x + area.size.x * 0.49, center_y + 7)
	var tank_center := Vector2(area.position.x + area.size.x * 0.83, center_y)
	var scale_factor := clampf(area.size.y / 112.0, 0.72, 1.45)
	var pipe_y := pump_center.y + 17.0 * scale_factor
	var pressure := _pressure()
	var progress := _progress()
	var pumping := str(_oil.phase) == "pumping"
	var cooling := str(_oil.phase) == "cooling"
	var working := bool(_oil.active) and not bool(_state.paused) and not cooling
	var radius := 25.0 * scale_factor
	# The input pressure and output batch have separate paths, not a decorative loop.
	draw_line(Vector2(pressure_center.x, pressure_center.y + radius), Vector2(pressure_center.x, pipe_y), PIPE, 5.0, true)
	draw_line(Vector2(pressure_center.x, pipe_y), Vector2(pump_center.x - 20 * scale_factor, pipe_y), PIPE, 5.0, true)
	var output_start := Vector2(pump_center.x + 28 * scale_factor, pipe_y)
	var output_end := Vector2(tank_center.x - 24 * scale_factor, pipe_y)
	draw_line(output_start, output_end, PIPE, 6.0, true)
	if pumping:
		draw_line(output_start, output_start.lerp(output_end, progress), GOLD if working else MUTED, 3.0, true)
		var packet := output_start.lerp(output_end, progress)
		draw_circle(packet, 4.0, GOLD if working else MUTED, true, -1.0, true)
	var outlet := Vector2(area.end.x - 3, pipe_y)
	draw_line(Vector2(tank_center.x + 24 * scale_factor, pipe_y), outlet, PIPE, 4.0, true)
	var consumption := float(_state.derived.oil_consumption)
	if consumption > 0.0 and not bool(_state.paused):
		draw_line(outlet + Vector2(-6, -4), outlet, GOLD, 2.0, true)
		draw_line(outlet + Vector2(-6, 4), outlet, GOLD, 2.0, true)
	var stock_caption := "Расход %.1f/с" % consumption if consumption > 0.0 and not bool(_state.paused) else "Общий запас"
	_text(stock_caption, Vector2(area.position.x + area.size.x * 0.68, area.position.y + 13), area.size.x * 0.32, 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	# A pressure dial reads the actual normalized station pressure.
	draw_circle(pressure_center, radius, DARK_METAL, true, -1.0, true)
	draw_arc(pressure_center, radius, PI * 0.75, PI * 2.25, 32, PIPE, 3.0, true)
	if pressure > 0.0:
		draw_arc(pressure_center, radius, PI * 0.75, PI * (0.75 + 1.5 * pressure), 32, ACTIVE, 3.0, true)
	var angle := PI * (0.75 + 1.5 * pressure)
	draw_line(pressure_center, pressure_center + Vector2.from_angle(angle) * radius * 0.72, INK, 2.0, true)
	draw_circle(pressure_center, 3, GOLD, true, -1.0, true)
	_draw_pump(pump_center, scale_factor, progress if pumping else 0.0, cooling)
	_draw_tank(tank_center, scale_factor)
	var label_y := area.end.y - 2.0
	var column_width := area.size.x * 0.3
	_text("Давление %.0f%%" % (pressure * 100.0), Vector2(pressure_center.x - column_width * 0.5, label_y), column_width, 12, ACTIVE, HORIZONTAL_ALIGNMENT_CENTER)
	var pump_label := "Охлаждение" if cooling else ("Откачка" if pumping else "Подготовка")
	_text(pump_label, Vector2(pump_center.x - column_width * 0.5, label_y), column_width, 12, GOLD if cooling else INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text("Масло %.1f" % float(_state.run.wallet.oil), Vector2(tank_center.x - column_width * 0.5, label_y), column_width, 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	if area.size.x >= 560.0:
		var batch_caption := "Без выдачи масла" if cooling else "+%.0f в конце партии" % float(_oil.next_output)
		_text(batch_caption, Vector2(area.position.x + area.size.x * 0.30, area.position.y + 13), area.size.x * 0.4, 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_pump(center: Vector2, scale_factor: float, progress: float, cooling: bool) -> void:
	var base := center + Vector2(0, 25) * scale_factor
	var pivot := center + Vector2(0, -8) * scale_factor
	var stroke := sin(progress * TAU) * 0.23
	var beam_left := pivot + Vector2(-36, -3).rotated(stroke) * scale_factor
	var beam_right := pivot + Vector2(28, -3).rotated(stroke) * scale_factor
	draw_rect(Rect2(base + Vector2(-39, -3) * scale_factor, Vector2(79, 7) * scale_factor), DARK_METAL)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-17, 0) * scale_factor, pivot, base + Vector2(17, 0) * scale_factor]), DARK_METAL)
	draw_line(base + Vector2(-17, 0) * scale_factor, pivot, METAL, 3.0, true)
	draw_line(pivot, base + Vector2(17, 0) * scale_factor, METAL, 3.0, true)
	draw_line(beam_left, beam_right, METAL, 6.0 * scale_factor, true)
	draw_line(beam_left, Vector2(beam_left.x, base.y + 10 * scale_factor), GOLD if not cooling else MUTED, 2.0, true)
	draw_rect(Rect2(Vector2(beam_left.x - 8 * scale_factor, base.y + 6 * scale_factor), Vector2(16, 5) * scale_factor), METAL)
	var motor := base + Vector2(28, -8) * scale_factor
	draw_circle(motor, 10 * scale_factor, DARK_METAL, true, -1.0, true)
	draw_arc(motor, 10 * scale_factor, 0, TAU, 24, METAL, 2.0, true)
	var crank := motor + Vector2.from_angle(progress * TAU) * 6 * scale_factor
	draw_line(motor, crank, GOLD if not cooling else MUTED, 2.0, true)
	draw_line(crank, beam_right, METAL, 2.0, true)
	draw_circle(pivot, 4 * scale_factor, GOLD, true, -1.0, true)
	if cooling:
		# Three static vent arrows denote passive heat loss; there is no free-running animation.
		for offset: int in [-16, 0, 16]:
			var tip := center + Vector2(offset, -39) * scale_factor
			draw_line(tip + Vector2(0, 11) * scale_factor, tip, ACTIVE, 1.5, true)
			draw_line(tip + Vector2(-3, 4) * scale_factor, tip, ACTIVE, 1.5, true)
			draw_line(tip + Vector2(3, 4) * scale_factor, tip, ACTIVE, 1.5, true)

func _draw_tank(center: Vector2, scale_factor: float) -> void:
	var tank := Rect2(center + Vector2(-24, -28) * scale_factor, Vector2(48, 61) * scale_factor)
	draw_rect(tank, DARK_METAL)
	draw_rect(tank, METAL, false, 2.0)
	for offset: int in [-14, 18]:
		draw_line(center + Vector2(-24, offset) * scale_factor, center + Vector2(24, offset) * scale_factor, METAL, 2.0, true)
	draw_line(center + Vector2(10, -28) * scale_factor, center + Vector2(10, -36) * scale_factor, METAL, 3.0, true)
	# This is the shared oil stock, not an invented tank capacity/fill percentage.
	var drop_center := center + Vector2(0, 3) * scale_factor
	draw_colored_polygon(PackedVector2Array([drop_center + Vector2(0, -12) * scale_factor, drop_center + Vector2(-7, 0) * scale_factor, drop_center + Vector2(7, 0) * scale_factor]), GOLD)
	draw_circle(drop_center, 7 * scale_factor, GOLD, true, -1.0, true)

func _draw_phase_strip(inset: float, width: float) -> void:
	var phase := str(_oil.phase)
	var progress := _progress()
	var label := "Набор давления"
	if phase == "pumping":
		label = "Откачка · +%.0f в конце" % float(_oil.next_output)
	elif phase == "cooling":
		label = "Автоохлаждение · без добычи"
	_text(label, Vector2(inset, size.y - 70), width - 72, 13, INK)
	_text("%.1f с" % _remaining_seconds(), Vector2(size.x - inset - 70, size.y - 70), 70, 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var rail := Rect2(Vector2(inset, size.y - 61), Vector2(width, 5))
	draw_rect(rail, DARK_METAL)
	rail.size.x *= progress
	if rail.size.x > 0.0:
		draw_rect(rail, GOLD if phase == "cooling" else ACTIVE)

func _draw_heat(inset: float, width: float, compact: bool) -> void:
	var heat := _heat()
	var limit := float(_oil.heat_limit)
	var heat_color := STOPPED if heat >= limit else (GOLD if heat > 0 else MUTED)
	var label_width := 118.0 if compact else 145.0
	_text("Нагрев %.0f / %.0f" % [heat, limit], Vector2(inset, size.y - 37), label_width, 13, heat_color)
	var bar := Rect2(Vector2(inset + label_width + 8, size.y - 46), Vector2(width - label_width - 8, 8))
	draw_rect(bar, DARK_METAL)
	bar.size.x *= clampf(heat / maxf(limit, 1.0), 0.0, 1.0)
	if bar.size.x > 0:
		draw_rect(bar, heat_color)

func _draw_unbuilt(area: Rect2) -> void:
	var base_y := area.position.y + area.size.y * 0.67
	var left := area.position.x + area.size.x * 0.16
	var right := area.end.x - area.size.x * 0.16
	draw_dashed_line(Vector2(left, base_y), Vector2(right, base_y), PIPE, 2.0, 7.0)
	for x: float in [left, right]:
		draw_line(Vector2(x, base_y - 26), Vector2(x, base_y + 7), METAL, 2.0, true)
		draw_line(Vector2(x - 6, base_y - 26), Vector2(x + 6, base_y - 26), METAL, 2.0, true)
	_text("Площадка насосной станции", Vector2(area.position.x, area.position.y + 21), area.size.x, 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_text("Машина появится после строительства", Vector2(area.position.x, area.end.y), area.size.x, 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_stock(position: Vector2, width: float, font_size: int) -> void:
	_text("Масло %.1f" % float(_state.run.wallet.oil), position, width, font_size, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

func _text(text: String, position: Vector2, width: float, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var caption := text
	if _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		while caption.length() > 1 and _font.get_string_size(caption + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			caption = caption.left(caption.length() - 1)
		caption += "…"
	draw_string(_font, position, caption, alignment, width, font_size, color)
