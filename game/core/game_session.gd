class_name GameSession
extends RefCounted

var _profile: Dictionary = {}
var _paused: bool = false
var _remainder: float = 0.0
var _network: Dictionary = {}

func new_profile(seed_value: int) -> void:
	_profile = ProfileState.create(seed_value)
	_paused = false
	_remainder = 0.0
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
	if kind == "build" and command.get("kind") == "port":
		if _profile.run.stations.has("port"):
			return _result(false, "already_built")
		var price: float = ContentCatalog.port_price(_profile.run)
		if _profile.run.wallet.alloy < price:
			return _result(false, "insufficient_alloy")
		if not _network.regions.port.reachable:
			return _result(false, "disconnected")
		_profile.run.wallet.alloy -= price
		if not _profile.run.relays.has("port"):
			_profile.run.relays.port = RunState.create_relay()
		_profile.run.stations.port = {
			"id": "port", "kind": "port", "region": "port", "enabled": true,
			"power_request": ContentCatalog.PORT_POWER, "priority": 0,
		}
		_profile.revision += 1
		_refresh_network()
		return _result(true)
	if kind == "assign":
		var worker_id: String = str(command.get("worker", ""))
		var target: String = str(command.get("target", "near"))
		if not _profile.run.workers.has(worker_id):
			return _result(false, "unknown_worker")
		if command.get("station") != "port" or not _profile.run.stations.has("port"):
			return _result(false, "unknown_station")
		if not ContentCatalog.PORT_ROUTES.has(target):
			return _result(false, "unknown_target")
		var worker: Dictionary = _profile.run.workers[worker_id]
		if worker.assignment == "port":
			if (not worker.recall_pending and worker.target == target) or (worker.recall_pending and worker.queued_assignment == "port" and worker.queued_target == target):
				return _result(false, "already_assigned")
			worker.queued_assignment = "port"
			worker.queued_target = target
			PortRules.recall(worker)
		else:
			worker.assignment = "port"
			worker.target = target
			worker.phase = "outbound"
			worker.phase_progress = 0.0
		_profile.revision += 1
		return _result(true)
	if kind == "recall":
		var worker_id: String = str(command.get("worker", ""))
		if not _profile.run.workers.has(worker_id):
			return _result(false, "unknown_worker")
		var worker: Dictionary = _profile.run.workers[worker_id]
		if worker.assignment.is_empty():
			return _result(false, "already_idle")
		PortRules.recall(worker)
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
		var deliveries := 0.0
		if _network.consumers.has("port") and _network.consumers.port.active:
			deliveries = PortRules.advance(_profile.run, ContentCatalog.STEP)
		if deliveries > 0.0:
			_produce("alloy", deliveries)
		_profile.revision += 1

func snapshot() -> Dictionary:
	var result: Dictionary = _profile.duplicate(true)
	result["paused"] = _paused
	result["derived"] = PortRules.describe(_profile.run)
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
	return result

func export_profile() -> Dictionary:
	return _profile.duplicate(true)

func is_paused() -> bool:
	return _paused

func _refresh_network() -> void:
	_network = NetworkRules.evaluate(_profile.run, _profile.meta.discovered_locations)
	_profile.meta.discovered_locations = _network.discovered_ids.duplicate()

func _produce(id: String, amount: float) -> void:
	_profile.run.wallet[id] += amount
	_profile.run.lifetime_produced[id] += amount

func _result(accepted: bool, reason: String = "ok") -> Dictionary:
	return {"accepted": accepted, "reason_code": reason, "events": []}
