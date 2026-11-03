class_name GameSession
extends RefCounted

var _profile: Dictionary = {}
var _paused: bool = false
var _remainder: float = 0.0
var _network: Dictionary = {}
var _generator_active := false
var _boost_active := false
var _boost_reason := "manual_off"

func new_profile(seed_value: int) -> void:
	_profile = ProfileState.create(seed_value)
	_paused = false
	_remainder = 0.0
	_generator_active = false
	_boost_active = false
	_boost_reason = "manual_off"
	_refresh_network()

func dispatch(command: Dictionary) -> Dictionary:
	var kind: String = str(command.get("type", ""))
	if kind == "pause":
		_paused = bool(command.get("paused", not _paused))
		return _result(true)
	if _paused:
		return _result(false, "paused")
	if kind == "collect":
		var run: Dictionary = _profile.run
		if int(run.tick) - int(run.last_collect_tick) < ContentCatalog.MANUAL_COOLDOWN_TICKS:
			return _result(false, "cooldown")
		run.last_collect_tick = run.tick
		_produce("alloy", 1.0)
		_profile.revision += 1
		return _result(true)
	if kind == "beam":
		if typeof(command.get("target")) != TYPE_STRING:
			return _result(false, "invalid_command")
		var target: String = command.target
		if not target.is_empty():
			if not ContentCatalog.BEAM_TARGETS.has(target):
				return _result(false, "unknown_region")
			if not _network.regions[target].discovered:
				return _result(false, "not_discovered")
		if _profile.run.beam_target != target:
			_profile.run.beam_target = target
			_profile.revision += 1
		return _result(true)
	if kind == "station_enabled":
		var station_id: String = str(command.get("station", ""))
		if not _profile.run.stations.has(station_id):
			return _result(false, "unknown_station")
		if typeof(command.get("enabled")) != TYPE_BOOL:
			return _result(false, "invalid_command")
		_profile.run.stations[station_id].enabled = command.enabled
		_profile.revision += 1
		_refresh_network()
		return _result(true)
	if kind == "power":
		var consumer_id: String = str(command.get("station", ""))
		if not _network.consumers.has(consumer_id):
			return _result(false, "unknown_consumer")
		var request_type: int = typeof(command.get("request"))
		if request_type != TYPE_FLOAT and request_type != TYPE_INT:
			return _result(false, "invalid_power")
		var request: float = float(command.request)
		if not is_finite(request) or request < 0.0 or request > ContentCatalog.MAX_POWER_REQUEST:
			return _result(false, "invalid_power")
		if typeof(command.get("priority")) != TYPE_INT or command.priority < ContentCatalog.MIN_PRIORITY or command.priority > ContentCatalog.MAX_PRIORITY:
			return _result(false, "invalid_priority")
		var consumer: Dictionary = _network.consumers[consumer_id]
		var state: Dictionary = _profile.run.relays[consumer.region] if consumer.kind == "relay" else _profile.run.stations[consumer_id]
		state.power_request = request
		state.priority = command.priority
		_profile.revision += 1
		_refresh_network()
		return _result(true)
	if kind == "build_relay":
		var region: String = str(command.get("region", ""))
		if not ContentCatalog.RELAY_PRICES.has(region):
			return _result(false, "unknown_region")
		if _profile.run.relays.has(region):
			return _result(false, "already_built")
		if not _network.regions[region].discovered:
			return _result(false, "not_discovered")
		if not _network.regions[region].reachable:
			return _result(false, "disconnected")
		var price: float = ContentCatalog.RELAY_PRICES[region]
		if _profile.run.wallet.alloy < price:
			return _result(false, "insufficient_alloy")
		_profile.run.wallet.alloy -= price
		_profile.run.relays[region] = RunState.create_relay()
		_profile.revision += 1
		_refresh_network()
		return _result(true)
	if kind == "relay":
		var region: String = str(command.get("region", ""))
		if not _profile.run.relays.has(region):
			return _result(false, "unknown_relay")
		if typeof(command.get("enabled")) != TYPE_BOOL:
			return _result(false, "invalid_command")
		_profile.run.relays[region].enabled = command.enabled
		_profile.revision += 1
		_refresh_network()
		return _result(true)
	if kind == "upgrade" and command.get("id") == "cargo_hold":
		if not _profile.run.stations.has("port"):
			return _result(false, "unknown_station")
		if _profile.run.upgrades.get("cargo_hold", 0) >= 1:
			return _result(false, "max_level")
		if _profile.run.wallet.alloy < ContentCatalog.CARGO_HOLD_PRICE:
			return _result(false, "insufficient_alloy")
		_profile.run.wallet.alloy -= ContentCatalog.CARGO_HOLD_PRICE
		_profile.run.upgrades.cargo_hold = 1
		_profile.revision += 1
		return _result(true)
	if kind == "buy_worker":
		var workers: Dictionary = _profile.run.workers
		var price: float = ContentCatalog.worker_price(workers.size())
		if _profile.run.wallet.alloy < price:
			return _result(false, "insufficient_alloy")
		var id := "w%d" % (workers.size() + 1)
		_profile.run.wallet.alloy -= price
		workers[id] = RunState.create_worker(id)
		_profile.revision += 1
		return _result(true)
	if kind == "oil_boost":
		if typeof(command.get("enabled")) != TYPE_BOOL or typeof(command.get("target")) != TYPE_STRING:
			return _result(false, "invalid_command")
		var target: String = command.target
		if target != "port" and (command.enabled or not target.is_empty()):
			return _result(false, "unknown_boost_target")
		if command.enabled and not _profile.run.stations.has("port"):
			return _result(false, "unknown_station")
		if _profile.run.oil_boost_target != target or _profile.run.oil_boost_enabled != command.enabled:
			_profile.run.oil_boost_target = target
			_profile.run.oil_boost_enabled = command.enabled
			_profile.revision += 1
		if not command.enabled:
			_boost_active = false
		_boost_reason = "starting" if command.enabled else "manual_off"
		return _result(true)
	if kind == "build" and command.get("kind") == "generator":
		if _profile.run.generator_built:
			return _result(false, "already_built")
		if _profile.run.wallet.alloy < ContentCatalog.GENERATOR_PRICE:
			return _result(false, "insufficient_alloy")
		_profile.run.wallet.alloy -= ContentCatalog.GENERATOR_PRICE
		_profile.run.generator_built = true
		_profile.revision += 1
		return _result(true)
	if kind == "generator":
		if not _profile.run.generator_built:
			return _result(false, "unknown_generator")
		if typeof(command.get("enabled")) != TYPE_BOOL:
			return _result(false, "invalid_command")
		if _profile.run.generator_enabled != command.enabled:
			_profile.run.generator_enabled = command.enabled
			_profile.revision += 1
			if not command.enabled and _generator_active:
				_generator_active = false
				_refresh_network()
		return _result(true)
	if kind == "mode":
		if command.get("station") != "oil" or not _profile.run.stations.has("oil"):
			return _result(false, "unknown_station")
		if command.get("mode") not in ["steady", "overdrive"]:
			return _result(false, "invalid_mode")
		var station: Dictionary = _profile.run.stations.oil
		if station.mode != command.mode:
			station.mode = command.mode
			if station.phase == "pressure" and station.phase_progress <= 0.00000001:
				station.cycle_mode = ""
			_profile.revision += 1
		return _result(true)
	if kind == "build" and ContentCatalog.STATION_PRICES.has(command.get("kind")):
		var region: String = command.kind
		if _profile.run.stations.has(region):
			return _result(false, "already_built")
		var price: float = ContentCatalog.station_price(_profile.run, region)
		if _profile.run.wallet.alloy < price:
			return _result(false, "insufficient_alloy")
		if not _network.regions[region].discovered:
			return _result(false, "not_discovered")
		if not _network.regions[region].reachable:
			return _result(false, "disconnected")
		_profile.run.wallet.alloy -= price
		if not _profile.run.relays.has(region):
			_profile.run.relays[region] = RunState.create_relay()
		var station: Dictionary = {
			"id": region, "kind": region, "region": region, "enabled": true,
			"power_request": ContentCatalog.PORT_POWER if region == "port" else ContentCatalog.OIL_POWER, "priority": 0,
		}
		if region == "oil":
			station.phase = "pressure"
			station.phase_progress = 0.0
			station.mode = "steady"
			station.cycle_mode = ""
			station.heat = 0.0
		_profile.run.stations[region] = station
		_profile.revision += 1
		_refresh_network()
		return _result(true)
	if kind == "assign":
		var worker_id: String = str(command.get("worker", ""))
		var target: String = str(command.get("target", "near"))
		if not _profile.run.workers.has(worker_id):
			return _result(false, "unknown_worker")
		var station_id: String = str(command.get("station", ""))
		if not _profile.run.stations.has(station_id):
			return _result(false, "unknown_station")
		if not ContentCatalog.PORT_ROUTES.has(target):
			return _result(false, "unknown_target")
		var worker: Dictionary = _profile.run.workers[worker_id]
		if station_id == "oil":
			for other_id: String in _profile.run.workers:
				var other: Dictionary = _profile.run.workers[other_id]
				if other_id != worker_id and (other.assignment == "oil" or other.queued_assignment == "oil"):
					return _result(false, "station_full")
			if worker.assignment == "oil":
				return _result(false, "already_assigned")
		if worker.assignment == "port":
			if (not worker.recall_pending and station_id == "port" and worker.target == target) or (worker.recall_pending and worker.queued_assignment == station_id and worker.queued_target == target):
				return _result(false, "already_assigned")
			worker.queued_assignment = station_id
			worker.queued_target = target
			PortRules.recall(worker)
		else:
			worker.assignment = station_id
			worker.target = target
			worker.phase = "operating" if station_id == "oil" else "outbound"
			worker.phase_progress = 0.0
			worker.recall_pending = false
			worker.queued_assignment = ""
		_profile.revision += 1
		return _result(true)
	if kind == "recall":
		var worker_id: String = str(command.get("worker", ""))
		if not _profile.run.workers.has(worker_id):
			return _result(false, "unknown_worker")
		var worker: Dictionary = _profile.run.workers[worker_id]
		if worker.assignment.is_empty():
			return _result(false, "already_idle")
		if worker.assignment == "port":
			PortRules.recall(worker)
		else:
			worker.assignment = ""
			worker.phase = "idle"
			worker.phase_progress = 0.0
			worker.recall_pending = false
		worker.queued_assignment = ""
		_profile.revision += 1
		return _result(true)
	return _result(false, "unknown_command")

