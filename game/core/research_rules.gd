class_name ResearchRules
extends RefCounted

static func assigned_worker(run: Dictionary) -> String:
	for id: String in run.workers:
		if run.workers[id].assignment == "research":
			return id
	return ""

static func advance(run: Dictionary, delta: float) -> float:
	var id: String = assigned_worker(run)
	if id.is_empty():
		return 0.0
	var worker: Dictionary = run.workers[id]
	worker.phase_progress += delta
	if worker.phase_progress + 0.00000001 < ContentCatalog.RESEARCH_SECONDS:
		return 0.0
	worker.phase_progress = maxf(0.0, worker.phase_progress - ContentCatalog.RESEARCH_SECONDS)
	return ContentCatalog.RESEARCH_BATCH

static func describe(run: Dictionary, paused: bool) -> Dictionary:
	var assigned: String = assigned_worker(run)
	var pending := ""
	for id: String in run.workers:
		if run.workers[id].queued_assignment == "research":
			pending = id
			break
	var work: float = 0.0 if assigned.is_empty() else float(run.workers[assigned].phase_progress)
	var active: bool = not assigned.is_empty() and not paused
	return {
		"active": active, "reason": "working" if not assigned.is_empty() else ("returning" if not pending.is_empty() else "no_worker"),
		"assigned_worker": assigned, "pending_worker": pending,
		"cycle_seconds": ContentCatalog.RESEARCH_SECONDS, "batch": ContentCatalog.RESEARCH_BATCH,
		"progress": clampf(work / ContentCatalog.RESEARCH_SECONDS, 0.0, 1.0),
		"remaining_seconds": maxf(0.0, ContentCatalog.RESEARCH_SECONDS - work),
		"rate": ContentCatalog.RESEARCH_BATCH / ContentCatalog.RESEARCH_SECONDS if active else 0.0,
	}

static func studies(run: Dictionary, hold_capacity: float) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ContentCatalog.RESEARCHES:
		var study: Dictionary = ContentCatalog.RESEARCHES[id]
		var level: int = run.research_levels.get(id, 0)
		var maximum: int = study.costs.size()
		var cost: Dictionary = {} if level == maximum else study.costs[level].duplicate(true)
		var reason: String = "max_level" if level == maximum else "ready"
		for resource: String in cost:
			if run.wallet[resource] < cost[resource]:
				reason = "insufficient_" + resource
				break
		var current: float = study.effects[level]
		var next: float = study.effects[mini(level + 1, maximum)]
		if id == "capacity":
			next = hold_capacity - current + next
			current = hold_capacity
		elif id == "stability":
			current = ContentCatalog.OIL_HEAT_LIMIT / (ContentCatalog.OIL_COOLING_RATE * current)
			next = ContentCatalog.OIL_HEAT_LIMIT / (ContentCatalog.OIL_COOLING_RATE * next)
		result[id] = {
			"id": id, "name": study.name, "description": study.description,
			"level": level, "max_level": maximum, "cost": cost,
			"can_buy": reason == "ready", "reason": reason,
			"current": {"value": current, "unit": study.unit},
			"next": {"value": next, "unit": study.unit},
		}
	return result

static func automation(run: Dictionary, paused: bool) -> Dictionary:
	var unlocked: bool = int(run.research_levels.get("automation", 0)) > 0
	var enabled: bool = run.automation_enabled
	var active: bool = unlocked and enabled and not paused
	var interval: float = ContentCatalog.STEP * ContentCatalog.MANUAL_COOLDOWN_TICKS
	return {
		"unlocked": unlocked, "enabled": enabled, "active": active,
		"reason": "research_required" if not unlocked else ("manual_off" if not enabled else ("paused" if paused else "working")),
		"rate": 1.0 / interval if active else 0.0, "interval_seconds": interval,
		"cooldown_seconds": maxf(0.0, float(ContentCatalog.MANUAL_COOLDOWN_TICKS - (int(run.tick) - int(run.last_collect_tick))) * ContentCatalog.STEP),
	}
