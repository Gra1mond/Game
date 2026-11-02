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
	return _result(false, "unknown_command")

func advance(seconds: float) -> void:
	if _paused or seconds < 0.0 or not is_finite(seconds):
		return
	_remainder += seconds
	while _remainder + 0.00000001 >= ContentCatalog.STEP:
		_remainder -= ContentCatalog.STEP
		_profile.run.tick += 1
		_profile.revision += 1

func snapshot() -> Dictionary:
	var result: Dictionary = _profile.duplicate(true)
	result["paused"] = _paused
	result["derived"] = {"power_capacity": 2.0, "power_used": 0.0}
	return result

func export_profile() -> Dictionary:
	return _profile.duplicate(true)

func _produce(id: String, amount: float) -> void:
	_profile.run.wallet[id] += amount
	_profile.run.lifetime_produced[id] += amount

func _result(accepted: bool, reason: String = "ok") -> Dictionary:
	return {"accepted": accepted, "reason_code": reason, "events": []}
