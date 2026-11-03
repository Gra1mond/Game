extends RefCounted

func test_beam_shortens_loading_but_pays_only_after_delivery() -> Array:
	var lit := GameSession.new()
	var base := GameSession.new()
	for session: GameSession in [lit, base]:
		session.new_profile(51)
		session.dispatch({"type": "build", "kind": "port"})
		session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	var aimed: Dictionary = lit.dispatch({"type": "beam", "target": "port"})
	if not aimed.accepted:
		return ["An illuminated port must accept the main beam: " + str(aimed.reason_code)]
	lit.advance(4.4)
	if lit.snapshot().run.lifetime_produced.alloy != 0:
		return ["Faster loading must not pay cargo before its return"]
	lit.advance(0.1)
	base.advance(4.5)
	if lit.snapshot().run.lifetime_produced.alloy != 4 or base.snapshot().run.lifetime_produced.alloy != 0:
		return ["2s outward + 0.5s lit loading + 2s return delivers four at 4.5s, before the baseline 5s"]
	return []

func test_aiming_mid_load_preserves_work_and_updates_forecast() -> Array:
	var session := GameSession.new()
	session.new_profile(52)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.advance(2.5)
	session.dispatch({"type": "beam", "target": "port"})
	var state: Dictionary = session.snapshot()
	if not is_equal_approx(state.derived.workers.w1.progress, 0.5):
		return ["Half-completed loading stays half-completed when the beam changes"]
	if not is_equal_approx(state.derived.workers.w1.phase_seconds, 0.5) or not is_equal_approx(state.derived.routes.near.rate, 8.0 / 9.0):
		return ["The forecast must use 0.5s loading and four cargo per 4.5s route"]
	session.advance(2.3)
	if session.snapshot().run.lifetime_produced.alloy != 4:
		return ["The remaining half-load must finish in 0.25s, then return without restarting work"]
	return []

func test_switching_cannot_turn_loading_work_into_free_travel_or_cargo() -> Array:
	var session := GameSession.new()
	session.new_profile(53)
	session.dispatch({"type": "build", "kind": "port"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "port"})
	session.advance(2.3)
	var before: Dictionary = session.snapshot()
	for i in range(100):
		session.dispatch({"type": "beam", "target": "port"})
		session.dispatch({"type": "beam", "target": "oil"})
	var switched: Dictionary = session.snapshot()
	if switched.run.workers != before.run.workers or switched.run.wallet != before.run.wallet or switched.derived.consumers != before.derived.consumers:
		return ["Aiming alone must not move cargo, complete work, or redistribute relay power"]
	session.dispatch({"type": "beam", "target": "port"})
	session.advance(2.3)
	if session.snapshot().run.lifetime_produced.alloy != 0:
		return ["0.3s baseline load + 0.35s doubled load + travel cannot pay before 4.65s (tick 4.7s)"]
	session.advance(0.1)
	if session.snapshot().run.lifetime_produced.alloy != 4:
		return ["The same partially loaded route must deliver once at 4.7s"]
	for i in range(100):
		session.dispatch({"type": "beam", "target": ""})
		session.dispatch({"type": "beam", "target": "port"})
	session.advance(4.5)
	if session.snapshot().run.lifetime_produced.alloy != 8:
		return ["Further zero-time switches cannot duplicate the next cargo"]
	return []
