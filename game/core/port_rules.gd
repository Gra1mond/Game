class_name PortRules
extends RefCounted

static func advance(run: Dictionary, delta: float) -> float:
	var delivered := 0.0
	for worker_id: String in run.workers:
		var worker: Dictionary = run.workers[worker_id]
		if worker.assignment != "port":
			continue
		var route: Dictionary = ContentCatalog.PORT_ROUTES[worker.target]
		var duration: float = route.loading_seconds if worker.phase == "loading" else route.travel_seconds
		worker.phase_progress += delta
		if worker.phase_progress + 0.00000001 < duration:
			continue
		worker.phase_progress = maxf(0.0, worker.phase_progress - duration)
		match worker.phase:
			"outbound":
				worker.phase = "loading"
			"loading":
				worker.cargo = minf(capacity(run), route.cargo_limit)
				worker.phase = "returning"
			"returning":
				delivered += float(worker.cargo)
				worker.cargo = 0.0
				worker.phase = "outbound"
				if worker.recall_pending:
					worker.assignment = worker.queued_assignment
					worker.target = worker.queued_target
					worker.phase = "idle" if worker.assignment.is_empty() else "outbound"
					worker.phase_progress = 0.0
					worker.recall_pending = false
					worker.queued_assignment = ""
	return delivered

static func recall(worker: Dictionary) -> void:
	worker.recall_pending = true
	var travel: float = ContentCatalog.PORT_ROUTES[worker.target].travel_seconds
	if worker.phase == "outbound":
		worker.phase_progress = maxf(0.0, travel - float(worker.phase_progress))
	elif worker.phase == "loading":
		worker.phase_progress = 0.0
	worker.phase = "returning"

static func capacity(run: Dictionary) -> float:
	return ContentCatalog.CARGO_HOLD_CAPACITY if run.upgrades.get("cargo_hold", 0) > 0 else ContentCatalog.WORKER_CAPACITY

static func describe(run: Dictionary) -> Dictionary:
	var hold_capacity: float = capacity(run)
	var routes: Dictionary = {}
	for target: String in ContentCatalog.PORT_ROUTES:
		routes[target] = route_details(target, hold_capacity)
	var workers: Dictionary = {}
	var total_rate := 0.0
	var assigned := 0
	for id: String in run.workers:
		var worker: Dictionary = run.workers[id]
		var route: Dictionary = routes[worker.target]
		var duration: float = route.loading_seconds if worker.phase == "loading" else route.travel_seconds
		workers[id] = {
			"progress": clampf(float(worker.phase_progress) / duration, 0.0, 1.0),
			"phase_seconds": duration, "capacity": hold_capacity, "routes": routes,
		}
		if worker.assignment == "port":
			assigned += 1
			if not worker.recall_pending:
				total_rate += float(route.rate)
	var built: bool = run.stations.has("port")
	return {
		"workers": workers, "routes": routes, "capacity": hold_capacity,
		"upgraded_routes": {
			"near": route_details("near", ContentCatalog.CARGO_HOLD_CAPACITY),
			"far": route_details("far", ContentCatalog.CARGO_HOLD_CAPACITY),
		},
		"stations": {"port": {"reason": "not_built" if not built else ("working" if assigned > 0 else "no_worker"),
			"active": built and assigned > 0, "rate": total_rate, "assigned_workers": assigned}},
		"prices": {"port": {"alloy": ContentCatalog.port_price(run)}, "worker": {"alloy": ContentCatalog.worker_price(run.workers.size())}},
		"upgrades": {"cargo_hold": {"level": run.upgrades.get("cargo_hold", 0), "max_level": 1,
			"cost": {"alloy": ContentCatalog.CARGO_HOLD_PRICE}, "next_capacity": ContentCatalog.CARGO_HOLD_CAPACITY}},
	}

static func route_details(target: String, hold_capacity: float) -> Dictionary:
	var base: Dictionary = ContentCatalog.PORT_ROUTES[target]
	var cargo: float = minf(hold_capacity, float(base.cargo_limit))
	var cycle: float = float(base.travel_seconds) * 2.0 + float(base.loading_seconds)
	return {
		"name": base.name, "cargo": cargo, "travel_seconds": base.travel_seconds,
		"loading_seconds": base.loading_seconds, "cycle_seconds": cycle, "rate": cargo / cycle,
	}
