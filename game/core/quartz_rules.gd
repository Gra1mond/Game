class_name QuartzRules
extends RefCounted

static func assigned_worker(run: Dictionary, station_id: String) -> String:
	for id: String in run.workers:
		if run.workers[id].assignment == station_id:
			return id
	return ""

static func advance(run: Dictionary, station: Dictionary, delta: float, power: float, oil_bonus: float) -> float:
	if power < ContentCatalog.QUARTZ_POWER or assigned_worker(run, station.id).is_empty():
		return 0.0
	if station.phase == "charge" and station.cycle_lens_level < 0:
		station.cycle_lens_level = station.lens_level
	var duration: float = charge_work(station.cycle_lens_level)
	if station.phase == "fracture":
		duration = ContentCatalog.QUARTZ_FRACTURE_SECONDS
	elif station.phase == "cooling":
		duration = ContentCatalog.QUARTZ_COOLING_SECONDS
	var charge_speed: float = power * ((ContentCatalog.QUARTZ_BEAM_CHARGE_SPEED if run.beam_target == "quartz" else 1.0) + oil_bonus)
	var speed: float = charge_speed if station.phase == "charge" else 1.0
	station.phase_progress += delta * speed
	if station.phase_progress + 0.00000001 < duration:
		return 0.0
	station.phase_progress = maxf(0.0, station.phase_progress - duration) / speed
	if station.phase == "charge":
		station.phase = "fracture"
	elif station.phase == "fracture":
		station.phase = "cooling"
		return ContentCatalog.QUARTZ_BATCH
	else:
		station.phase = "charge"
		station.cycle_lens_level = station.lens_level if station.phase_progress > 0.00000001 else -1
		station.phase_progress *= charge_speed
	return 0.0

static func unlocked(run: Dictionary) -> bool:
	if not run.stations.has("port") or not run.stations.has("oil"):
		return false
	for resource: String in ContentCatalog.QUARTZ_UNLOCK_PRODUCTION:
		if run.lifetime_produced[resource] < ContentCatalog.QUARTZ_UNLOCK_PRODUCTION[resource]:
			return false
	return true

static func charge_work(lens_level: int) -> float:
	return ContentCatalog.QUARTZ_LENS_CHARGE_SECONDS if lens_level > 0 else ContentCatalog.QUARTZ_CHARGE_SECONDS

static func cycle_details(lens_level: int, power: float, lit: bool, oil_bonus: float) -> Dictionary:
	var speed: float = power * ((ContentCatalog.QUARTZ_BEAM_CHARGE_SPEED if lit else 1.0) + oil_bonus)
	var charge: float = charge_work(lens_level) / speed
	var cycle: float = charge + ContentCatalog.QUARTZ_FRACTURE_SECONDS + ContentCatalog.QUARTZ_COOLING_SECONDS
	return {"charge_seconds": charge, "cycle_seconds": cycle, "rate": ContentCatalog.QUARTZ_BATCH / cycle}

static func describe(run: Dictionary, station: Dictionary, consumer: Dictionary, oil_bonus: float) -> Dictionary:
	var operator: String = assigned_worker(run, station.id)
	var pending := ""
	for id: String in run.workers:
		if run.workers[id].queued_assignment == station.id:
			pending = id
			break
	var powered: bool = consumer.active
	var active: bool = powered and not operator.is_empty()
	var power: float = consumer.power
	var forecast_power: float = power if powered else maxf(ContentCatalog.QUARTZ_POWER, float(station.power_request))
	var speed: float = forecast_power * ((ContentCatalog.QUARTZ_BEAM_CHARGE_SPEED if run.beam_target == "quartz" else 1.0) + oil_bonus)
	var committed: int = station.cycle_lens_level if station.cycle_lens_level >= 0 else station.lens_level
	var work: float = charge_work(committed)
	var charge: float = work / speed
	var next_charge: float = charge_work(station.lens_level) / speed
	var seconds: float = charge
	if station.phase == "fracture":
		work = ContentCatalog.QUARTZ_FRACTURE_SECONDS
		seconds = work
	elif station.phase == "cooling":
		work = ContentCatalog.QUARTZ_COOLING_SECONDS
		seconds = work
	var progress: float = clampf(float(station.phase_progress) / work, 0.0, 1.0)
	var reason: String = consumer.reason if not powered else ("no_worker" if operator.is_empty() else ("cooling" if station.phase == "cooling" else "working"))
	return {
		"built": true, "kind": "quartz", "active": active, "reason": reason, "power": power,
		"assigned_worker": operator, "pending_worker": pending, "phase": station.phase,
		"progress": progress, "phase_seconds": seconds, "remaining_seconds": (1.0 - progress) * seconds,
		"charge_seconds": charge, "next_charge_seconds": next_charge,
		"lens_preview_seconds": ContentCatalog.QUARTZ_LENS_CHARGE_SECONDS / speed,
		"lens_level": station.lens_level, "cycle_lens_level": station.cycle_lens_level,
		"forecast_power": forecast_power, "forecast_theoretical": not powered,
		"fracture_seconds": ContentCatalog.QUARTZ_FRACTURE_SECONDS,
		"cooling_seconds": ContentCatalog.QUARTZ_COOLING_SECONDS, "next_output": ContentCatalog.QUARTZ_BATCH,
		"rate": ContentCatalog.QUARTZ_BATCH / (next_charge + ContentCatalog.QUARTZ_FRACTURE_SECONDS + ContentCatalog.QUARTZ_COOLING_SECONDS) if active else 0.0,
	}
