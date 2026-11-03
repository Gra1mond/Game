extends RefCounted

func test_cargo_is_paid_once_only_after_delivery() -> Array:
	var session := GameSession.new()
	session.new_profile(1)
	var build: Dictionary = session.dispatch({"type": "build", "kind": "port"})
	if not build.accepted:
		return ["Port construction must be available: " + build.reason_code]
	session.dispatch({"type": "assign", "worker": "w1", "station": "port", "target": "near"})
	session.advance(3.0)
	if session.snapshot().run.wallet.alloy != 20 or session.snapshot().run.workers.w1.cargo != 4:
		return ["Loaded cargo is not yet wallet income"]
	session.advance(2.0)
	var state: Dictionary = session.snapshot()
	if state.run.wallet.alloy != 24 or state.run.lifetime_produced.alloy != 4:
		return ["A 2+1+2 second route must deliver exactly four alloy"]
	return []

func test_recall_delivers_loaded_cargo_then_releases_worker() -> Array:
	var session := GameSession.new()
	session.new_profile(2)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.advance(3.0)
	var recalled: Dictionary = session.dispatch({"type": "recall", "worker": "w1"})
	if not recalled.accepted:
		return ["Recall must accept a loaded collector"]
	session.advance(2.0)
	var state: Dictionary = session.snapshot()
	if state.run.wallet.alloy != 24 or state.run.workers.w1.assignment != "" or state.run.workers.w1.cargo != 0:
		return ["Recall must deliver the existing four cargo and release the same worker"]
	session.advance(20.0)
	if session.snapshot().run.lifetime_produced.alloy != 4 or session.snapshot().run.workers.size() != 1:
		return ["An idle recalled worker must not duplicate cargo or itself"]
	return []

func test_recall_before_loading_returns_without_creating_cargo() -> Array:
	for sample: Array in [[0.5, 0.5], [2.5, 2.0]]:
		var session := GameSession.new()
		session.new_profile(3)
		session.dispatch({"type": "build", "kind": "port"})
		session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
		session.advance(sample[0])
		session.dispatch({"type": "recall", "worker": "w1"})
		session.advance(sample[1])
		var state: Dictionary = session.snapshot()
		if state.run.workers.w1.assignment != "" or state.run.wallet.alloy != 20 or state.run.lifetime_produced.alloy != 0:
			return ["Recall at %.1fs must return empty in %.1fs, not finish loading" % sample]
	return []

func test_retarget_and_repeat_assignment_preserve_in_transit_cargo() -> Array:
	var session := GameSession.new()
	session.new_profile(4)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.advance(3.5)
	session.dispatch({"type": "assign", "worker": "w1", "station": "port", "target": "far"})
	session.advance(1.5)
	var delivered: Dictionary = session.snapshot()
	if delivered.run.wallet.alloy != 24 or delivered.run.workers.w1.target != "far":
		return ["A changed destination starts only after the old four-cargo delivery"]
	for step in range(80):
		session.dispatch({"type": "assign", "worker": "w1", "station": "port", "target": "far"})
		session.advance(0.1)
	var state: Dictionary = session.snapshot()
	if state.run.lifetime_produced.alloy != 8 or state.run.workers.size() != 1:
		return ["Repeated assignment must neither restart the route nor duplicate worker/cargo"]
	return []

func test_purchase_failure_keeps_stock_and_manual_recovery_available() -> Array:
	var session := GameSession.new()
	session.new_profile(5)
	session.dispatch({"type": "build", "kind": "port"})
	var purchase: Dictionary = session.dispatch({"type": "buy_worker"})
	if not purchase.accepted:
		return ["A second collector must cost the affordable twelve alloy"]
	if session.snapshot().run.wallet.alloy != 8 or session.snapshot().run.workers.size() != 2:
		return ["One purchase must charge twelve once and create one distinct worker"]
	var before: Dictionary = session.export_profile()
	var rejected: Dictionary = session.dispatch({"type": "buy_worker"})
	if rejected.accepted or rejected.reason_code != "insufficient_alloy" or session.export_profile() != before:
		return ["Unaffordable purchase must explain shortage without changing progress"]
	for action in range(9):
		session.dispatch({"type": "collect"})
		session.advance(0.5)
	var recovered: Dictionary = session.dispatch({"type": "buy_worker"})
	if not recovered.accepted or session.snapshot().run.wallet.alloy != 0 or session.snapshot().run.workers.size() != 3:
		return ["Free salvage must recover seventeen alloy for the next collector"]
	return []

func test_larger_hold_changes_which_renewable_route_is_profitable() -> Array:
	for sample: Array in [["near", false, 32.0], ["far", false, 20.0], ["near", true, 32.0], ["far", true, 40.0]]:
		var session := GameSession.new()
		session.new_profile(6)
		session.dispatch({"type": "build", "kind": "port"})
		if sample[1]:
			var upgrade: Dictionary = session.dispatch({"type": "upgrade", "id": "cargo_hold"})
			if not upgrade.accepted:
				return ["A larger hold must be purchasable before research is introduced"]
		session.dispatch({"type": "assign", "worker": "w1", "station": "port", "target": sample[0]})
		session.advance(40.0)
		if session.snapshot().run.lifetime_produced.alloy != sample[2]:
			return ["Route %s with upgraded=%s must deliver %.0f in forty seconds" % sample]
	return []

func test_collectors_work_independently_and_invalid_actions_spend_nothing() -> Array:
	var session := GameSession.new()
	session.new_profile(8)
	session.dispatch({"type": "build", "kind": "port"})
	var before: Dictionary = session.export_profile()
	for command: Dictionary in [
		{"type": "build", "kind": "port"},
		{"type": "assign", "worker": "missing", "station": "port"},
		{"type": "assign", "worker": "w1", "station": "port", "target": "missing"},
	]:
		if session.dispatch(command).accepted or session.export_profile() != before:
			return ["Invalid/repeated actions must leave the entire profile unchanged"]
	session.dispatch({"type": "buy_worker"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port", "target": "near"})
	session.dispatch({"type": "assign", "worker": "w2", "station": "port", "target": "far"})
	session.advance(8.0)
	var state: Dictionary = session.snapshot()
	if state.run.wallet.alloy != 16 or state.run.lifetime_produced.alloy != 8:
		return ["Independent near/far collectors must deliver four each by eight seconds"]
	return []

func test_installing_hold_does_not_change_cargo_already_loaded() -> Array:
	var session := GameSession.new()
	session.new_profile(9)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port", "target": "far"})
	session.advance(5.0)
	session.dispatch({"type": "upgrade", "id": "cargo_hold"})
	session.advance(3.0)
	if session.snapshot().run.lifetime_produced.alloy != 4:
		return ["Installing a hold during return must not enlarge the existing four-cargo load"]
	var before: Dictionary = session.export_profile()
	var rejected: Dictionary = session.dispatch({"type": "upgrade", "id": "cargo_hold"})
	if rejected.accepted or rejected.reason_code != "max_level" or session.export_profile() != before:
		return ["A maxed hold upgrade must reject without charging again"]
	session.advance(8.0)
	if session.snapshot().run.lifetime_produced.alloy != 12:
		return ["The following far route must use the upgraded eight-cargo hold"]
	return []
