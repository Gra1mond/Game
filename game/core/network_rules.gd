class_name NetworkRules
extends RefCounted

static func evaluate(run: Dictionary, discovered: Array, capacity: float = ContentCatalog.EMERGENCY_POWER) -> Dictionary:
	var consumers: Dictionary = {}
	var relays: Dictionary = run.get("relays", {})
	for region: String in ContentCatalog.REGIONS:
		if region == "ship" or not relays.has(region):
			continue
		var relay: Dictionary = relays[region]
		if not bool(relay.get("built", false)):
			continue
		var id := "relay:" + region
		consumers[id] = _consumer(id, "relay", region, relay, ContentCatalog.RELAY_POWER, 10)
	var stations: Dictionary = run.get("stations", {})
	for id: String in stations:
		var station: Dictionary = stations[id]
		var region: String = station.get("region", id)
		consumers[id] = _consumer(id, "station", region, station, ContentCatalog.OIL_POWER if station.kind == "oil" else ContentCatalog.PORT_POWER, 0)

	var consumer_ids: Array[String] = []
	for id: String in consumers:
		consumer_ids.append(id)
	consumer_ids.sort()
	var active_regions: Dictionary = {"ship": true}
	var links: Array = []
	var power_used := 0.0
	while true:
		var next_id := ""
		var next_parent := ""
		var next_priority := 0
		for id: String in consumer_ids:
			var consumer: Dictionary = consumers[id]
			if consumer.reason != "disconnected":
				continue
			var parent := ""
			if consumer.kind == "relay":
				parent = _parent_for(consumer.region, active_regions)
				if parent.is_empty():
					continue
			elif not active_regions.has(consumer.region):
				continue
			var priority: int = consumer.priority
			if next_id.is_empty() or priority > next_priority:
				next_id = id
				next_parent = parent
				next_priority = priority
		if next_id.is_empty():
			break
		var consumer: Dictionary = consumers[next_id]
		var request: float = consumer.request
		if request < float(consumer.minimum_request) or power_used + request > capacity:
			consumer.reason = "no_power"
			continue
		consumer.power = request
		consumer.active = true
		consumer.reason = "working"
		power_used += request
		if consumer.kind == "relay":
			active_regions[consumer.region] = true
			# Choose only an already powered parent, keeping every link rooted at the ship.
			links.append([next_parent, consumer.region])

	var known: Dictionary = {}
	for id: String in discovered:
		known[id] = true
	for region: String in ContentCatalog.REGIONS:
		for active_region: String in active_regions:
			if _distance_squared(region, active_region) <= ContentCatalog.RELAY_RANGE * ContentCatalog.RELAY_RANGE:
				known[region] = true
				break
	var discovered_ids: Array[String] = []
	for id: String in known:
		discovered_ids.append(id)
	discovered_ids.sort()

	var regions: Dictionary = {}
	for region: String in ContentCatalog.REGIONS:
		var definition: Dictionary = ContentCatalog.REGIONS[region]
		var is_ship: bool = region == "ship"
		var built: bool = is_ship or consumers.has("relay:" + region)
		var active: bool = active_regions.has(region)
		var is_discovered: bool = known.has(region)
		var reachable: bool = not _parent_for(region, active_regions).is_empty()
		var reason := "working"
		if not is_discovered:
			reason = "not_discovered"
		elif not built:
			reason = "not_built" if reachable else "disconnected"
		elif not is_ship:
			reason = consumers["relay:" + region].reason
		regions[region] = {
			"name": definition.name, "position": definition.position.duplicate(),
			"discovered": is_discovered, "unlocked": is_discovered, "built": built,
			"reachable": reachable,
			"connected": active, "active": active, "reason": reason,
		}
	return {
		"regions": regions, "consumers": consumers, "links": links,
		"power_capacity": capacity, "power_used": power_used,
		"range": ContentCatalog.RELAY_RANGE, "discovered_ids": discovered_ids,
	}

static func _consumer(id: String, kind: String, region: String, record: Dictionary, minimum: float, default_priority: int) -> Dictionary:
	var enabled: bool = record.get("enabled", true)
	return {
		"id": id, "kind": kind, "region": region, "enabled": enabled,
		"request": float(record.get("power_request", minimum)), "minimum_request": minimum,
		"priority": int(record.get("priority", default_priority)), "power": 0.0,
		"active": false, "reason": "disconnected" if enabled else "manual_off",
	}

static func _parent_for(region: String, active_regions: Dictionary) -> String:
	var parent := ""
	var nearest_distance := INF
	for candidate: String in active_regions:
		if candidate == region:
			continue
		var distance: float = _distance_squared(region, candidate)
		if distance > ContentCatalog.RELAY_RANGE * ContentCatalog.RELAY_RANGE:
			continue
		if distance < nearest_distance or (distance == nearest_distance and (parent.is_empty() or candidate < parent)):
			parent = candidate
			nearest_distance = distance
	return parent

static func _distance_squared(first: String, second: String) -> float:
	var first_position: Array = ContentCatalog.REGIONS[first].position
	var second_position: Array = ContentCatalog.REGIONS[second].position
	var dx: float = float(first_position[0]) - float(second_position[0])
	var dy: float = float(first_position[1]) - float(second_position[1])
	return dx * dx + dy * dy
