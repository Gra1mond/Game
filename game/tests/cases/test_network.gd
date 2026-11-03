extends RefCounted

func test_three_relays_at_range_edge_disconnect_and_restore_as_a_chain() -> Array:
	var session := GameSession.new()
	session.new_profile(41)
	for region: String in ["port", "quartz", "coastal"]:
		var result: Dictionary = session.dispatch({"type": "build_relay", "region": region})
		if not result.accepted:
			return ["Relay %s must be reachable at the 160-unit range boundary: %s" % [region, result.reason_code]]
	var state: Dictionary = session.snapshot()
	if state.run.wallet.alloy != 2 or not state.derived.regions.coastal.connected:
		return ["Three paid relays must connect the outer island, using 38 alloy"]
	session.dispatch({"type": "relay", "region": "quartz", "enabled": false})
	var disconnected: Dictionary = session.snapshot()
	if disconnected.derived.regions.coastal.connected or not disconnected.derived.regions.port.connected:
		return ["Disabling the intermediate relay must disconnect only its dependent branch"]
	if not disconnected.run.relays.has("coastal"):
		return ["Disconnected buildings must not be destroyed"]
	session.dispatch({"type": "relay", "region": "quartz", "enabled": true})
	if not session.snapshot().derived.regions.coastal.connected or session.snapshot().run.wallet.alloy != 2:
		return ["Re-enabling the relay must restore the chain without charging again"]
	return []

func test_power_priority_stops_and_resumes_a_loaded_delivery_without_duplication() -> Array:
	var session := GameSession.new()
	session.new_profile(42)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.advance(3.0)
	session.dispatch({"type": "build_relay", "region": "oil"})
	var requested: Dictionary = session.dispatch({"type": "power", "station": "relay:oil", "request": 2.0, "priority": 10})
	if not requested.accepted:
		return ["Relay power request must be configurable through GameSession"]
	var stopped: Dictionary = session.snapshot()
	if not stopped.derived.regions.oil.active or stopped.derived.regions.port.reason != "no_power":
		return ["At equal priority the stable oil ID takes two units, stopping port's relay"]
	if stopped.derived.stations.port.active or stopped.derived.stations.port.rate != 0:
		return ["A disconnected port must explain its outage and report zero output"]
	var worker: Dictionary = stopped.run.workers.w1
	session.advance(30.0)
	if session.snapshot().run.workers.w1 != worker or session.snapshot().run.wallet.alloy != 10:
		return ["An outage must freeze the loaded phase without losing cargo or paying it early"]
	session.dispatch({"type": "power", "station": "relay:port", "request": 0.25, "priority": 20})
	var restored: Dictionary = session.snapshot()
	if not restored.derived.stations.port.active or restored.derived.regions.oil.reason != "no_power":
		return ["A higher-priority port relay must restore its station while oil cannot fit"]
	session.advance(2.0)
	if session.snapshot().run.wallet.alloy != 14 or session.snapshot().run.lifetime_produced.alloy != 4:
		return ["Restored power must complete exactly the old four-cargo delivery"]
	return []

func test_manual_station_stop_keeps_its_relay_and_downstream_branch_alive() -> Array:
	var session := GameSession.new()
	session.new_profile(43)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "build_relay", "region": "quartz"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.advance(1.0)
	var result: Dictionary = session.dispatch({"type": "station_enabled", "station": "port", "enabled": false})
	if not result.accepted:
		return ["Station stop must be independent from its relay switch"]
	var stopped: Dictionary = session.snapshot()
	if stopped.derived.stations.port.reason != "manual_off" or not stopped.derived.regions.quartz.connected:
		return ["A stopped port must explain manual_off without cutting the relay branch"]
	var worker: Dictionary = stopped.run.workers.w1
	session.advance(9.0)
	if session.snapshot().run.workers.w1 != worker:
		return ["A manual station stop must preserve its partially travelled route"]
	session.dispatch({"type": "station_enabled", "station": "port", "enabled": true})
	session.advance(4.0)
	if session.snapshot().run.lifetime_produced.alloy != 4 or session.snapshot().run.wallet.alloy != 12:
		return ["The remaining four seconds must deliver exactly one existing route"]
	return []

