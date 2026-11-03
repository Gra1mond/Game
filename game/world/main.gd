extends Control

const PortView = preload("res://world/port_view.gd")
const COLLECT_COMMAND: Dictionary = {"type": "collect"}
const PHASE_NAMES: Dictionary = {"idle": "свободен", "outbound": "к обломку", "loading": "погрузка", "returning": "доставка"}
const REASONS: Dictionary = {
	"paused": "Игра на паузе — продолжите, чтобы выполнять действия.",
	"insufficient_alloy": "Не хватает сплава. Разберите обломок вручную или дождитесь доставки.",
	"already_built": "Порт уже построен; повторная цена не списана.",
	"already_assigned": "Это назначение уже действует или ожидает возвращения.",
	"already_idle": "Сборщик уже свободен.", "unknown_station": "Сначала постройте порт.",
	"unknown_worker": "Такого сборщика нет.", "unknown_target": "Выберите ближний обломок или дальнее судно.",
	"max_level": "Увеличенный трюм уже установлен.", "cooldown": "Ручной сбор доступен каждые 0,5 секунды.",
}

var session := GameSession.new()
var clock := FixedClock.new()
var paused: bool:
	get:
		return session.is_paused()
var status: Label
var resources: Label
var harbor: Control
var _pause_button: Button
var _build_button: Button
var _buy_button: Button
var _upgrade_button: Button
var _collect_button: Button
var _station_label: Label
var _route_label: Label
var _workers_container: VBoxContainer
var _worker_rows: Dictionary = {}
var _collect_held := false

func _ready() -> void:
	session.new_profile(1)
	_build_interface()
	_refresh()

func _build_interface() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", Color("e8edf0"))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203440") if state == "normal" else Color("2b4552")
		if state == "disabled":
			style.bg_color = Color("16232e")
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = Color("f5cb7d")
		style.set_corner_radius_all(4)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		ui_theme.set_stylebox(state, "Button", style)
	theme = ui_theme
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := _label("Маяки в тумане", 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_pause_button = _button("Пауза [Пробел]", "Pause", _toggle_pause)
	header.add_child(_pause_button)
	resources = _label("", 18)
	resources.name = "Resources"
	layout.add_child(resources)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	harbor = PortView.new()
	harbor.name = "PortView"
	harbor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harbor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(harbor)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.x = 340
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sidebar_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 12)
	sidebar_scroll.add_child(sidebar)
	sidebar.add_child(_label("Кладбище кораблей", 21))
	_station_label = _wrapped_label()
	sidebar.add_child(_station_label)
	_build_button = _button("", "BuildPort", func() -> void: dispatch_command({"type": "build", "kind": "port"}))
	sidebar.add_child(_build_button)
	_buy_button = _button("", "BuyWorker", func() -> void: dispatch_command({"type": "buy_worker"}))
	sidebar.add_child(_buy_button)
	_upgrade_button = _button("", "UpgradeHold", func() -> void: dispatch_command({"type": "upgrade", "id": "cargo_hold"}))
	sidebar.add_child(_upgrade_button)
	_collect_button = _button("Разобрать обломок  ·  +1 сплав", "Collect", Callable())
	_collect_button.button_down.connect(func() -> void:
		_collect_held = true
		dispatch_command(COLLECT_COMMAND))
	_collect_button.button_up.connect(func() -> void: _collect_held = false)
	sidebar.add_child(_collect_button)
	sidebar.add_child(_label("Два пути к сплаву", 19))
	_route_label = _wrapped_label()
	sidebar.add_child(_route_label)
	var workers_heading := _label("Сборщики — назначения можно свободно менять", 19)
	layout.add_child(workers_heading)
	var worker_scroll := ScrollContainer.new()
	worker_scroll.custom_minimum_size.y = 174
	worker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(worker_scroll)
	_workers_container = VBoxContainer.new()
	_workers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workers_container.add_theme_constant_override("separation", 8)
	worker_scroll.add_child(_workers_container)
	status = _wrapped_label()
	status.name = "Status"
	status.custom_minimum_size.y = 44
	status.text = "Постройте порт и назначьте сборщика. Ручной сбор доступен без топлива и работников."
	layout.add_child(status)

func _process(delta: float) -> void:
	var steps: int = clock.frame(session, delta)
	var collected := false
	if _collect_held:
		var result: Dictionary = session.dispatch(COLLECT_COMMAND)
		collected = result.accepted
	if steps > 0 or collected or _pause_button.text.begins_with("Продолжить") != paused:
		_refresh()

func dispatch_command(command: Dictionary) -> Dictionary:
	var result: Dictionary = session.dispatch(command)
	if result.accepted:
		match command.get("type", ""):
			"recall": status.text = "Возврат запрошен: погруженный груз будет доставлен один раз."
			"assign": status.text = "Назначение принято. В пути новая цель начнётся после возвращения."
			"upgrade": status.text = "Трюм увеличен. Уже погруженный груз не меняется; сравните отдачу маршрутов."
			"buy_worker": status.text = "Новый сборщик свободен — выберите ему маршрут ниже."
			"build": status.text = "Порт построен. Назначьте свободного сборщика на один из маршрутов."
			"pause": status.text = "Пауза" if paused else "Экспедиция продолжается."
			_: status.text = "Сплав получен."
	else:
		status.text = REASONS.get(result.reason_code, "Действие недоступно: " + str(result.reason_code))
	_refresh()
	return result

