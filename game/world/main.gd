extends Control

const PortView = preload("res://world/port_view.gd")
const MapView = preload("res://world/map_view.gd")
const OilView = preload("res://world/oil_view.gd")
const QuartzView = preload("res://world/quartz_view.gd")
const COLLECT_COMMAND: Dictionary = {"type": "collect"}
const PHASE_NAMES: Dictionary = {"idle": "свободен", "outbound": "к обломку", "loading": "погрузка", "returning": "доставка", "operating": "на станции"}
const OIL_PHASE_NAMES: Dictionary = {"pressure": "набор давления", "pumping": "откачка", "cooling": "охлаждение"}
const OIL_MODE_NAMES: Dictionary = {"steady": "ровный", "overdrive": "форсаж"}
const QUARTZ_PHASE_NAMES: Dictionary = {"charge": "заряд", "fracture": "раскол", "cooling": "охлаждение"}
const REASONS: Dictionary = {
	"paused": "Игра на паузе — продолжите, чтобы выполнять действия.",
	"insufficient_alloy": "Не хватает сплава. Разберите обломок вручную или дождитесь доставки.",
	"already_built": "Уже построено; повторная цена не списана.",
	"already_assigned": "Это назначение уже действует или ожидает возвращения.",
	"already_idle": "Работник уже свободен.", "unknown_station": "Сначала постройте выбранную станцию.",
	"unknown_worker": "Такого работника нет.", "unknown_target": "Выберите доступную цель назначения.",
	"max_level": "Это улучшение уже установлено.", "cooldown": "Ручной сбор доступен каждые 0,5 секунды.",
	"disconnected": "Нет связи с кораблём. Включите и запитайте промежуточные реле.",
	"out_of_range": "Нет активного реле в радиусе связи. Сначала восстановите ближний участок сети.",
	"not_discovered": "Район в тумане. Запитайте ближайшее реле, чтобы открыть соседние берега.",
	"unknown_region": "Выберите открытый район на карте.",
	"unknown_relay": "Сначала постройте реле в этом районе.",
	"unknown_consumer": "Сначала постройте выбранное реле или станцию.",
	"invalid_power": "Запрос питания должен быть в пределах, указанных в поле.",
	"invalid_priority": "Приоритет должен быть целым числом в пределах поля.",
	"invalid_command": "Параметры действия недопустимы. Выберите район или потребителя заново.",
	"station_full": "На станции одно место, включая назначение после возвращения. Сначала освободите его.",
	"invalid_mode": "Выберите ровный режим или форсаж насоса.",
	"unknown_generator": "Сначала постройте генератор.",
	"unknown_boost_target": "Выберите построенный порт или кварцевый район.",
	"quartz_locked": "Нужны порт, насос и суммарный выпуск по 8 сплава и масла.",
	"insufficient_quartz": "Не хватает кварца. Выплата происходит только после раскола.",
}
const NETWORK_REASONS: Dictionary = {
	"working": "Работает — питание выделено полностью.",
	"no_power": "Нет питания. Запрос должен быть не ниже минимума и целиком помещаться в остаток. Уменьшите запрос или повысьте приоритет; сначала запитайте родительские реле.",
	"disconnected": "Нет связи с кораблём. Включите и запитайте промежуточные реле на карте; приоритет дочернего узла не заменяет связь.",
	"manual_off": "Выключено вручную. Включите потребителя переключателем выше.",
	"no_worker": "Нет рабочего. Назначьте работника на станцию.",
	"not_built": "Объект не построен. Цена и действие доступны во вкладке района.",
	"not_discovered": "Неизвестный берег. Запитайте ближайшее реле, чтобы открыть район.",
	"cooling": "Автоохлаждение — добычи нет; остывает даже без рабочего и питания.",
	"no_oil": "Не хватает масла на топливо. Аварийное питание корабля сохраняется.",
	"starting": "Ожидает следующего такта и резервирования топлива.",
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
var oil_view: Control
var quartz_view: Control
var _quartz_button: Button
var _build_quartz_button: Button
var _quartz_select: OptionButton
var _quartz_lens: Button
var _quartz_requirements: Label
var _quartz_status: Label
var _quartz_facts: Label
var _selected_quartz := ""
var _oil_button: Button
var _build_oil_button: Button
var _oil_steady: Button
var _oil_overdrive: Button
var _oil_status: Label
var _oil_modes: Label
var _oil_forecast: Label
var _build_generator: Button
var _generator_enabled: CheckButton
var _generator_status: Label
var _oil_boost_enabled: CheckButton
var _oil_boost_target: OptionButton
var _oil_boost_status: Label
var _oil_boost_preview: Label
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
var _aim_button: Button
var _beam_select: OptionButton
var _beam_apply: Button
var _beam_status: Label
var _beam_preview: Label
var _beam_caption: Label
var _beam_preview_target := ""

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
	resources = _wrapped_label()
	resources.add_theme_font_size_override("font_size", 17)
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
	_port_button = _button("Порт", "ShowPort", show_port)
	navigation.add_child(_port_button)
	_oil_button = _button("Насос", "ShowOil", show_oil)
	navigation.add_child(_oil_button)
	_quartz_button = _button("Кварц", "ShowQuartz", show_quartz)
	navigation.add_child(_quartz_button)
	_aim_button = _button("Луч [Enter]", "AimBeam", func() -> void: dispatch_command({"type": "beam", "target": _selected_region}))
	navigation.add_child(_aim_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	navigation.add_child(_button("−", "ZoomOut", func() -> void: map_view.change_zoom(1.0 / 1.2)))
	navigation.add_child(_button("+", "ZoomIn", func() -> void: map_view.change_zoom(1.2)))
	navigation.add_child(_button("Сброс", "ResetMap", func() -> void: map_view.reset_view()))
	_beam_caption = _label("", 15)
	_beam_caption.name = "BeamCaption"
	_beam_caption.add_theme_color_override("font_color", Color("f5cb7d"))
	chart.add_child(_beam_caption)
	var viewport := Control.new()
	viewport.custom_minimum_size = Vector2(360, 260)
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.add_child(viewport)
	map_view = MapView.new()
	map_view.name = "MapView"
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(map_view)
	map_view.region_selected.connect(select_region)
	map_view.beam_requested.connect(func(region: String) -> void: dispatch_command({"type": "beam", "target": region}))
	harbor = PortView.new()
	harbor.name = "PortView"
	harbor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(harbor)
	harbor.hide()
	oil_view = OilView.new()
	oil_view.name = "OilView"
	oil_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(oil_view)
	oil_view.hide()
	quartz_view = QuartzView.new()
	quartz_view.name = "QuartzView"
	quartz_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(quartz_view)
	quartz_view.hide()
	var legend := _wrapped_label()
	legend.add_theme_font_size_override("font_size", 13)
	legend.text = "Щелчок / ← → — район · ПКМ / Enter / «Луч сюда» — направить луч\nКолесо / + − — масштаб · перетаскивание / WASD — сдвиг · Home — сброс.\nЗолотой сектор — усиление; зелёные линии — питание. Луч не заменяет реле."
	chart.add_child(legend)
	_sidebar_tabs = TabContainer.new()
	_sidebar_tabs.name = "SidebarTabs"
	_sidebar_tabs.custom_minimum_size.x = 400
	_sidebar_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_sidebar_tabs)
	var district := _scroll_tab("Район")
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
	power_help.text = "Выше приоритет — раньше питание. Запрос выделяется целиком. Реле и станция независимы: сначала нужна действующая цепь от корабля. Измените поля и нажмите «Применить»."
	_network_container.add_child(power_help)
	var beam_panel := _scroll_tab("Луч")
	_beam_status = _wrapped_label()
	_beam_status.name = "BeamStatus"
	beam_panel.add_child(_beam_status)
	_beam_select = OptionButton.new()
	_beam_select.name = "BeamSelect"
	_beam_select.item_selected.connect(func(index: int) -> void:
		_beam_preview_target = str(_beam_select.get_item_metadata(index))
		_refresh())
	beam_panel.add_child(_beam_select)
	_beam_preview = _wrapped_label()
	_beam_preview.name = "BeamPreview"
	beam_panel.add_child(_beam_preview)
	_beam_apply = _button("Направить луч", "ApplyBeam", func() -> void: dispatch_command({"type": "beam", "target": _beam_preview_target}))
	beam_panel.add_child(_beam_apply)
	var oil_panel := _scroll_tab("Масло")
	oil_panel.add_child(_label("Насосная станция", 20))
	_build_oil_button = _button("", "BuildOil", func() -> void: dispatch_command({"type": "build", "kind": "oil"}))
	oil_panel.add_child(_build_oil_button)
	_oil_status = _wrapped_label()
	_oil_status.name = "OilStatus"
	oil_panel.add_child(_oil_status)
	_oil_steady = _button("Ровный режим", "OilSteady", func() -> void: dispatch_command({"type": "mode", "station": "oil", "mode": "steady"}))
	oil_panel.add_child(_oil_steady)
	_oil_overdrive = _button("Форсаж", "OilOverdrive", func() -> void: dispatch_command({"type": "mode", "station": "oil", "mode": "overdrive"}))
	oil_panel.add_child(_oil_overdrive)
	_oil_modes = _wrapped_label()
	_oil_modes.name = "OilModes"
	oil_panel.add_child(_oil_modes)
	_oil_forecast = _wrapped_label()
	_oil_forecast.name = "OilForecast"
	oil_panel.add_child(_oil_forecast)
	oil_panel.add_child(HSeparator.new())
	oil_panel.add_child(_label("Генератор на корабле", 19))
	_build_generator = _button("", "BuildGenerator", func() -> void: dispatch_command({"type": "build", "kind": "generator"}))
	oil_panel.add_child(_build_generator)
	_generator_enabled = CheckButton.new()
	_generator_enabled.name = "GeneratorEnabled"
	_generator_enabled.text = "Генератор включён"
	_generator_enabled.toggled.connect(func(value: bool) -> void: dispatch_command({"type": "generator", "enabled": value}))
	oil_panel.add_child(_generator_enabled)
	_generator_status = _wrapped_label()
	_generator_status.name = "GeneratorStatus"
	oil_panel.add_child(_generator_status)
	oil_panel.add_child(HSeparator.new())
	oil_panel.add_child(_label("Масляный форсаж района", 19))
	_oil_boost_target = OptionButton.new()
	_oil_boost_target.name = "OilBoostTarget"
	_oil_boost_target.item_selected.connect(func(index: int) -> void:
		dispatch_command({"type": "oil_boost", "target": str(_oil_boost_target.get_item_metadata(index)), "enabled": session.snapshot().derived.oil_boost.enabled}))
	oil_panel.add_child(_oil_boost_target)
	_oil_boost_enabled = CheckButton.new()
	_oil_boost_enabled.name = "OilBoostEnabled"
	_oil_boost_enabled.text = "Ускорять выбранный район маслом"
	_oil_boost_enabled.toggled.connect(func(value: bool) -> void:
		var target := str(_oil_boost_target.get_selected_metadata())
		dispatch_command({"type": "oil_boost", "target": target, "enabled": value}))
	oil_panel.add_child(_oil_boost_enabled)
	_oil_boost_status = _wrapped_label()
	_oil_boost_status.name = "OilBoostStatus"
	oil_panel.add_child(_oil_boost_status)
	_oil_boost_preview = _wrapped_label()
	_oil_boost_preview.name = "OilBoostPreview"
	oil_panel.add_child(_oil_boost_preview)
	var quartz_panel := _scroll_tab("Кварц")
	quartz_panel.add_child(_label("Кварцевые буры", 20))
	_quartz_requirements = _wrapped_label()
	_quartz_requirements.name = "QuartzRequirements"
	quartz_panel.add_child(_quartz_requirements)
	_build_quartz_button = _button("", "BuildQuartz", func() -> void: dispatch_command({"type": "build", "kind": "quartz"}))
	quartz_panel.add_child(_build_quartz_button)
	_quartz_select = OptionButton.new()
	_quartz_select.name = "QuartzSelect"
	_quartz_select.item_selected.connect(func(index: int) -> void:
		_selected_quartz = str(_quartz_select.get_item_metadata(index))
		_refresh())
	quartz_panel.add_child(_quartz_select)
	_quartz_status = _wrapped_label()
	_quartz_status.name = "QuartzStatus"
	quartz_panel.add_child(_quartz_status)
	_quartz_facts = _wrapped_label()
	_quartz_facts.name = "QuartzFacts"
	quartz_panel.add_child(_quartz_facts)
	_quartz_lens = _button("", "QuartzLens", func() -> void: dispatch_command({"type": "upgrade", "id": "quartz_lens", "station": _selected_quartz}))
	quartz_panel.add_child(_quartz_lens)
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
	status.text = "Начните с порта или масляного насоса и назначьте работника. Ручной сбор доступен без топлива и работников."
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
	if session.snapshot().derived.beam.targets.has(region):
		_beam_preview_target = region
	if _detail_open:
		if region == "quartz":
			_sidebar_tabs.current_tab = 4
		elif region not in ["port", "oil"]:
			_detail_open = false
	_refresh()
	return true

func show_port() -> void:
	_selected_region = "port"
	_beam_preview_target = "port"
	map_view.select_region("port")
	_detail_open = true
	map_view.hide()
	oil_view.hide()
	harbor.show()
	_refresh()

func show_oil() -> void:
	if not map_view.select_region("oil"):
		return
	_selected_region = "oil"
	_beam_preview_target = "oil"
	_detail_open = true
	map_view.hide()
	harbor.hide()
	oil_view.show()
	_sidebar_tabs.current_tab = 3
	_refresh()

func show_quartz() -> void:
	_selected_region = "quartz"
	map_view.select_region("quartz")
	if session.snapshot().derived.beam.targets.has("quartz"):
		_beam_preview_target = "quartz"
	_detail_open = true
	_sidebar_tabs.current_tab = 4
	_refresh()

func show_map() -> void:
	_detail_open = false
	harbor.hide()
	oil_view.hide()
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
			"upgrade":
				status.text = "Линза установлена для следующего заряда. Текущая работа и охлаждение сохранены." if command.get("id", "") == "quartz_lens" else "Трюм увеличен. Уже погруженный груз не меняется; сравните отдачу маршрутов."
			"buy_worker": status.text = "Новый сборщик свободен — выберите ему маршрут ниже."
			"build":
				match command.get("kind", ""):
					"oil": status.text = "Насос построен. Назначьте одного работника; режим и топливо доступны во вкладке «Масло»."
					"generator": status.text = "Генератор построен и выключен. Включение резервирует масло на следующем такте."
					"quartz":
						var ids: Array = session.snapshot().derived.quartz.station_ids
						_selected_quartz = str(ids.back())
						_sidebar_tabs.current_tab = 4
						status.text = "Бур построен. Выберите его у работника ниже; питание — во вкладке «Питание»."
					_: status.text = "Порт и его реле построены. Назначьте сборщика; проверьте вкладку «Питание»."
			"build_relay": status.text = "Реле построено. Действующая сеть открывает соседние берега."
			"relay": status.text = "Реле включено. Проверьте связь и питание ветки." if command.enabled else "Реле выключено. Зависимые ветки остановлены, груз и фазы сохранены."
			"station_enabled": status.text = "Станция включена. Проверьте питание и назначения." if command.enabled else "Станция выключена. Реле продолжает независимо передавать связь."
			"power": status.text = "Запрос и приоритет применены. Распределение сети пересчитано; проверьте фактическую мощность и причину остановки."
			"beam": status.text = "Направление луча изменено. Сеть продолжает работать; груз и выполненная работа сохранены."
			"mode": status.text = "Режим выбран для следующего цикла. Текущая партия, фаза и нагрев не сбрасываются."
			"generator": status.text = "Генератор включён: топливо и мощность проверяются на следующем такте." if command.enabled else "Генератор выключен. Аварийное питание корабля остаётся."
			"oil_boost": status.text = "Масляный форсаж → %s. Ускорение начнётся после оплаты следующего такта; генератор получает топливо первым." % _boost_target_name(str(command.target)) if command.enabled and not str(command.target).is_empty() else "Масляный форсаж выключен."
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
	resources.text = "Сплав  %.0f     Масло  %.1f     Кварц  %.0f     Выпущено сплава  %.0f     Работников  %d     Питание  %.2f / %.2f" % [state.run.wallet.alloy, state.run.wallet.oil, state.run.wallet.quartz, state.run.lifetime_produced.alloy, state.run.workers.size(), details.power_used, details.power_capacity]
	_pause_button.text = "Продолжить [Пробел]" if paused else "Пауза [Пробел]"
	_map_button.disabled = not _detail_open
	_port_button.disabled = _detail_open and _selected_region == "port"
	_oil_button.disabled = not details.regions.oil.discovered or (_detail_open and _selected_region == "oil")
	_quartz_button.disabled = _detail_open and _selected_region == "quartz"
	_quartz_button.tooltip_text = "Буры и условия открытия кварца."
	map_view.visible = not _detail_open
	harbor.visible = _detail_open and _selected_region == "port"
	oil_view.visible = _detail_open and _selected_region == "oil"
	quartz_view.visible = _detail_open and _selected_region == "quartz"
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
		route_lines.append("%s\n%.0f груза / %.1f с = %.2f/с\nС увеличенным трюмом: %.2f/с" % [route.name, route.cargo, route.cycle_seconds, route.rate, upgraded_route.rate])
	_route_label.text = "\n\n".join(route_lines)
	for id: String in state.run.workers:
		if not _worker_rows.has(id):
			_create_worker_row(id)
		var row: Dictionary = _worker_rows[id]
		var worker: Dictionary = state.run.workers[id]
		var visual: Dictionary = details.workers[id]
		var phase_name: String = str(PHASE_NAMES.get(worker.phase, worker.phase))
		var assignment_text := ""
		if worker.assignment == "oil":
			assignment_text = " · насос: " + str(OIL_PHASE_NAMES.get(details.stations.oil.phase, details.stations.oil.phase))
		elif worker.assignment == "port":
			assignment_text = " · " + str(details.routes[worker.target].name)
		elif details.quartz.station_ids.has(worker.assignment):
			var drill: Dictionary = details.stations[worker.assignment]
			assignment_text = " · %s: %s" % [_station_name(worker.assignment), QUARTZ_PHASE_NAMES.get(drill.phase, drill.phase)]
		var queue_text := ""
		if worker.recall_pending:
			if worker.queued_assignment == "oil":
				queue_text = " → насос после доставки"
			elif worker.queued_assignment == "port":
				queue_text = " → " + str(details.routes[worker.queued_target].name) + " после доставки"
			elif details.quartz.station_ids.has(worker.queued_assignment):
				queue_text = " → %s после доставки" % _station_name(worker.queued_assignment)
			else:
				queue_text = " → свободен после возврата"
		row.summary.text = "%s · %s%s · груз %.0f / %.0f%s" % [id.to_upper(), phase_name, assignment_text, worker.cargo, visual.capacity, queue_text]
		row.progress.value = visual.progress * 100.0 if worker.phase != "idle" else 0.0
		row.near.disabled = paused or (worker.assignment == "port" and worker.target == "near" and not worker.recall_pending) or not built
		row.far.disabled = paused or (worker.assignment == "port" and worker.target == "far" and not worker.recall_pending) or not built
		var oil: Dictionary = details.stations.oil
		var oil_reserved: bool = (not str(oil.assigned_worker).is_empty() and oil.assigned_worker != id) or (not str(oil.pending_worker).is_empty() and oil.pending_worker != id)
		row.oil.disabled = paused or not oil.built or oil_reserved or worker.assignment == "oil" or worker.queued_assignment == "oil"
		row.oil.tooltip_text = "Насос: одно место. Назначение в пути начнётся после доставки груза." if not oil_reserved else "Место у насоса занято или зарезервировано другим работником."
		var preferred_drill: String = str(row.drill_target.get_selected_metadata()) if row.drill_target.selected >= 0 else str(worker.assignment)
		var drill_id := _sync_drill_select(row.drill_target, details.quartz.station_ids, preferred_drill)
		row.drill_target.disabled = details.quartz.station_ids.is_empty()
		var drill_reason := ""
		if paused:
			drill_reason = "Игра на паузе."
		elif drill_id.is_empty():
			drill_reason = "Сначала постройте бур во вкладке «Кварц»."
		elif worker.assignment == drill_id or worker.queued_assignment == drill_id:
			drill_reason = "Этот бур уже назначен или ожидает работника после доставки."
		else:
			var target_drill: Dictionary = details.stations[drill_id]
			if (not str(target_drill.assigned_worker).is_empty() and target_drill.assigned_worker != id) or (not str(target_drill.pending_worker).is_empty() and target_drill.pending_worker != id):
				drill_reason = "Место занято или зарезервировано другим работником."
		row.drill.disabled = not drill_reason.is_empty()
		row.drill.tooltip_text = drill_reason if not drill_reason.is_empty() else "Одно место. Сборщик в пути сначала доставит груз; место у бура будет зарезервировано."
		row.drill_target.tooltip_text = "Выберите конкретный бур для этого работника." if not drill_id.is_empty() else "Нет построенных буров."
		row.recall.disabled = paused or worker.assignment.is_empty() or (worker.recall_pending and worker.queued_assignment.is_empty())
	map_view.present(state)
	map_view.select_region(_selected_region)
	_refresh_region(details)
	_refresh_power(details)
	_refresh_beam(details)
	_refresh_oil(state)
	_refresh_quartz(state)
	harbor.present(state)
	oil_view.present(state)
	quartz_view.present(state, _selected_quartz)

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
	var district_help := "Сеть передаёт связь от корабля через активные реле."
	if _selected_region == "oil":
		district_help = "Насос, режимы и топливо — вкладка «Масло». Назначение рабочего — кнопка «Насос» ниже."
	elif _selected_region == "quartz":
		district_help = "Буры, условия открытия и линзы — вкладка «Кварц». Работник выбирает конкретный бур ниже."
	_region_label.text = "%s · %s\n%s\nРадиус связи: %.0f. %s" % [region.name, access, str(NETWORK_REASONS.get(region.reason, region.reason)), details.range, district_help]
	_relay_button.text = "Реле построено · вкладка «Питание»" if region.built else "Построить реле  ·  %.0f сплава" % details.prices.relays[_selected_region].alloy
	_relay_button.disabled = paused or region.built or not region.unlocked or not region.reachable
	if not region.built and not region.reachable:
		_region_label.text += "\nСначала включите и запитайте соседнее реле: район вне действующей сети."

func _refresh_beam(details: Dictionary) -> void:
	var beam: Dictionary = details.beam
	_beam_caption.text = "Главный луч: без усиления" if str(beam.target).is_empty() else "Главный луч → " + str(details.regions[beam.target].name)
	_aim_button.disabled = paused or not beam.targets.has(_selected_region)
	if _beam_select.item_count != beam.targets.size() + 1:
		_beam_select.clear()
		_beam_select.add_item("Без усиления")
		_beam_select.set_item_metadata(0, "")
		for region: String in beam.targets:
			_beam_select.add_item(str(details.regions[region].name))
			_beam_select.set_item_metadata(_beam_select.item_count - 1, region)
	var selected_index := 0
	for index in range(_beam_select.item_count):
		if _beam_select.get_item_metadata(index) == _beam_preview_target:
			selected_index = index
	_beam_select.select(selected_index)
	_beam_select.disabled = paused
	_beam_apply.disabled = paused or _beam_preview_target == beam.target
	var target_name: String = "без усиления" if str(beam.target).is_empty() else str(details.regions[beam.target].name)
	var effect: String = "Главный луч не усиливает производство."
	if beam.target == "port":
		effect = "Луч: погрузка ×%.1f до масляного форсажа; дорога и груз не меняются. Итоговые времена с топливом — ниже." % beam.port_loading_speed
		if not beam.active:
			effect += "\nНе действует: " + str(NETWORK_REASONS.get(details.stations.port.reason, details.stations.port.reason))
	elif beam.target == "oil":
		effect = "Набор давления ×%.1f. Откачка, объём партии и нагрев не меняются." % beam.oil_pressure_speed
		if not beam.active:
			effect += "\nНе действует: " + str(NETWORK_REASONS.get(details.stations.oil.reason, details.stations.oil.reason))
	elif beam.target == "quartz":
		effect = "Луч ускоряет только заряд бура; раскол, охлаждение и выплата не меняются."
		if details.quartz.station_ids.is_empty():
			effect += "\nСначала постройте бур во вкладке «Кварц»."
		elif not beam.active:
			effect += "\nНет работающих буров: проверьте питание и назначения."
	_beam_status.text = "Сейчас: %s\n%s\nСлужебный резерв луча %.2f уже учтён до бюджета станций %.2f; переключение бесплатно." % [target_name, effect, beam.reserved_power, details.power_capacity]
	var preview_lit: bool = _beam_preview_target == "port"
	var lines: PackedStringArray = ["Порт после направления луча (с оплаченным масляным форсажем):"]
	for route: String in beam.port_routes:
		var forecast: Dictionary = beam.port_routes[route].lit if preview_lit else beam.port_routes[route].base
		lines.append("%s: погрузка %.1f с, цикл %.1f с, %.2f сплава/с" % [forecast.name, forecast.loading_seconds, forecast.cycle_seconds, forecast.rate])
	var oil_rates: Dictionary = beam.oil_rates.lit if _beam_preview_target == "oil" else beam.oil_rates.base
	lines.append("Насос: ровный %.2f · форсаж %.2f масла/с в среднем, включая охлаждение." % [oil_rates.steady, oil_rates.overdrive])
	if _beam_preview_target == "oil":
		lines.append("Луч ускоряет только набор давления ×%.1f." % beam.oil_pressure_speed)
	for id: String in beam.quartz_drills:
		var forecast: Dictionary = beam.quartz_drills[id].lit if _beam_preview_target == "quartz" else beam.quartz_drills[id].base
		lines.append("%s · следующий заряд %.1f с, цикл %.1f с, %.2f кварца/с.\n%s" % [_station_name(id), forecast.charge_seconds, forecast.cycle_seconds, forecast.rate, _drill_forecast_context(details, id)])
	lines.append("Прогноз для следующего заряда и установленной линзы, при операторе и питании. Луч не заменяет сеть; форсаж насоса и масляный форсаж района независимы.")
	_beam_preview.text = "\n\n".join(lines)

func _refresh_oil(state: Dictionary) -> void:
	var details: Dictionary = state.derived
	var oil: Dictionary = details.stations.oil
	_build_oil_button.text = "Насос построен" if oil.built else "Построить насос · %.0f сплава" % details.prices.oil.alloy
	_build_oil_button.disabled = paused or oil.built
	_build_oil_button.tooltip_text = "Цена включает реле. Уже оплаченное реле повторно не оплачивается."
	var staff := "Работник: нет"
	if not str(oil.assigned_worker).is_empty():
		staff = "Работник: " + str(oil.assigned_worker).to_upper()
	if not str(oil.pending_worker).is_empty():
		staff += "\nОжидается " + str(oil.pending_worker).to_upper() + " после доставки портового груза."
	_oil_status.text = str(NETWORK_REASONS.get(oil.reason, oil.reason)) + "\n" + staff
	if oil.built:
		_oil_status.text += "\n%s · %.0f%% фазы · длительность %.1f с\nНагрев %.1f / %.0f · давление %.0f%%" % [str(OIL_PHASE_NAMES.get(oil.phase, oil.phase)).capitalize(), oil.progress * 100.0, oil.phase_seconds, oil.heat, oil.heat_limit, oil.pressure * 100.0]
		if oil.phase == "cooling":
			_oil_status.text += "\nОстывание: осталось %.1f с без паузы; сейчас добычи нет." % oil.cooling_seconds
		else:
			_oil_status.text += "\nПартия: %.0f масла по завершении откачки." % oil.next_output
	_oil_status.add_theme_color_override("font_color", Color("85c7ae") if oil.active else Color("f5cb7d"))
	_oil_steady.text = "Ровный · среднее %.2f масла/с" % oil.steady_rate
	_oil_overdrive.text = "Форсаж · среднее %.2f масла/с" % oil.overdrive_rate
	_oil_steady.disabled = paused or not oil.built or oil.mode == "steady"
	_oil_overdrive.disabled = paused or not oil.built or oil.mode == "overdrive"
	var cycle_mode := "не начат" if str(oil.cycle_mode).is_empty() else str(OIL_MODE_NAMES.get(oil.cycle_mode, oil.cycle_mode))
	_oil_modes.text = "Текущий цикл: %s. Следующий: %s.\nСмена режима не меняет партию и не сбрасывает нагрев.\nДавление без луча: %.1f с.\nРовный: %.0f масла, откачка %.1f с; охлаждает на %.0f/с.\nФорсаж: %.0f масла, откачка %.1f с; +%.0f тепла за партию. При %.0f — автоохлаждение, %.0f/с без питания и рабочего. Пауза останавливает всё." % [
		cycle_mode, str(OIL_MODE_NAMES.get(oil.mode, oil.mode)),
		ContentCatalog.OIL_PRESSURE_SECONDS,
		ContentCatalog.OIL_BATCH, ContentCatalog.OIL_PUMP_SECONDS, ContentCatalog.OIL_STEADY_COOLING_RATE,
		ContentCatalog.OIL_OVERDRIVE_BATCH, ContentCatalog.OIL_OVERDRIVE_PUMP_SECONDS,
		ContentCatalog.OIL_HEAT_PER_BATCH, ContentCatalog.OIL_HEAT_LIMIT, ContentCatalog.OIL_COOLING_RATE,
	]
	var fuel_time := "Нет расхода — запас не убывает от топлива."
	if details.oil_seconds >= 0.0:
		fuel_time = "Топлива без новой добычи: %.1f с (не срок истощения с учётом дохода)." % details.oil_seconds
	_oil_forecast.text = "Запас: %.1f масла\nДобыча в среднем: %.2f/с\nОплаченный расход: %.2f/с · баланс: %+.2f/с\n%s\nПрогноз учитывает автоохлаждение; выплата — только за завершённую партию." % [state.run.wallet.oil, details.oil_production, details.oil_consumption, details.oil_net, fuel_time]
	var generator: Dictionary = details.generator
	_build_generator.text = "Генератор построен" if generator.built else "Построить генератор · %.0f сплава" % details.prices.generator.alloy
	_build_generator.disabled = paused or generator.built
	_generator_enabled.set_pressed_no_signal(generator.enabled)
	_generator_enabled.disabled = paused or not generator.built
	_generator_status.text = "%s\nДополнительная мощность: %.2f из +%.2f\nРасход сейчас %.2f, при работе %.2f масла/с.\nВключение запрашивает топливо на следующем такте. Без масла остаётся аварийное питание; включённый генератор возобновит работу при поступлении топлива." % [str(NETWORK_REASONS.get(generator.reason, generator.reason)), generator.capacity, generator.additional_capacity, generator.consumption, generator.rated_consumption]
	_generator_status.add_theme_color_override("font_color", Color("85c7ae") if generator.active else Color("f5cb7d"))
	var boost: Dictionary = details.oil_boost
	var targets: Array = [""]
	targets.append_array(boost.targets)
	var rebuild_targets := _oil_boost_target.item_count != targets.size()
	if not rebuild_targets:
		for index in range(targets.size()):
			if _oil_boost_target.get_item_metadata(index) != targets[index]:
				rebuild_targets = true
				break
	if rebuild_targets:
		_oil_boost_target.clear()
		for target: String in targets:
			_oil_boost_target.add_item(_boost_target_name(target))
			_oil_boost_target.set_item_metadata(_oil_boost_target.item_count - 1, target)
	for index in range(targets.size()):
		var target: String = str(targets[index])
		var unavailable: bool = (target == "port" and not details.stations.port.built) or (target == "quartz" and details.quartz.station_ids.is_empty())
		_oil_boost_target.set_item_disabled(index, unavailable)
	_oil_boost_target.select(targets.find(boost.target))
	_oil_boost_target.disabled = paused or boost.targets.is_empty()
	_oil_boost_target.tooltip_text = "Один район за раз. Смена цели сохранит переключатель, но ускорение ждёт следующей оплаты. «Без форсажа» отключает его."
	_oil_boost_enabled.set_pressed_no_signal(boost.enabled)
	var target_built: bool = (boost.target == "port" and details.stations.port.built) or (boost.target == "quartz" and not details.quartz.station_ids.is_empty())
	_oil_boost_enabled.disabled = paused or not target_built or not boost.targets.has(boost.target)
	_oil_boost_enabled.tooltip_text = "Выберите построенный район выше." if not target_built else "Топливо оплачивает активный цикл района, не только ускоряемую фазу."
	var boost_reason := "Сначала постройте выбранный район или выберите другой." if not target_built else str(NETWORK_REASONS.get(boost.reason, boost.reason))
	var boost_effect := "Ускоряется заряд; топливо расходуется во всём активном цикле буров, включая охлаждение." if boost.target == "quartz" else "Ускоряется погрузка; дорога и груз не меняются."
	_oil_boost_status.text = "Цель: %s · %s\n+%.0f%% к скорости. %s\nРасход сейчас %.2f, при работе %.2f масла/с. Генератор получает топливо первым. Без запитанного рабочего места расхода нет; это не форсаж насоса." % [_boost_target_name(str(boost.target)), boost_reason, boost.bonus * 100.0, boost_effect, boost.consumption, boost.rated_consumption]
	_oil_boost_status.add_theme_color_override("font_color", Color("85c7ae") if boost.active else Color("f5cb7d"))
	var routes: PackedStringArray = ["Порт: без / с масляным форсажем (текущий луч учтён):"]
	for id: String in boost.port_routes:
		var off: Dictionary = boost.port_routes[id].off
		var on: Dictionary = boost.port_routes[id].on
		routes.append("%s\nПогрузка %.1f / %.1f с · цикл %.1f / %.1f с\nСредний выпуск %.2f / %.2f сплава/с" % [off.name, off.loading_seconds, on.loading_seconds, off.cycle_seconds, on.cycle_seconds, off.rate, on.rate])
	for id: String in boost.quartz_drills:
		var off: Dictionary = boost.quartz_drills[id].off
		var on: Dictionary = boost.quartz_drills[id].on
		routes.append("%s · без / с оплатой форсажа кварца:\nЗаряд %.1f / %.1f с · цикл %.1f / %.1f с\nСреднее %.2f / %.2f кварца/с\n%s" % [_station_name(id), off.charge_seconds, on.charge_seconds, off.cycle_seconds, on.cycle_seconds, off.rate, on.rate, _drill_forecast_context(details, id)])
	routes.append("Условия сравнения: оператор, следующий заряд с установленной линзой, текущий луч. Одновременно оплачивается только выбранный район.")
	_oil_boost_preview.text = "\n\n".join(routes)

func _refresh_power(details: Dictionary) -> void:
	_power_summary.text = "Питание станций: %.2f / %.2f\nРадиус реле: %.0f. Генератор и топливо — вкладка «Масло». Остановленная ветка сохраняет груз и выполненную работу." % [details.power_used, details.power_capacity, details.range]
	for id: String in details.consumers:
		if not _power_rows.has(id):
			_create_power_row(id, details.power_limits)
		var row: Dictionary = _power_rows[id]
		var consumer: Dictionary = details.consumers[id]
		row.title.text = "Реле · " + str(details.regions[consumer.region].name) if consumer.kind == "relay" else _station_name(id)
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
	var summary := _wrapped_label()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(summary)
	var row := HFlowContainer.new()
	box.add_child(row)
	var near := _button("Ближний обломок", "Near", func() -> void: dispatch_command({"type": "assign", "worker": id, "station": "port", "target": "near"}))
	row.add_child(near)
	var far := _button("Дальнее судно", "Far", func() -> void: dispatch_command({"type": "assign", "worker": id, "station": "port", "target": "far"}))
	row.add_child(far)
	var oil := _button("Насос", "Oil", func() -> void: dispatch_command({"type": "assign", "worker": id, "station": "oil"}))
	row.add_child(oil)
	var drill_target := OptionButton.new()
	drill_target.name = "DrillTarget"
	drill_target.custom_minimum_size.x = 110
	drill_target.item_selected.connect(func(_index: int) -> void: _refresh())
	row.add_child(drill_target)
	var drill := _button("На бур", "Drill", func() -> void:
		dispatch_command({"type": "assign", "worker": id, "station": str(drill_target.get_selected_metadata())}))
	row.add_child(drill)
	var recall := _button("Вернуть", "Recall", func() -> void: dispatch_command({"type": "recall", "worker": id}))
	row.add_child(recall)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 5
	progress.show_percentage = false
	box.add_child(progress)
	_worker_rows[id] = {"summary": summary, "progress": progress, "near": near, "far": far, "oil": oil, "drill_target": drill_target, "drill": drill, "recall": recall}

func _refresh_quartz(state: Dictionary) -> void:
	var details: Dictionary = state.derived
	var quartz: Dictionary = details.quartz
	var region: Dictionary = details.regions.quartz
	_quartz_requirements.text = "Для добычи: порт %s · насос %s\nВсего выпущено: сплав %.0f / %.0f · масло %.1f / %.0f\n%s" % [
		"есть" if quartz.required_stations.port else "нужен",
		"есть" if quartz.required_stations.oil else "нужен",
		quartz.requirements.alloy.produced, quartz.requirements.alloy.required,
		quartz.requirements.oil.produced, quartz.requirements.oil.required,
		"Производство открыто; связь и питание нужны отдельно." if quartz.unlocked else REASONS.quartz_locked,
	]
	var build_reason := ""
	if paused:
		build_reason = "Игра на паузе."
	elif not quartz.unlocked:
		build_reason = REASONS.quartz_locked
	elif not region.discovered:
		build_reason = REASONS.not_discovered
	elif not region.reachable:
		build_reason = REASONS.disconnected
	elif state.run.wallet.alloy < details.prices.quartz.alloy:
		build_reason = REASONS.insufficient_alloy
	_build_quartz_button.text = "Построить %s · %.0f сплава" % [_station_name(str(quartz.next_id)).to_lower(), details.prices.quartz.alloy]
	_build_quartz_button.disabled = not build_reason.is_empty()
	_build_quartz_button.tooltip_text = build_reason if not build_reason.is_empty() else "Цена включает отсутствующее реле. У каждого бура одно рабочее место."
	if not build_reason.is_empty() and quartz.unlocked:
		_quartz_requirements.text += "\n" + build_reason
	_selected_quartz = _sync_drill_select(_quartz_select, quartz.station_ids, _selected_quartz)
	_quartz_select.disabled = quartz.station_ids.is_empty()
	_quartz_select.tooltip_text = "Выберите бур для схемы и линзы." if not quartz.station_ids.is_empty() else "Сначала постройте бур."
	if _selected_quartz.is_empty():
		_quartz_status.text = "Буры не построены. После постройки назначьте работника на конкретный бур ниже."
		_quartz_facts.text = "Заряд → раскол → охлаждение. Выплата только при завершении раскола; каждый этап требует рабочего и питания."
		_quartz_lens.text = "Линза · %.0f кварца" % details.prices.quartz_lens.quartz
		_quartz_lens.disabled = true
		_quartz_lens.tooltip_text = "Сначала постройте и выберите бур."
		return
	var drill: Dictionary = details.stations[_selected_quartz]
	var reason: String = str(NETWORK_REASONS.get(drill.reason, drill.reason))
	if drill.reason == "cooling":
		reason = "Охлаждение — добычи нет; нужны рабочий и питание."
	if paused:
		reason = "Пауза — фаза сохранена."
	var staff := "Работник: нет" if str(drill.assigned_worker).is_empty() else "Работник: " + str(drill.assigned_worker).to_upper()
	if not str(drill.pending_worker).is_empty():
		staff += " · ожидается " + str(drill.pending_worker).to_upper() + " после доставки"
	_quartz_status.text = "%s · %s\n%s\nФакт питания %.2f · %s, %.0f%% · осталось %.1f с" % [_station_name(_selected_quartz), reason, staff, drill.power, QUARTZ_PHASE_NAMES.get(drill.phase, drill.phase), drill.progress * 100.0, drill.remaining_seconds]
	_quartz_status.add_theme_color_override("font_color", Color("85c7ae") if drill.active and not paused else Color("f5cb7d"))
	var cycle_lens := "ещё не начат" if drill.cycle_lens_level < 0 else "линза %d" % drill.cycle_lens_level
	_quartz_facts.text = "Линза установлена: %d · текущий цикл: %s.\nДлительность заряда: текущий %.1f с, следующий %.1f с.\nРаскол %.1f с → +%.0f кварца; охлаждение %.1f с без выплаты.\nСредний выпуск при работе %.2f кварца/с. Все этапы требуют рабочего и питания; остановка сохраняет работу.\n%s" % [drill.lens_level, cycle_lens, drill.charge_seconds, drill.next_charge_seconds, drill.fracture_seconds, drill.next_output, drill.cooling_seconds, drill.rate, _drill_forecast_context(details, _selected_quartz)]
	_quartz_lens.text = "Линза установлена · следующий заряд %.1f с" % drill.next_charge_seconds if drill.lens_level > 0 else "Линза · %.0f кварца\nСледующий заряд %.1f → %.1f с" % [details.prices.quartz_lens.quartz, drill.next_charge_seconds, drill.lens_preview_seconds]
	var lens_reason := ""
	if paused:
		lens_reason = "Игра на паузе."
	elif drill.lens_level > 0:
		lens_reason = "Линза уже установлена. Начатый заряд сохраняет линзу своего цикла."
	elif state.run.wallet.quartz < details.prices.quartz_lens.quartz:
		lens_reason = REASONS.insufficient_quartz
	_quartz_lens.disabled = not lens_reason.is_empty()
	_quartz_lens.tooltip_text = lens_reason if not lens_reason.is_empty() else "Только следующий заряд. Текущая работа, раскол и охлаждение не сбрасываются."

func _sync_drill_select(selector: OptionButton, ids: Array, preferred: String) -> String:
	var rebuild := selector.item_count != ids.size()
	if not rebuild:
		for index in range(ids.size()):
			if selector.get_item_metadata(index) != ids[index]:
				rebuild = true
				break
	if rebuild:
		selector.clear()
		for id: String in ids:
			selector.add_item(_station_name(id))
			selector.set_item_metadata(selector.item_count - 1, id)
	var selected := ids.find(preferred)
	if selected < 0 and not ids.is_empty():
		selected = 0
	selector.select(selected)
	return str(ids[selected]) if selected >= 0 else ""

func _station_name(id: String) -> String:
	if id.begins_with("quartz_"):
		return "Бур " + id.trim_prefix("quartz_")
	if id == "oil":
		return "Насос"
	if id == "port":
		return "Порт"
	return id

func _boost_target_name(target: String) -> String:
	if target == "port":
		return "Порт"
	if target == "quartz":
		return "Кварцевый район"
	return "Без форсажа"

func _drill_forecast_context(details: Dictionary, id: String) -> String:
	if details.stations[id].power > 0.0:
		return "При факте питания %.2f; нужен оператор." % details.stations[id].power
	return "Теоретически при питании %.2f; сейчас нет питания и выпуска." % details.stations[id].forecast_power

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
