extends Control

const PortView = preload("res://world/port_view.gd")
const MapView = preload("res://world/map_view.gd")
const COLLECT_COMMAND: Dictionary = {"type": "collect"}
const PHASE_NAMES: Dictionary = {"idle": "свободен", "outbound": "к обломку", "loading": "погрузка", "returning": "доставка"}
const REASONS: Dictionary = {
	"paused": "Игра на паузе — продолжите, чтобы выполнять действия.",
	"insufficient_alloy": "Не хватает сплава. Разберите обломок вручную или дождитесь доставки.",
	"already_built": "Уже построено; повторная цена не списана.",
	"already_assigned": "Это назначение уже действует или ожидает возвращения.",
	"already_idle": "Сборщик уже свободен.", "unknown_station": "Сначала постройте порт.",
	"unknown_worker": "Такого сборщика нет.", "unknown_target": "Выберите ближний обломок или дальнее судно.",
	"max_level": "Увеличенный трюм уже установлен.", "cooldown": "Ручной сбор доступен каждые 0,5 секунды.",
	"disconnected": "Нет связи с кораблём. Включите и запитайте промежуточные реле.",
	"out_of_range": "Нет активного реле в радиусе связи. Сначала восстановите ближний участок сети.",
	"not_discovered": "Район в тумане. Запитайте ближайшее реле, чтобы открыть соседние берега.",
	"unknown_region": "Выберите открытый район на карте.",
	"unknown_relay": "Сначала постройте реле в этом районе.",
	"unknown_consumer": "Сначала постройте выбранное реле или станцию.",
	"invalid_power": "Запрос питания должен быть в пределах, указанных в поле.",
	"invalid_priority": "Приоритет должен быть целым числом в пределах поля.",
	"invalid_command": "Параметры действия недопустимы. Выберите район или потребителя заново.",
}
const NETWORK_REASONS: Dictionary = {
	"working": "Работает — питание выделено полностью.",
	"no_power": "Нет питания. Запрос должен быть не ниже минимума и целиком помещаться в остаток. Уменьшите запрос или повысьте приоритет; сначала запитайте родительские реле.",
	"disconnected": "Нет связи с кораблём. Включите и запитайте промежуточные реле на карте; приоритет дочернего узла не заменяет связь.",
	"manual_off": "Выключено вручную. Включите потребителя переключателем выше.",
	"no_worker": "Нет рабочего. Назначьте сборщика на маршрут ниже.",
	"not_built": "Реле не построено. Подведите действующую сеть и постройте его за сплав.",
	"not_discovered": "Неизвестный берег. Запитайте ближайшее реле, чтобы открыть район.",
}

var session := GameSession.new()
var clock := FixedClock.new()
var paused: bool:
	get:
		return session.is_paused()
