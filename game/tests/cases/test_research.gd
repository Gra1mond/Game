extends RefCounted

func test_ship_research_pays_completed_work_and_reserves_one_real_worker() -> Array:
	var session := GameSession.new()
	session.new_profile(81)
	if not session.dispatch({"type": "assign", "worker": "w1", "station": "research"}).accepted:
		return ["The ship must offer research before any district or random find"]
	session.advance(4.9)
	if session.snapshot().run.wallet.data != 0:
		return ["Unfinished research cannot pay partial data"]
	session.advance(0.1)
	if session.snapshot().run.wallet.data != 1:
		return ["Five seconds of actual research pays one data"]
	session.dispatch({"type": "buy_worker"})
	var before: Dictionary = session.export_profile()
	var rejected: Dictionary = session.dispatch({"type": "assign", "worker": "w2", "station": "research"})
	if rejected.accepted or rejected.reason_code != "station_full" or session.export_profile() != before:
		return ["The slow onboard post has one operator, not free duplicated researchers"]
	session.dispatch({"type": "recall", "worker": "w1"})
	session.advance(5.0)
	if session.snapshot().run.wallet.data != 1 or session.snapshot().run.workers.w1.assignment != "":
		return ["A recalled researcher cannot keep producing from an idle assignment"]
	return []

func _study() -> GameSession:
	var session := GameSession.new()
	session.new_profile(82)
	assert(session.dispatch({"type": "assign", "worker": "w1", "station": "research"}).accepted)
	return session

func test_capacity_research_spends_data_and_improves_real_cargo_alongside_equipment() -> Array:
	var session := _study()
	session.advance(20.0)
	if not session.dispatch({"type": "research", "id": "capacity"}).accepted:
		return ["The first ship data must buy an ordinary upgrade without the city"]
	var state: Dictionary = session.snapshot()
	if state.run.wallet.data != 0 or state.run.wallet.alloy != 32 or state.run.lifetime_produced.data != 4:
		return ["Capacity research pays four data and eight alloy without erasing cumulative data production"]
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port", "target": "far"})
	session.advance(7.9)
	if session.snapshot().run.wallet.alloy != 12:
		return ["Research cannot turn an unfinished route into alloy"]
	session.advance(0.1)
	if session.snapshot().run.wallet.alloy != 17:
		return ["The completed far route now carries five, not the original four"]
	session.dispatch({"type": "upgrade", "id": "cargo_hold"})
	session.advance(8.0)
	if session.snapshot().run.wallet.alloy != 10 or session.snapshot().run.lifetime_produced.alloy != 14:
		return ["The existing eight-place equipment and one research place combine into a genuine nine-place delivery"]
	return []

func _quartz_economy() -> GameSession:
	var session := _study()
	session.advance(30.0)
	for index in 80:
		assert(session.dispatch({"type": "collect"}).accepted)
		session.advance(0.5)
	assert(session.dispatch({"type": "build", "kind": "port"}).accepted)
	assert(session.dispatch({"type": "build", "kind": "oil"}).accepted)
	assert(session.dispatch({"type": "build", "kind": "generator"}).accepted)
	assert(session.dispatch({"type": "generator", "enabled": true}).accepted)
	assert(session.dispatch({"type": "buy_worker"}).accepted)
	assert(session.dispatch({"type": "assign", "worker": "w2", "station": "oil"}).accepted)
	assert(session.dispatch({"type": "buy_worker"}).accepted)
	session.advance(8.0)
	assert(session.dispatch({"type": "build", "kind": "quartz"}).accepted)
	assert(session.dispatch({"type": "assign", "worker": "w3", "station": "quartz_1"}).accepted)
	session.advance(9.0)
	return session

func test_quartz_optics_accelerates_remaining_travel_and_combines_with_port_beam() -> Array:
	var session := _quartz_economy()
	session.dispatch({"type": "assign", "worker": "w3", "station": "port"})
	session.dispatch({"type": "beam", "target": "port"})
	session.advance(0.5)
	var before: Dictionary = session.snapshot()
	if not session.dispatch({"type": "research", "id": "optics"}).accepted:
		return ["Ordinarily produced quartz and ship data must purchase navigation optics"]
	var state: Dictionary = session.snapshot()
	if state.run.wallet.quartz != 0 or state.run.wallet.data != before.run.wallet.data - 6:
		return ["Navigation optics spends four quartz and six data, not alloy"]
	if not is_equal_approx(state.derived.routes.near.cycle_seconds, 3.7):
		return ["Optics travel and beam loading combine as 1.6 + 0.5 + 1.6 seconds"]
	if state.run.workers.w3.phase_progress != before.run.workers.w3.phase_progress or not is_equal_approx(state.derived.workers.w3.progress, 0.25):
		return ["Purchasing optics must preserve the half-second of completed base travel work"]
	session.advance(3.2)
	if session.snapshot().run.wallet.alloy != before.run.wallet.alloy:
		return ["Remaining outbound work, loading and return still require 3.3 seconds"]
	session.advance(0.1)
	if session.snapshot().run.wallet.alloy != before.run.wallet.alloy + 4:
		return ["The accelerated first return must actually pay four alloy at the predicted boundary"]
	return []

