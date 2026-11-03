class_name OilRules
extends RefCounted

static func advance(run: Dictionary, delta: float, powered: bool) -> float:
	if not run.stations.has("oil"):
		return 0.0
	var station: Dictionary = run.stations.oil
	if station.phase == "cooling":
		station.heat = maxf(0.0, float(station.heat) - cooling_rate(run) * delta)
		station.phase_progress += delta
		if station.heat <= 0.00000001:
			station.heat = 0.0
			station.phase = "pressure"
			station.phase_progress = 0.0
			station.cycle_mode = ""
		return 0.0
	if not powered or assigned_worker(run).is_empty():
		return 0.0
	if station.cycle_mode.is_empty():
		station.cycle_mode = station.mode
	var hot: bool = station.cycle_mode == "overdrive"
	if not hot:
		station.heat = maxf(0.0, float(station.heat) - ContentCatalog.OIL_STEADY_COOLING_RATE * delta)
	var duration: float = ContentCatalog.OIL_PRESSURE_SECONDS if station.phase == "pressure" else (ContentCatalog.OIL_OVERDRIVE_PUMP_SECONDS if hot else ContentCatalog.OIL_PUMP_SECONDS)
	var pressure_speed: float = ContentCatalog.OIL_BEAM_PRESSURE_SPEED if run.beam_target == "oil" else 1.0
	var speed: float = pressure_speed if station.phase == "pressure" else 1.0
	station.phase_progress += delta * speed
	if station.phase_progress + 0.00000001 < duration:
		return 0.0
	station.phase_progress = maxf(0.0, station.phase_progress - duration) / speed
	if station.phase == "pressure":
		station.phase = "pumping"
		return 0.0
	var output: float = ContentCatalog.OIL_OVERDRIVE_BATCH if hot else ContentCatalog.OIL_BATCH
	if hot:
		station.heat = minf(ContentCatalog.OIL_HEAT_LIMIT, float(station.heat) + ContentCatalog.OIL_HEAT_PER_BATCH)
	station.phase = "cooling" if station.heat >= ContentCatalog.OIL_HEAT_LIMIT else "pressure"
	station.cycle_mode = ""
	if station.phase == "pressure":
		station.phase_progress *= pressure_speed
		if station.phase_progress > 0.00000001:
			station.cycle_mode = station.mode
	return output

static func assigned_worker(run: Dictionary) -> String:
	for id: String in run.workers:
		if run.workers[id].assignment == "oil":
			return id
	return ""

static func cooling_rate(run: Dictionary) -> float:
	return ContentCatalog.OIL_COOLING_RATE * ContentCatalog.research_effect(run, "stability")

static func rates(run: Dictionary, lit: bool) -> Dictionary:
	var pressure: float = ContentCatalog.OIL_PRESSURE_SECONDS / (ContentCatalog.OIL_BEAM_PRESSURE_SPEED if lit else 1.0)
	var batches: float = ceilf(ContentCatalog.OIL_HEAT_LIMIT / ContentCatalog.OIL_HEAT_PER_BATCH)
	return {
		"steady": ContentCatalog.OIL_BATCH / (pressure + ContentCatalog.OIL_PUMP_SECONDS),
		"overdrive": batches * ContentCatalog.OIL_OVERDRIVE_BATCH / (batches * (pressure + ContentCatalog.OIL_OVERDRIVE_PUMP_SECONDS) + ContentCatalog.OIL_HEAT_LIMIT / cooling_rate(run)),
	}

static func describe(run: Dictionary, power: Dictionary) -> Dictionary:
	var built: bool = run.stations.has("oil")
	var station: Dictionary = run.stations.get("oil", {})
	var assigned: String = assigned_worker(run)
	var pending := ""
	for id: String in run.workers:
		if run.workers[id].queued_assignment == "oil":
			pending = id
			break
	var mode: String = station.get("mode", "steady")
	var committed: String = station.get("cycle_mode", "")
	var phase: String = station.get("phase", "pressure")
	var heat: float = station.get("heat", 0.0)
	var hot: bool = committed == "overdrive" or (committed.is_empty() and mode == "overdrive")
	var pressure_speed: float = ContentCatalog.OIL_BEAM_PRESSURE_SPEED if run.beam_target == "oil" else 1.0
	var work: float = ContentCatalog.OIL_PRESSURE_SECONDS if phase == "pressure" else (ContentCatalog.OIL_OVERDRIVE_PUMP_SECONDS if hot else ContentCatalog.OIL_PUMP_SECONDS)
	var progress: float = clampf(float(station.get("phase_progress", 0.0)) / work, 0.0, 1.0)
	var seconds: float = work / (pressure_speed if phase == "pressure" else 1.0)
	var cooling: float = cooling_rate(run)
	if phase == "cooling":
		progress = 1.0 - heat / ContentCatalog.OIL_HEAT_LIMIT
		seconds = ContentCatalog.OIL_HEAT_LIMIT / cooling
	var powered: bool = power.get("active", false)
	var reason := "not_built"
	if built:
		reason = str(power.get("reason", "no_power")) if not powered else ("no_worker" if assigned.is_empty() else ("cooling" if phase == "cooling" else "working"))
	var forecast: Dictionary = rates(run, run.beam_target == "oil")
	var rate: float = forecast[mode] if built and powered and not assigned.is_empty() else 0.0
	return {
		"built": built, "active": reason == "working", "reason": reason, "power": power.get("power", 0.0),
		"assigned_worker": assigned, "pending_worker": pending, "mode": mode, "cycle_mode": committed,
		"phase": phase, "progress": progress, "phase_seconds": seconds,
		"pressure": progress if phase == "pressure" else (1.0 if phase == "pumping" else 0.0),
		"heat": heat, "heat_limit": ContentCatalog.OIL_HEAT_LIMIT,
		"cooling_rate": cooling, "cooling_seconds": heat / cooling if phase == "cooling" else 0.0,
		"next_output": ContentCatalog.OIL_OVERDRIVE_BATCH if hot else ContentCatalog.OIL_BATCH,
		"rate": rate, "steady_rate": forecast.steady, "overdrive_rate": forecast.overdrive,
	}
