class_name GameSession
extends RefCounted

var _profile: Dictionary = {}
var _paused: bool = false
var _remainder: float = 0.0

func new_profile(seed_value: int) -> void:
	_profile = ProfileState.create(seed_value)
	_paused = false
	_remainder = 0.0

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
		if _profile.run.wallet.alloy < ContentCatalog.PORT_PRICE:
			return _result(false, "insufficient_alloy")
		_profile.run.wallet.alloy -= ContentCatalog.PORT_PRICE
		_profile.run.stations.port = {"id": "port", "kind": "port", "enabled": true}
		_profile.revision += 1
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
		var deliveries: float = PortRules.advance(_profile.run, ContentCatalog.STEP)
		if deliveries > 0.0:
			_produce("alloy", deliveries)
		_profile.revision += 1

func snapshot() -> Dictionary:
	var result: Dictionary = _profile.duplicate(true)
	result["paused"] = _paused
	result["derived"] = PortRules.describe(_profile.run)
	return result

func export_profile() -> Dictionary:
	return _profile.duplicate(true)

func is_paused() -> bool:
	return _paused

func _produce(id: String, amount: float) -> void:
	_profile.run.wallet[id] += amount
	_profile.run.lifetime_produced[id] += amount

func _result(accepted: bool, reason: String = "ok") -> Dictionary:
	return {"accepted": accepted, "reason_code": reason, "events": []}