func test_stability_cools_existing_heat_faster_without_restarting_the_pump() -> Array:
	var session := _study()
	session.advance(20.0)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "buy_worker"})
	session.dispatch({"type": "assign", "worker": "w2", "station": "oil"})
	session.dispatch({"type": "mode", "station": "oil", "mode": "overdrive"})
	session.advance(10.0)
	var before: Dictionary = session.snapshot()
	if before.run.wallet.oil != 18 or not is_equal_approx(before.run.stations.oil.heat, 50):
		return ["The example must begin with three paid hot batches and one second of existing cooldown"]
	if not session.dispatch({"type": "research", "id": "stability"}).accepted:
		return ["Ordinary ship data can improve pump stability"]
	var state: Dictionary = session.snapshot()
	if state.run.stations.oil != before.run.stations.oil:
		return ["Stability cannot erase existing heat or restart an unfinished phase"]
	if not is_equal_approx(state.derived.stations.oil.cooling_seconds, 50.0 / 12.0) or not is_equal_approx(state.derived.stations.oil.overdrive_rate, 18.0 / 14.0):
		return ["The remaining heat cools at twelve per second; the full hot period is nine plus five seconds"]
	session.advance(4.1)
	if session.snapshot().run.stations.oil.phase != "cooling" or session.snapshot().run.wallet.oil != 18:
		return ["Research still cannot skip the remaining physical cooling boundary"]
	session.advance(0.1)
	if session.snapshot().run.stations.oil.phase != "pressure":
		return ["Existing heat finishes cooling after 4.2 quantized seconds, not the original five"]
	session.advance(2.9)
	if session.snapshot().run.wallet.oil != 18:
		return ["Faster cooling does not also accelerate pumping or pay an unfinished batch"]
	session.advance(0.1)
	if session.snapshot().run.wallet.oil != 24:
		return ["The next unchanged hot batch pays six after its complete three-second work"]
	return []

func test_unlocked_automation_shares_manual_cooldown_and_stops_on_pause_or_disable() -> Array:
	var session := _study()
	session.advance(40.0)
	var before: Dictionary = session.export_profile()
	var locked: Dictionary = session.dispatch({"type": "automation", "enabled": true})
	if locked.accepted or locked.reason_code != "research_required" or session.export_profile() != before:
		return ["Auto salvage cannot run or mutate the profile before its research"]
	if not session.dispatch({"type": "research", "id": "automation"}).accepted:
		return ["Eight ship data and twelve alloy must unlock automation in the first run"]
	if session.snapshot().run.wallet.alloy != 28 or session.snapshot().run.automation_enabled:
		return ["Research unlocks, but does not silently enable or pay for automatic salvage"]
	before = session.export_profile()
	var maximum: Dictionary = session.dispatch({"type": "research", "id": "automation"})
	if maximum.accepted or maximum.reason_code != "max_level" or session.export_profile() != before:
		return ["The maximum level rejects before spending, even when its previous price is no longer affordable"]
	if not session.dispatch({"type": "automation", "enabled": true}).accepted:
		return ["The unlocked automation has an explicit enable switch"]
	session.advance(0.1)
	if session.snapshot().run.wallet.alloy != 29:
		return ["Enabled salvage pays one alloy on the next eligible simulation tick"]
	before = session.export_profile()
	var manual: Dictionary = session.dispatch({"type": "collect"})
	if manual.accepted or manual.reason_code != "cooldown" or session.export_profile() != before:
		return ["Manual clicking cannot duplicate an automatic payout within the same cooldown"]
	session.advance(0.4)
	if session.snapshot().run.wallet.alloy != 29:
		return ["Auto salvage observes the same half-second interval as manual collection"]
	session.advance(0.1)
	if session.snapshot().run.wallet.alloy != 30:
		return ["The next eligible tick pays exactly one additional alloy"]
	session.dispatch({"type": "pause", "paused": true})
	before = session.export_profile()
	session.advance(10.0)
	if session.export_profile() != before:
		return ["Paused automation cannot earn resources or age the shared cooldown"]
	session.dispatch({"type": "pause", "paused": false})
	session.advance(0.5)
	if session.snapshot().run.wallet.alloy != 31:
		return ["Resume earns one ordinary payout, not offline catch-up"]
	session.dispatch({"type": "automation", "enabled": false})
	session.advance(1.0)
	if session.snapshot().run.wallet.alloy != 31 or not session.dispatch({"type": "collect"}).accepted:
		return ["Disabling stops automatic income without removing ordinary manual collection"]
	if session.snapshot().run.wallet.alloy != 32 or session.snapshot().run.lifetime_produced.alloy != 4:
		return ["Both collection modes use the same genuine production accounting"]
	return []

func test_research_shortage_rejects_the_entire_multiresource_purchase() -> Array:
	var session := _study()
	session.advance(20.0)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "build", "kind": "oil"})
	var before: Dictionary = session.export_profile()
	var rejected: Dictionary = session.dispatch({"type": "research", "id": "capacity"})
	if rejected.accepted or rejected.reason_code != "insufficient_alloy" or session.export_profile() != before:
		return ["Having enough data cannot spend it when the alloy part of the same research price is missing"]
	return []