func advance(seconds: float) -> void:
	if _paused or seconds < 0.0 or not is_finite(seconds):
		return
	_remainder += seconds
	while _remainder + 0.00000001 >= ContentCatalog.STEP:
		_remainder -= ContentCatalog.STEP
		_profile.run.tick += 1
		var generating: bool = _profile.run.generator_built and _profile.run.generator_enabled and _spend_oil(ContentCatalog.GENERATOR_OIL_PER_SECOND * ContentCatalog.STEP)
		if generating != _generator_active:
			_generator_active = generating
			_refresh_network()
		_reserve_boost()
		var oil_powered: bool = _network.consumers.has("oil") and _network.consumers.oil.active
		var oil: float = OilRules.advance(_profile.run, ContentCatalog.STEP, oil_powered)
		if oil > 0.0:
			_produce("oil", oil)
		var deliveries := 0.0
		if _network.consumers.has("port") and _network.consumers.port.active:
			deliveries = PortRules.advance(_profile.run, ContentCatalog.STEP, ContentCatalog.OIL_BOOST_BONUS if _boost_active else 0.0)
		if deliveries > 0.0:
			_produce("alloy", deliveries)
		_profile.revision += 1

func snapshot() -> Dictionary:
	var result: Dictionary = _profile.duplicate(true)
	result["paused"] = _paused
	var oil_bonus: float = ContentCatalog.OIL_BOOST_BONUS if _boost_active else 0.0
	result["derived"] = PortRules.describe(_profile.run, oil_bonus)
	var derived: Dictionary = result.derived
	derived.regions = _network.regions.duplicate(true)
	derived.consumers = _network.consumers.duplicate(true)
	derived.links = _network.links.duplicate(true)
	derived.range = _network.range
	derived.power_capacity = _network.power_capacity
	derived.power_used = _network.power_used
	derived.power_limits = {
		"min_request": 0.0, "max_request": ContentCatalog.MAX_POWER_REQUEST,
		"min_priority": ContentCatalog.MIN_PRIORITY, "max_priority": ContentCatalog.MAX_PRIORITY,
	}
	derived.prices.relays = {}
	for region: String in ContentCatalog.RELAY_PRICES:
		derived.prices.relays[region] = {"alloy": ContentCatalog.RELAY_PRICES[region]}
	if _network.consumers.has("port"):
		var port_power: Dictionary = _network.consumers.port
		derived.stations.port.power = port_power.power
		if not port_power.active:
			derived.stations.port.reason = port_power.reason
			derived.stations.port.active = false
			derived.stations.port.rate = 0.0
	derived.stations.oil = OilRules.describe(_profile.run, _network.consumers.get("oil", {}))
	derived.prices.oil = {"alloy": ContentCatalog.station_price(_profile.run, "oil")}
	for id: String in _profile.run.workers:
		if _profile.run.workers[id].assignment == "oil":
			derived.workers[id].progress = derived.stations.oil.progress
			derived.workers[id].phase_seconds = derived.stations.oil.phase_seconds
	var targets: Array[String] = []
	for region: String in ContentCatalog.BEAM_TARGETS:
		if derived.regions[region].discovered:
			targets.append(region)
	var lit: bool = _profile.run.beam_target == "port"
	var preview_routes: Dictionary = {}
	for route: String in ContentCatalog.PORT_ROUTES:
		preview_routes[route] = {
			"base": PortRules.route_details(route, derived.capacity, 1.0 + oil_bonus) if lit else derived.routes[route],
			"lit": derived.routes[route] if lit else PortRules.route_details(route, derived.capacity, ContentCatalog.PORT_BEAM_LOADING_SPEED + oil_bonus),
		}
	derived.beam = {
		"target": _profile.run.beam_target, "targets": targets,
		"reserved_power": ContentCatalog.BEAM_RESERVED_POWER,
		"port_loading_speed": ContentCatalog.PORT_BEAM_LOADING_SPEED,
		"port_routes": preview_routes,
		"active": (lit and derived.stations.port.active) or (_profile.run.beam_target == "oil" and derived.stations.oil.active),
		"oil_pressure_speed": ContentCatalog.OIL_BEAM_PRESSURE_SPEED,
		"oil_rates": {"base": OilRules.rates(false), "lit": OilRules.rates(true)},
	}
	var generator_reason := "not_built"
	if _profile.run.generator_built:
		generator_reason = "manual_off"
		if _profile.run.generator_enabled:
			generator_reason = "working" if _generator_active else ("starting" if _profile.run.wallet.oil + 0.00000001 >= ContentCatalog.GENERATOR_OIL_PER_SECOND * ContentCatalog.STEP else "no_oil")
	derived.generator = {
		"built": _profile.run.generator_built, "enabled": _profile.run.generator_enabled,
		"active": _generator_active, "reason": generator_reason,
		"consumption": ContentCatalog.GENERATOR_OIL_PER_SECOND if _generator_active else 0.0,
		"rated_consumption": ContentCatalog.GENERATOR_OIL_PER_SECOND,
		"capacity": ContentCatalog.GENERATOR_CAPACITY if _generator_active else 0.0,
		"additional_capacity": ContentCatalog.GENERATOR_CAPACITY,
	}
	derived.prices.generator = {"alloy": ContentCatalog.GENERATOR_PRICE}
	derived.oil_boost = {
		"target": _profile.run.oil_boost_target, "enabled": _profile.run.oil_boost_enabled,
		"active": _boost_active, "reason": _boost_reason, "bonus": ContentCatalog.OIL_BOOST_BONUS,
		"consumption": ContentCatalog.OIL_BOOST_PER_SECOND if _boost_active else 0.0,
		"rated_consumption": ContentCatalog.OIL_BOOST_PER_SECOND, "targets": ["port"],
	}
	var boost_routes: Dictionary = {}
	var beam_speed: float = ContentCatalog.PORT_BEAM_LOADING_SPEED if lit else 1.0
	for route: String in ContentCatalog.PORT_ROUTES:
		boost_routes[route] = {
			"off": derived.routes[route] if not _boost_active else PortRules.route_details(route, derived.capacity, beam_speed),
			"on": derived.routes[route] if _boost_active else PortRules.route_details(route, derived.capacity, beam_speed + ContentCatalog.OIL_BOOST_BONUS),
		}
	derived.oil_boost.port_routes = boost_routes
	derived.oil_production = derived.stations.oil.rate
	derived.oil_consumption = derived.generator.consumption + derived.oil_boost.consumption
	derived.oil_net = derived.oil_production - derived.oil_consumption
	derived.oil_seconds = float(_profile.run.wallet.oil) / float(derived.oil_consumption) if derived.oil_consumption > 0.0 else -1.0
	return result

