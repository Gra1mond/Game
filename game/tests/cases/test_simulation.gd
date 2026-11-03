extends RefCounted

func test_manual_collection_is_limited_by_game_time() -> Array:
	var script: Script = load("res://core/game_session.gd")
	if script == null:
		return ["GameSession is not implemented"]
	var session: RefCounted = script.new()
	session.new_profile(7)
	var initial: Dictionary = session.snapshot()
	if initial.run.wallet.alloy != 40 or initial.run.lifetime_produced.alloy != 0:
		return ["Starting stock must not count as production"]
	var first: Dictionary = session.dispatch({"type": "collect"})
	var second: Dictionary = session.dispatch({"type": "collect"})
	if not first.accepted or second.accepted:
		return ["Input repeats must not bypass the collection cooldown"]
	session.advance(0.5)
	session.dispatch({"type": "collect"})
	var state: Dictionary = session.snapshot()
	if state.run.wallet.alloy != 42 or state.run.lifetime_produced.alloy != 2:
		return ["Two allowed actions must yield exactly two alloy"]
	return []

func test_pause_and_rejected_commands_leave_economy_unchanged() -> Array:
	var session := GameSession.new()
	session.new_profile(11)
	var before: Dictionary = session.export_profile()
	session.dispatch({"type": "unknown"})
	session.dispatch({"type": "pause", "paused": true})
	session.advance(5.0)
	session.dispatch({"type": "collect"})
	var copy: Dictionary = session.snapshot()
	copy.run.wallet.alloy = 99999
	if session.export_profile() != before:
		return ["Pause, rejected commands and view copies must not mutate the profile"]
	return []

func test_render_frame_rates_preserve_active_time() -> Array:
	var results: Array = []
	for fps in [30, 144]:
		var session := GameSession.new()
		var clock := FixedClock.new()
		session.new_profile(1)
		for frame in range(fps * 10):
			session.dispatch({"type": "collect"})
			clock.frame(session, 1.0 / fps)
		results.append(session.snapshot().run.lifetime_produced.alloy)
	if results != [20.0, 20.0]:
		return ["10 active seconds at 30 and 144 FPS must allow 20 collections: %s" % [results]]
	return []