var status: Label
var resources: Label
var harbor: Control
var map_view: Control
var _pause_button: Button
var _build_button: Button
var _relay_button: Button
var _buy_button: Button
var _upgrade_button: Button
var _collect_button: Button
var _port_button: Button
var _map_button: Button
var _station_label: Label
var _region_label: Label
var _route_label: Label
var _power_summary: Label
var _region_select: OptionButton
var _sidebar_tabs: TabContainer
var _workers_container: VBoxContainer
var _network_container: VBoxContainer
var _worker_rows: Dictionary = {}
var _power_rows: Dictionary = {}
var _collect_held := false
var _selected_region := "port"
var _detail_open := false

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
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := _label("Маяки в тумане", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_pause_button = _button("Пауза [Пробел]", "Pause", _toggle_pause)
	header.add_child(_pause_button)
	resources = _label("", 17)
	resources.name = "Resources"
	layout.add_child(resources)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var chart := VBoxContainer.new()
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(chart)
	var navigation := HBoxContainer.new()
	chart.add_child(navigation)
	_map_button = _button("Карта", "ShowMap", show_map)
	navigation.add_child(_map_button)
	_port_button = _button("Маршруты порта", "ShowPort", show_port)
	navigation.add_child(_port_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	navigation.add_child(_button("−", "ZoomOut", func() -> void: map_view.change_zoom(1.0 / 1.2)))
	navigation.add_child(_button("+", "ZoomIn", func() -> void: map_view.change_zoom(1.2)))
	navigation.add_child(_button("Сброс", "ResetMap", func() -> void: map_view.reset_view()))
	var viewport := Control.new()
	viewport.custom_minimum_size = Vector2(360, 260)
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.add_child(viewport)
	map_view = MapView.new()
	map_view.name = "MapView"
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(map_view)
	map_view.region_selected.connect(select_region)
	harbor = PortView.new()
	harbor.name = "PortView"
	harbor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(harbor)
	harbor.hide()
	var legend := _wrapped_label()
	legend.add_theme_font_size_override("font_size", 13)
	legend.text = "Карта: щелчок / ← → — район · колесо / + − — масштаб\nПеретаскивание / WASD — сдвиг · Home — сброс. Линии — только действующая сеть.\nКонтур — открытый берег; столбик — построено; светлый — работает; рыжий — остановлено."
	chart.add_child(legend)
	_sidebar_tabs = TabContainer.new()
	_sidebar_tabs.name = "SidebarTabs"
	_sidebar_tabs.custom_minimum_size.x = 400
	_sidebar_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_sidebar_tabs)
	var district := _scroll_tab("Район и порт")
	_region_select = OptionButton.new()
	_region_select.name = "RegionSelect"
	_region_select.item_selected.connect(func(index: int) -> void: select_region(str(_region_select.get_item_metadata(index))))
	district.add_child(_region_select)
	_region_label = _wrapped_label()
	_region_label.name = "RegionStatus"
	district.add_child(_region_label)
	_relay_button = _button("", "BuildRelay", func() -> void: dispatch_command({"type": "build_relay", "region": _selected_region}))
	district.add_child(_relay_button)
	district.add_child(HSeparator.new())
	district.add_child(_label("Кладбище кораблей", 20))
	_station_label = _wrapped_label()
	district.add_child(_station_label)
	_build_button = _button("", "BuildPort", func() -> void: dispatch_command({"type": "build", "kind": "port"}))
	district.add_child(_build_button)
	_buy_button = _button("", "BuyWorker", func() -> void: dispatch_command({"type": "buy_worker"}))
	district.add_child(_buy_button)
	_upgrade_button = _button("", "UpgradeHold", func() -> void: dispatch_command({"type": "upgrade", "id": "cargo_hold"}))
	district.add_child(_upgrade_button)
	_collect_button = _button("Разобрать обломок  ·  +1 сплав", "Collect", Callable())
	_collect_button.button_down.connect(func() -> void:
		_collect_held = true
		dispatch_command(COLLECT_COMMAND))
	_collect_button.button_up.connect(func() -> void: _collect_held = false)
	district.add_child(_collect_button)
	district.add_child(_label("Два пути к сплаву", 19))
	_route_label = _wrapped_label()
	district.add_child(_route_label)
	_network_container = _scroll_tab("Питание")
	_network_container.name = "NetworkPanel"
	_power_summary = _wrapped_label()
	_power_summary.name = "PowerSummary"
	_network_container.add_child(_power_summary)
	var power_help := _wrapped_label()
	power_help.text = "Выше приоритет — раньше питание. Запрос выделяется целиком, не частично. Реле и станция порта независимы: сначала нужна действующая цепь от корабля. Измените поля и нажмите «Применить»."
	_network_container.add_child(power_help)
	layout.add_child(_label("Сборщики — назначения можно свободно менять", 19))
	var worker_scroll := ScrollContainer.new()
	worker_scroll.name = "Workers"
	worker_scroll.custom_minimum_size.y = 110
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

func _scroll_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	return content

func select_region(region: String) -> bool:
	if not map_view.select_region(region):
		return false
	_selected_region = region
	if _detail_open and region != "port":
		show_map()
	_refresh()
	return true

func show_port() -> void:
	_selected_region = "port"
	map_view.select_region("port")
	_detail_open = true
	map_view.hide()
	harbor.show()
	_refresh()

func show_map() -> void:
	_detail_open = false
	harbor.hide()
	map_view.show()
	_refresh()

func show_network() -> void:
	_sidebar_tabs.current_tab = 1

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
			"build": status.text = "Порт и его реле построены. Назначьте сборщика; питание проверяется во вкладке «Питание»."
			"build_relay": status.text = "Реле построено. Действующая сеть открывает соседние берега; добыча нефти и кварца пока недоступна."
			"relay": status.text = "Реле включено. Проверьте связь и питание ветки." if command.enabled else "Реле выключено. Зависимые ветки остановлены, груз и фазы сохранены."
			"station_enabled": status.text = "Станция включена. Проверьте питание и назначения." if command.enabled else "Станция выключена. Реле продолжает независимо передавать связь."
			"power": status.text = "Запрос и приоритет применены. Распределение сети пересчитано; проверьте фактическую мощность и причину остановки."
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
	resources.text = "Сплав  %.0f     Выпущено  %.0f     Сборщиков  %d     Питание  %.2f / %.2f" % [state.run.wallet.alloy, state.run.lifetime_produced.alloy, state.run.workers.size(), details.power_used, details.power_capacity]
	_pause_button.text = "Продолжить [Пробел]" if paused else "Пауза [Пробел]"
	_map_button.disabled = not _detail_open
	_port_button.disabled = _detail_open
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
		_station_label.text = "Нет станции. Цена включает реле; уже построенное реле повторно не оплачивается."
	elif port.reason != "working":
		_station_label.text = str(NETWORK_REASONS.get(port.reason, port.reason))
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
	map_view.present(state)
	map_view.select_region(_selected_region)
	_refresh_region(details)
	_refresh_power(details)
	harbor.present(state)

func _refresh_region(details: Dictionary) -> void:
	var ids: Array[String] = []
	for id: String in details.regions:
		if details.regions[id].discovered:
			ids.append(id)
	if _region_select.item_count != ids.size():
		_region_select.clear()
		for id: String in ids:
			_region_select.add_item(str(details.regions[id].name))
			_region_select.set_item_metadata(_region_select.item_count - 1, id)
	_region_select.select(ids.find(_selected_region))
	var region: Dictionary = details.regions[_selected_region]
	if _selected_region == "ship":
		_region_label.text = "Корабль — источник аварийного питания.\nРадиус связи: %.0f. Доступная мощность: %.2f." % [details.range, details.power_capacity]
		_relay_button.text = "Источник сети — реле не требуется"
		_relay_button.disabled = true
		return
	var access := "Открыт для релейной связи" if region.unlocked else "Реле пока недоступно"
	_region_label.text = "%s · %s\n%s\nРадиус связи: %.0f. %s" % [region.name, access, str(NETWORK_REASONS.get(region.reason, region.reason)), details.range, "Добыча масла и кварца ещё недоступна." if _selected_region in ["oil", "quartz"] else "Сеть передаёт связь от корабля через активные реле."]
	_relay_button.text = "Реле построено · вкладка «Питание»" if region.built else "Построить реле  ·  %.0f сплава" % details.prices.relays[_selected_region].alloy
	_relay_button.disabled = paused or region.built or not region.unlocked or not region.reachable
	if not region.built and not region.reachable:
		_region_label.text += "\nСначала включите и запитайте соседнее реле: район вне действующей сети."

func _refresh_power(details: Dictionary) -> void:
	_power_summary.text = "Аварийное питание: %.2f / %.2f\nРадиус реле: %.0f. Остановленная ветка сохраняет груз и пройденную часть маршрута." % [details.power_used, details.power_capacity, details.range]
	for id: String in details.consumers:
		if not _power_rows.has(id):
			_create_power_row(id, details.power_limits)
		var row: Dictionary = _power_rows[id]
		var consumer: Dictionary = details.consumers[id]
		row.title.text = ("Реле · " if consumer.kind == "relay" else "Станция · ") + str(details.regions[consumer.region].name)
		row.enabled.set_pressed_no_signal(consumer.enabled)
		row.enabled.disabled = paused
		if not row.dirty:
			row.request.set_value_no_signal(consumer.request)
			row.priority.set_value_no_signal(consumer.priority)
		row.request.editable = not paused
		row.priority.editable = not paused
		row.apply.disabled = paused
		row.actual.text = "Факт %.2f · запрос %.2f · минимум %.2f" % [consumer.power, consumer.request, consumer.minimum_request]
		row.reason.text = str(NETWORK_REASONS.get(consumer.reason, consumer.reason))
		row.reason.add_theme_color_override("font_color", Color("85c7ae") if consumer.active else Color("f5cb7d"))

func _create_power_row(id: String, limits: Dictionary) -> void:
	_network_container.add_child(HSeparator.new())
	var box := VBoxContainer.new()
	box.name = id.replace(":", "_")
	box.add_theme_constant_override("separation", 6)
	_network_container.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var enabled := CheckButton.new()
	enabled.name = "Enabled"
	enabled.text = "Вкл."
	enabled.toggled.connect(func(value: bool) -> void:
		if id.begins_with("relay:"):
			dispatch_command({"type": "relay", "region": id.trim_prefix("relay:"), "enabled": value})
		else:
			dispatch_command({"type": "station_enabled", "station": id, "enabled": value}))
	heading.add_child(enabled)
	var fields := HBoxContainer.new()
	box.add_child(fields)
	fields.add_child(_label("Запрос", 15))
	var request := SpinBox.new()
	request.name = "Request"
	request.min_value = limits.min_request
	request.max_value = limits.max_request
	request.step = 0.05
	request.custom_minimum_size.x = 92
	fields.add_child(request)
	fields.add_child(_label("Приор.", 15))
	var priority := SpinBox.new()
	priority.name = "Priority"
	priority.min_value = limits.min_priority
	priority.max_value = limits.max_priority
	priority.step = 1
	priority.custom_minimum_size.x = 92
	fields.add_child(priority)
	var apply := _button("Применить", "Apply", func() -> void:
		var result: Dictionary = dispatch_command({"type": "power", "station": id, "request": request.value, "priority": int(priority.value)})
		if result.accepted:
			_power_rows[id].dirty = false)
	box.add_child(apply)
	var actual := _label("", 15)
	actual.name = "ActualPower"
	box.add_child(actual)
	var reason := _wrapped_label()
	reason.name = "Reason"
	box.add_child(reason)
	_power_rows[id] = {"title": title, "enabled": enabled, "request": request, "priority": priority, "apply": apply, "actual": actual, "reason": reason, "dirty": false}
	request.value_changed.connect(func(_value: float) -> void: _power_rows[id].dirty = true)
	priority.value_changed.connect(func(_value: float) -> void: _power_rows[id].dirty = true)

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