func export_profile() -> Dictionary:
	return _profile.duplicate(true)

func is_paused() -> bool:
	return _paused

func _refresh_network() -> void:
	_network = NetworkRules.evaluate(_profile.run, _profile.meta.discovered_locations, ContentCatalog.EMERGENCY_POWER + (ContentCatalog.GENERATOR_CAPACITY if _generator_active else 0.0))
	_profile.meta.discovered_locations = _network.discovered_ids.duplicate()

func _reserve_boost() -> void:
	_boost_active = false
	if not _profile.run.oil_boost_enabled:
		return
	if not _network.consumers.has("port") or not _network.consumers.port.active:
		_boost_reason = "no_power"
		return
	var working := false
	for id: String in _profile.run.workers:
		var worker: Dictionary = _profile.run.workers[id]
		if worker.assignment == "port" and not worker.recall_pending:
			working = true
			break
	if not working:
		_boost_reason = "no_worker"
		return
	if not _spend_oil(ContentCatalog.OIL_BOOST_PER_SECOND * ContentCatalog.STEP):
		_profile.run.oil_boost_enabled = false
		_boost_reason = "no_oil"
		return
	_boost_active = true
	_boost_reason = "working"

func _spend_oil(amount: float) -> bool:
	if float(_profile.run.wallet.oil) + 0.00000001 < amount:
		return false
	_profile.run.wallet.oil = maxf(0.0, float(_profile.run.wallet.oil) - amount)
	return true

func _produce(id: String, amount: float) -> void:
	_profile.run.wallet[id] += amount
	_profile.run.lifetime_produced[id] += amount

func _result(accepted: bool, reason: String = "ok") -> Dictionary:
	return {"accepted": accepted, "reason_code": reason, "events": []}