func _toggle_pause() -> void:
	_collect_held = false
	dispatch_command({"type": "pause", "paused": not paused})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_pause_button):
		_collect_held = false
		session.dispatch({"type": "pause", "paused": true})
		status.text = "Пауза: приложение потеряло фокус."
		_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	var state: Dictionary = session.snapshot()
	var details: Dictionary = state.derived
	var built: bool = state.run.stations.has("port")
	resources.text = "Сплав  %.0f     Выпущено  %.0f     Сборщиков  %d     Питание  %.0f / %.0f" % [state.run.wallet.alloy, state.run.lifetime_produced.alloy, state.run.workers.size(), details.power_used, details.power_capacity]
	_pause_button.text = "Продолжить [Пробел]" if paused else "Пауза [Пробел]"
	_build_button.text = "Порт построен" if built else "Построить порт  ·  %.0f сплава" % details.prices.port.alloy
	_build_button.disabled = built or paused
	_buy_button.text = "Новый сборщик  ·  %.0f сплава" % details.prices.worker.alloy
	_buy_button.disabled = paused
	var upgraded: bool = details.upgrades.cargo_hold.level >= details.upgrades.cargo_hold.max_level
	_upgrade_button.text = "Трюм увеличен до %.0f" % details.capacity if upgraded else "Увеличить трюм до %.0f  ·  %.0f сплава" % [details.upgrades.cargo_hold.next_capacity, details.upgrades.cargo_hold.cost.alloy]
	_upgrade_button.disabled = paused or not built or upgraded
	_collect_button.disabled = paused
	var port: Dictionary = details.stations.port
	if not built:
		_station_label.text = "Нет станции. Строительство — первый шаг к автоматической добыче."
	elif port.assigned_workers == 0:
		_station_label.text = "Нет рабочего. Выберите маршрут сборщику ниже."
	else:
		_station_label.text = "Работает: %d сборщиков.\nСредний выпуск при повторении: %.2f сплава/с. Выплата — только при доставке." % [port.assigned_workers, port.rate]
	var route_lines: PackedStringArray = []
	for target: String in details.routes:
		var route: Dictionary = details.routes[target]
		var upgraded_route: Dictionary = details.upgraded_routes[target]
		route_lines.append("%s\n%.0f груза / %.0f с = %.2f/с\nС увеличенным трюмом: %.2f/с" % [route.name, route.cargo, route.cycle_seconds, route.rate, upgraded_route.rate])
	_route_label.text = "\n\n".join(route_lines)
	for id: String in state.run.workers:
		if not _worker_rows.has(id):
			_create_worker_row(id)
		var row: Dictionary = _worker_rows[id]
		var worker: Dictionary = state.run.workers[id]
		var visual: Dictionary = details.workers[id]
		var phase_name: String = PHASE_NAMES[worker.phase]
		var queue_text := ""
		if worker.recall_pending:
			queue_text = " → свободен" if worker.queued_assignment.is_empty() else " → " + str(details.routes[worker.queued_target].name)
		row.summary.text = "%s  ·  %s  ·  груз %.0f / %.0f%s" % [id.to_upper(), phase_name, worker.cargo, visual.capacity, queue_text]
		row.progress.value = visual.progress * 100.0 if worker.phase != "idle" else 0.0
		row.near.disabled = paused or (worker.assignment == "port" and worker.target == "near" and not worker.recall_pending) or not built
		row.far.disabled = paused or (worker.assignment == "port" and worker.target == "far" and not worker.recall_pending) or not built
		row.recall.disabled = paused or worker.assignment.is_empty() or (worker.recall_pending and worker.queued_assignment.is_empty())
	harbor.present(state)

func _create_worker_row(id: String) -> void:
	var box := VBoxContainer.new()
	box.name = id
	_workers_container.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var summary := _label("", 15)
	summary.custom_minimum_size.x = 340
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	var near := _button("Ближний обломок", "Near", func() -> void: dispatch_command({"type": "assign", "worker": id, "station": "port", "target": "near"}))
	row.add_child(near)
	var far := _button("Дальнее судно", "Far", func() -> void: dispatch_command({"type": "assign", "worker": id, "station": "port", "target": "far"}))
	row.add_child(far)
	var recall := _button("Вернуть", "Recall", func() -> void: dispatch_command({"type": "recall", "worker": id}))
	row.add_child(recall)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 5
	progress.show_percentage = false
	box.add_child(progress)
	_worker_rows[id] = {"summary": summary, "progress": progress, "near": near, "far": far, "recall": recall}

func _button(text: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	if action.is_valid():
		button.pressed.connect(action)
	return button

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _wrapped_label() -> Label:
	var label := _label("", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
