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

var _laboratory: Dictionary = {}
var _stock: float = 0.0
var _paused: bool = false
var _render_elapsed: float = 0.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(360, 300)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_font("font", "Label")
	resized.connect(_request_redraw)
	visibility_changed.connect(_update_processing)
	_update_processing()

func present(state: Dictionary) -> void:
	var derived: Dictionary = state.get("derived", {})
	var laboratory: Dictionary = derived.get("laboratory", {})
	var stock: float = float(state.get("run", {}).get("wallet", {}).get("data", 0.0))
	var paused: bool = bool(state.get("paused", false))
	var changed: bool = _laboratory != laboratory or _stock != stock or _paused != paused or _render_elapsed > 0.0
	_laboratory = laboratory
	_stock = stock
	_paused = paused
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
	return is_visible_in_tree() and not _paused and bool(_laboratory.get("active", false)) and not str(_laboratory.get("assigned_worker", "")).is_empty() and float(_laboratory.get("cycle_seconds", 0.0)) > 0.0 and float(_laboratory.get("progress", 0.0)) < 1.0

func _process(delta: float) -> void:
	if not _can_advance():
		set_process(false)
		return
	# Only interpolate the current snapshot; completion and stock belong to the rules.
	_render_elapsed = minf(_render_elapsed + delta, ContentCatalog.STEP)
	queue_redraw()
	if _render_elapsed >= ContentCatalog.STEP or _progress() >= 1.0:
		set_process(false)

func _progress() -> float:
	var progress: float = float(_laboratory.get("progress", 0.0))
	var seconds: float = float(_laboratory.get("cycle_seconds", 0.0))
	if _can_advance() and seconds > 0.0:
		progress += _render_elapsed / seconds
	return clampf(progress, 0.0, 1.0)

func _status_caption() -> String:
	if _laboratory.is_empty():
		return "Исследовательский пост недоступен"
	if _paused:
		return "Пауза — цикл сохранён"
	if not str(_laboratory.get("pending_worker", "")).is_empty():
		return "Ожидаем возвращения сборщика"
	if str(_laboratory.get("assigned_worker", "")).is_empty():
		return "Нет оператора — данных нет"
	if bool(_laboratory.get("active", false)):
		return "Исследование идёт"
	return "Исследование остановлено"

func _staff_caption() -> String:
	var assigned: String = str(_laboratory.get("assigned_worker", ""))
	var pending: String = str(_laboratory.get("pending_worker", ""))
	if not assigned.is_empty():
		return assigned.to_upper() + " · единственный научный пост"
	if not pending.is_empty():
		return pending.to_upper() + " · пост зарезервирован"
	return "Один свободный пост на корабле" if not _laboratory.is_empty() else ""