func test_known_but_disconnected_building_does_not_spend_materials() -> Array:
	var session := GameSession.new()
	session.new_profile(44)
	var initial: Dictionary = session.export_profile()
	var unseen: Dictionary = session.dispatch({"type": "build_relay", "region": "quartz"})
	if unseen.accepted or unseen.reason_code != "not_discovered" or session.export_profile() != initial:
		return ["An unseen reef beyond the ship's range must not charge for construction"]
	session.dispatch({"type": "build_relay", "region": "port"})
	session.dispatch({"type": "relay", "region": "port", "enabled": false})
	var state: Dictionary = session.snapshot()
	if not state.derived.regions.quartz.discovered or state.derived.regions.quartz.reachable:
		return ["Discovery must persist, but inactive relays must not extend construction range"]
	if state.derived.regions.quartz.reason != "disconnected":
		return ["The island must explain the lost connection, not merely show an unbuilt relay"]
	var before: Dictionary = session.export_profile()
	var rejected: Dictionary = session.dispatch({"type": "build_relay", "region": "quartz"})
	if rejected.accepted or rejected.reason_code != "disconnected" or session.export_profile() != before:
		return ["Known but disconnected construction must preserve the whole profile"]
	session.dispatch({"type": "relay", "region": "port", "enabled": true})
	var restored: Dictionary = session.dispatch({"type": "build_relay", "region": "quartz"})
	if not restored.accepted or session.snapshot().run.wallet.alloy != 18:
		return ["Restoring the active parent must make the reef buildable for twelve alloy"]
	return []

func test_equal_priority_uses_stable_ids_not_construction_order() -> Array:
	for order: Array in [["port", "oil"], ["oil", "port"]]:
		var session := GameSession.new()
		session.new_profile(45)
		for region: String in order:
			session.dispatch({"type": "build_relay", "region": region})
			session.dispatch({"type": "power", "station": "relay:" + region, "request": 2.0, "priority": 10})
		var state: Dictionary = session.snapshot()
		if not state.derived.regions.oil.active or state.derived.regions.port.reason != "no_power" or state.derived.power_used != 2:
			return ["Equal priority must select relay:oil before relay:port in either construction order"]
	return []

func test_below_minimum_request_draws_nothing_and_does_not_starve_other_consumers() -> Array:
	var session := GameSession.new()
	session.new_profile(46)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "build_relay", "region": "oil"})
	session.dispatch({"type": "power", "station": "relay:oil", "request": 0.1, "priority": 100})
	var state: Dictionary = session.snapshot()
	if state.derived.consumers["relay:oil"].power != 0 or state.derived.regions.oil.reason != "no_power" or not state.derived.consumers.port.active:
		return ["An under-requested relay must draw zero, leaving one unit for the working port"]
	session.dispatch({"type": "power", "station": "port", "request": 0.0, "priority": 100})
	state = session.snapshot()
	if state.derived.stations.port.reason != "no_power" or not state.derived.regions.port.connected or state.derived.power_used != 0.25:
		return ["A zero station request must preserve its quarter-unit relay, not run production for free"]
	return []

func test_invalid_network_commands_are_rejected_atomically() -> Array:
	var session := GameSession.new()
	session.new_profile(47)
	session.dispatch({"type": "build", "kind": "port"})
	var before: Dictionary = session.export_profile()
	for request: Variant in [-1.0, 2.1, INF, NAN, true, "1"]:
		if session.dispatch({"type": "power", "station": "port", "request": request, "priority": 0}).accepted or session.export_profile() != before:
			return ["Invalid power must not alter any field of the profile"]
	for priority: Variant in [-101, 101, 0.5, true, "0"]:
		if session.dispatch({"type": "power", "station": "port", "request": 0.75, "priority": priority}).accepted or session.export_profile() != before:
			return ["Invalid priority must not alter any field of the profile"]
	for command: Dictionary in [
		{"type": "power", "station": "missing", "request": 1.0, "priority": 0},
		{"type": "relay", "region": "port", "enabled": 1},
		{"type": "station_enabled", "station": "port", "enabled": "false"},
	]:
		if session.dispatch(command).accepted or session.export_profile() != before:
			return ["Malformed network actions must reject without partial mutation"]
	return []
