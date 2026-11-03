extends RefCounted

func test_oil_first_produces_batches_and_can_return_to_port_without_prestige() -> Array:
	var session := GameSession.new()
	session.new_profile(61)
	var build: Dictionary = session.dispatch({"type": "build", "kind": "oil"})
	if not build.accepted:
		return ["The forty-alloy start must allow the oil station first: " + str(build.reason_code)]
	var assigned: Dictionary = session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	if not assigned.accepted:
		return ["The starting collector must operate the oil pump"]
	session.advance(3.9)
	if session.snapshot().run.lifetime_produced.oil != 0:
		return ["Pressure and incomplete pumping must not pay oil"]
	session.advance(0.1)
	if session.snapshot().run.wallet.oil != 4 or session.snapshot().run.wallet.alloy != 20:
		return ["A two-second pressure plus two-second pump cycle yields four oil, construction costs twenty"]
	if not session.dispatch({"type": "build", "kind": "port"}).accepted:
		return ["Oil-first must retain enough alloy to build the other starting station"]
	if not session.dispatch({"type": "assign", "worker": "w1", "station": "port"}).accepted:
		return ["The same collector must leave the pump for the port"]
	session.advance(5.0)
	var state: Dictionary = session.snapshot()
	if state.run.lifetime_produced.alloy != 4 or state.run.wallet.oil != 4 or state.run.workers.size() != 1:
		return ["Reassignment must produce port cargo without a duplicated pump worker or extra oil"]
	return []

func test_overdrive_outputs_hot_batches_then_cools_automatically() -> Array:
	var session := GameSession.new()
	session.new_profile(62)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	if not session.dispatch({"type": "mode", "station": "oil", "mode": "overdrive"}).accepted:
		return ["Pump overdrive must be a selectable operating mode"]
	session.advance(9.0)
	var state: Dictionary = session.snapshot()
	if state.run.wallet.oil != 18 or state.run.stations.oil.phase != "cooling" or not is_equal_approx(state.run.stations.oil.heat, 60.0):
		return ["Three 2+1 second six-oil batches must reach sixty heat and stop for cooling"]
	session.advance(5.9)
	if session.snapshot().run.wallet.oil != 18 or session.snapshot().run.stations.oil.phase != "cooling":
		return ["Cooling must cost real time and cannot produce a hidden fourth batch"]
	session.advance(0.1)
	session.advance(3.0)
	state = session.snapshot()
	if state.run.wallet.oil != 24 or state.run.stations.oil.phase == "cooling":
		return ["After six seconds of cooling, the next hot batch resumes without another click"]
	return []

func test_beam_stabilizes_remaining_pressure_without_upgrading_an_inflight_batch() -> Array:
	var session := GameSession.new()
	session.new_profile(63)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	session.advance(0.5)
	session.dispatch({"type": "mode", "station": "oil", "mode": "overdrive"})
	session.dispatch({"type": "beam", "target": "oil"})
	session.advance(2.7)
	if session.snapshot().run.wallet.oil != 0:
		return ["The already-started steady batch still needs its full two-second pumping phase"]
	session.advance(0.1)
	if session.snapshot().run.wallet.oil != 4 or session.snapshot().run.stations.oil.heat != 0:
		return ["0.5s pressure + 0.75s lit remaining pressure + 2s pumping completes the original four-oil batch at tick3.3"]
	session.advance(2.0)
	if session.snapshot().run.wallet.oil != 10 or session.snapshot().run.stations.oil.heat != 20:
		return ["Only the following batch adopts overdrive, with one-second lit pressure and one-second pumping"]
	return []

func test_loaded_port_collector_reaches_pump_before_starting_its_work() -> Array:
	var session := GameSession.new()
	session.new_profile(64)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.advance(3.0)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	session.advance(2.0)
	var arrived: Dictionary = session.snapshot()
	if arrived.run.wallet.alloy != 4 or arrived.run.wallet.oil != 0 or arrived.run.workers.w1.assignment != "oil":
		return ["Queued oil assignment must wait for the existing cargo delivery"]
	session.advance(3.9)
	if session.snapshot().run.wallet.oil != 0:
		return ["The return tick cannot also count as a full pump-work tick"]
	session.advance(0.1)
	if session.snapshot().run.wallet.oil != 4 or session.snapshot().run.lifetime_produced.alloy != 4:
		return ["The first pump batch needs four seconds after arrival, with no duplicated old cargo"]
	return []