func _draw() -> void:
	if not is_visible_in_tree():
		return
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _font == null:
		return
	var compact: bool = size.x < 560.0
	var inset: float = 16.0 if compact else 24.0
	var width: float = size.x - inset * 2.0
	var running: bool = bool(_laboratory.get("active", false)) and not _paused and not str(_laboratory.get("assigned_worker", "")).is_empty()
	var pending: bool = not str(_laboratory.get("pending_worker", "")).is_empty()
	var status_color: Color = ACTIVE if running else (GOLD if _paused or pending else STOPPED)
	_text("Схема исследования", Vector2(inset, 27), width, 19, INK)
	_text(_status_caption(), Vector2(inset, 49), width, 14, status_color)
	_text(_staff_caption(), Vector2(inset, 69), width, 13, MUTED)
	if _laboratory.is_empty():
		_text("Сведения о научном посте ещё не получены", Vector2(inset, 125), width, 13, MUTED)
		_text("Данные в запасе %.1f" % _stock, Vector2(inset, size.y - 65), width, 15, GOLD)
		return
	_draw_process(Rect2(Vector2(inset, 85), Vector2(width, size.y - 209.0)), running)
	var remaining: float = maxf(0.0, float(_laboratory.get("remaining_seconds", 0.0)) - (_render_elapsed if _can_advance() else 0.0))
	var progress_caption: String = "Исследование · %.0f%%" % (_progress() * 100.0)
	if str(_laboratory.get("assigned_worker", "")).is_empty():
		progress_caption = "Цикл ещё не начат"
	_text(progress_caption, Vector2(inset, size.y - 99), width - 100.0, 13, INK)
	_text("Осталось %.1f с" % remaining, Vector2(size.x - inset - 100.0, size.y - 99), 100.0, 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var rail: Rect2 = Rect2(Vector2(inset, size.y - 89), Vector2(width, 5))
	draw_rect(rail, DARK_METAL)
	rail.size.x *= _progress()
	if rail.size.x > 0.0:
		draw_rect(rail, ACTIVE if running else MUTED)
	var rate: float = 0.0 if _paused else float(_laboratory.get("rate", 0.0))
	_text("Данные %.2f/с" % rate, Vector2(inset, size.y - 65), width * 0.47, 13, ACTIVE if rate > 0.0 else MUTED)
	_text("+%.0f в конце цикла" % float(_laboratory.get("batch", 0.0)), Vector2(inset + width * 0.47, size.y - 65), width * 0.53, 13, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var instruction: String = "Отзыв сбрасывает незавершённый цикл"
	if pending:
		instruction = "Сначала доставка груза, затем исследование"
	elif str(_laboratory.get("assigned_worker", "")).is_empty():
		instruction = "Назначьте работника на научный пост"
	_text(instruction, Vector2(inset, size.y - 42), width, 12, MUTED)
	_text("Данные доступны на корабле до города", Vector2(inset, size.y - 20), width, 12, MUTED)

func _draw_process(area: Rect2, running: bool) -> void:
	var column: float = area.size.x / 3.0
	var radius: float = clampf((area.size.y - 34.0) * 0.38, 23.0, 34.0)
	var center_y: float = area.position.y + (area.size.y - 22.0) * 0.5
	var operator_center: Vector2 = Vector2(area.position.x + column * 0.5, center_y)
	var cycle_center: Vector2 = Vector2(area.position.x + column * 1.5, center_y)
	var stock_center: Vector2 = Vector2(area.position.x + column * 2.5, center_y)
	var box_width: float = minf(column - 24.0, 112.0)
	var assigned: String = str(_laboratory.get("assigned_worker", ""))
	var pending: String = str(_laboratory.get("pending_worker", ""))
	var operator_id: String = assigned if not assigned.is_empty() else pending
	var operator_color: Color = ACTIVE if running else (GOLD if not pending.is_empty() else METAL)
	var cycle_color: Color = ACTIVE if running else MUTED
	var input_start: Vector2 = operator_center + Vector2(box_width * 0.5 + 4.0, 0)
	var input_end: Vector2 = cycle_center - Vector2(radius + 8.0, 0)
	var output_start: Vector2 = cycle_center + Vector2(radius + 8.0, 0)
	var output_end: Vector2 = stock_center - Vector2(box_width * 0.5 + 4.0, 0)
	_draw_arrow(input_start, input_end, PIPE)
	_draw_arrow(output_start, output_end, PIPE)
	var operator_box: Rect2 = Rect2(operator_center - Vector2(box_width * 0.5, 22), Vector2(box_width, 44))
	draw_rect(operator_box, DARK_METAL)
	draw_rect(operator_box, operator_color, false, 1.0)
	_text(operator_id.to_upper() if not operator_id.is_empty() else "—", operator_center + Vector2(-box_width * 0.5 + 3, 5), box_width - 6, 16, operator_color, HORIZONTAL_ALIGNMENT_CENTER)
	draw_circle(cycle_center, radius, DARK_METAL, true, -1.0, true)
	draw_arc(cycle_center, radius, -PI * 0.5, PI * 1.5, 40, PIPE, 2.0, true)
	var progress: float = _progress()
	if progress > 0.0:
		draw_arc(cycle_center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, cycle_color, 3.0, true)
	_text("%.0f с" % float(_laboratory.get("cycle_seconds", 0.0)), cycle_center + Vector2(-radius + 2, 5), radius * 2.0 - 4.0, 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var stock_box: Rect2 = Rect2(stock_center - Vector2(box_width * 0.5, 22), Vector2(box_width, 44))
	draw_rect(stock_box, DARK_METAL)
	draw_line(stock_box.position, Vector2(stock_box.end.x, stock_box.position.y), GOLD, 2.0, true)
	draw_line(Vector2(stock_box.position.x, stock_box.end.y), stock_box.end, PIPE, 1.0, true)
	_text("%.1f" % _stock, stock_center + Vector2(-box_width * 0.5 + 3, 5), box_width - 6, 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var operator_caption: String = "Оператор" if not assigned.is_empty() else ("В пути" if not pending.is_empty() else "Нет оператора")
	var label_y: float = area.end.y - 3.0
	_text(operator_caption, Vector2(area.position.x, label_y), column, 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_text("Исследование", Vector2(area.position.x + column, label_y), column, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text("Запас данных", Vector2(area.position.x + column * 2.0, label_y), column, 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_arrow(start: Vector2, end: Vector2, color: Color) -> void:
	if end.x <= start.x:
		return
	draw_line(start, end, color, 1.5, true)
	draw_line(end - Vector2(4, 3), end, color, 1.5, true)
	draw_line(end - Vector2(4, -3), end, color, 1.5, true)

func _text(text: String, position: Vector2, width: float, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if width <= 0.0:
		return
	var caption: String = text
	if _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		while caption.length() > 1 and _font.get_string_size(caption + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			caption = caption.left(caption.length() - 1)
		caption += "…"
	draw_string(_font, position, caption, alignment, width, font_size, color)