func test_generator_reserves_old_fuel_and_recovers_on_emergency_power() -> Array:
	var session := GameSession.new()
	session.new_profile(65)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	if not session.dispatch({"type": "build", "kind": "generator"}).accepted:
		return ["An oil-first start must afford the twelve-alloy generator"]
	if not session.dispatch({"type": "generator", "enabled": true}).accepted:
		return ["The built generator must accept an on request"]
	session.advance(4.0)
	var state: Dictionary = session.snapshot()
	if state.run.wallet.oil != 4 or state.derived.power_capacity != 2 or state.derived.generator.active:
		return ["Oil produced at the end of a step cannot fuel generation on that same step"]
	session.advance(0.1)
	state = session.snapshot()
	if not is_equal_approx(state.run.wallet.oil, 3.95) or state.derived.power_capacity != 4:
		return ["A paid 0.05 oil step adds two power without charging the beam reserve twice"]
	session.dispatch({"type": "station_enabled", "station": "oil", "enabled": false})
	session.advance(8.0)
	state = session.snapshot()
	if state.run.wallet.oil < 0 or not is_zero_approx(state.run.wallet.oil) or state.derived.power_capacity != 2:
		return ["Fuel exhaustion removes only generator output and cannot overdraw the tank"]
	session.dispatch({"type": "station_enabled", "station": "oil", "enabled": true})
	session.advance(3.9)
	session.advance(0.1)
	state = session.snapshot()
	if state.derived.power_capacity != 4 or not is_equal_approx(state.run.wallet.oil, 3.95):
		return ["The pump must recover under emergency power and fuel generation again"]
	return []

func test_last_fuel_step_goes_to_generator_before_port_boost() -> Array:
	var session := GameSession.new()
	session.new_profile(66)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "build", "kind": "generator"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	session.advance(4.0)
	session.dispatch({"type": "recall", "worker": "w1"})
	for i in range(12):
		session.dispatch({"type": "collect"})
		session.advance(0.5)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.dispatch({"type": "generator", "enabled": true})
	session.advance(7.9)
	if not session.dispatch({"type": "oil_boost", "target": "port", "enabled": true}).accepted:
		return ["Built port must accept an explicit oil-boost request"]
	session.advance(0.1)
	var state: Dictionary = session.snapshot()
	if not is_zero_approx(state.run.wallet.oil) or not state.derived.generator.active or state.derived.power_capacity != 4:
		return ["The last 0.05 oil pays generation, not the lower-priority boost"]
	if state.run.oil_boost_enabled or state.derived.oil_boost.active:
		return ["Unfunded boost must switch off safely instead of borrowing this step's output"]
	session.advance(0.1)
	if session.snapshot().derived.power_capacity != 2 or session.snapshot().run.wallet.oil < 0:
		return ["The following empty step retains emergency power without fuel debt"]
	return []

func test_paid_port_boost_adds_to_beam_and_stops_without_free_cargo() -> Array:
	var session := GameSession.new()
	session.new_profile(67)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	session.advance(4.0)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.dispatch({"type": "beam", "target": "port"})
	session.dispatch({"type": "oil_boost", "target": "port", "enabled": true})
	session.advance(4.3)
	if session.snapshot().run.lifetime_produced.alloy != 0:
		return ["Combined bonuses cannot bypass the return trip"]
	session.advance(0.1)
	var state: Dictionary = session.snapshot()
	if state.run.lifetime_produced.alloy != 4 or not is_equal_approx(state.run.wallet.oil, 1.8):
		return ["1 + 1 beam + 0.5 oil bonus gives 0.4s loading, 4.4s delivery and costs 2.2 oil"]
	if not is_equal_approx(state.derived.routes.near.loading_seconds, 0.4):
		return ["The route forecast must match the actually funded combined effect"]
	session.dispatch({"type": "oil_boost", "target": "port", "enabled": false})
	session.advance(4.5)
	state = session.snapshot()
	if state.run.lifetime_produced.alloy != 8 or not is_equal_approx(state.run.wallet.oil, 1.8):
		return ["Disabling fuel boost restores beam-only timing and stops consumption without a free delivery"]
	return []

func test_overdrive_average_forecast_includes_automatic_cooling() -> Array:
	var session := GameSession.new()
	session.new_profile(68)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	session.dispatch({"type": "mode", "station": "oil", "mode": "overdrive"})
	session.advance(30.0)
	var state: Dictionary = session.snapshot()
	if not state.derived.stations.has("oil"):
		return ["The oil station must expose a production forecast"]
	if state.run.lifetime_produced.oil != 36 or not is_equal_approx(state.derived.stations.oil.overdrive_rate, 1.2) or not is_equal_approx(state.derived.oil_net, 1.2):
		return ["Two 15-second periods deliver 36 oil; average is 1.2/s, not the 2/s burst rate"]
	return []

func test_pump_assignment_rejects_invalid_routes_and_an_occupied_post_atomically() -> Array:
	var session := GameSession.new()
	session.new_profile(69)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "buy_worker"})
	var before: Dictionary = session.export_profile()
	if session.dispatch({"type": "assign", "worker": "w1", "station": "oil", "target": "missing"}).accepted or session.export_profile() != before:
		return ["An oil assignment must not corrupt the collector's valid route state"]
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	before = session.export_profile()
	var occupied: Dictionary = session.dispatch({"type": "assign", "worker": "w2", "station": "oil"})
	if occupied.accepted or occupied.reason_code != "station_full" or session.export_profile() != before:
		return ["A second collector cannot steal or duplicate the pump post"]
	session.advance(4.0)
	if session.snapshot().run.wallet.oil != 4 or session.snapshot().run.workers.w2.assignment != "":
		return ["The original operator produces one batch; rejected collector stays idle"]
	return []
