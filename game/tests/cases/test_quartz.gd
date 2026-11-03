extends RefCounted

func _oil_economy() -> GameSession:
	var session := GameSession.new()
	session.new_profile(71)
	assert(session.dispatch({"type": "build", "kind": "oil"}).accepted)
	assert(session.dispatch({"type": "assign", "worker": "w1", "station": "oil"}).accepted)
	for index in 64:
		assert(session.dispatch({"type": "collect"}).accepted)
		session.advance(0.5)
	assert(session.dispatch({"type": "build", "kind": "port"}).accepted)
	assert(session.dispatch({"type": "build", "kind": "generator"}).accepted)
	assert(session.dispatch({"type": "buy_worker"}).accepted)
	assert(session.dispatch({"type": "generator", "enabled": true}).accepted)
	session.advance(0.1)
	return session

func test_drill_pays_only_after_fracture_and_keeps_its_cooling_interval() -> Array:
	var session := _oil_economy()
	if not session.dispatch({"type": "build", "kind": "quartz"}).accepted:
		return ["An established oil/port economy must be able to build its first drill"]
	if not session.dispatch({"type": "assign", "worker": "w2", "station": "quartz_1"}).accepted:
		return ["The new drill must accept an available operator"]
	session.advance(8.9)
	if session.snapshot().run.wallet.quartz != 0:
		return ["Eight seconds of charge alone cannot pay quartz before fracture completes"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 4:
		return ["The first completed fracture pays four quartz once"]
	session.advance(12.9)
	if session.snapshot().run.wallet.quartz != 4:
		return ["A subsequent payout needs the full four-second cooling, eight-second charge and one-second fracture"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 8 or session.snapshot().run.lifetime_produced.quartz != 8:
		return ["The second fracture pays once at twenty-two seconds, not during cooling"]
	return []

func test_unlock_requires_both_starting_stations_and_actual_current_cycle_output() -> Array:
	var session := GameSession.new()
	session.new_profile(72)
	session.dispatch({"type": "build", "kind": "port"})
	var before: Dictionary = session.export_profile()
	var locked: Dictionary = session.dispatch({"type": "build", "kind": "quartz"})
	if locked.accepted or locked.reason_code != "quartz_locked" or session.export_profile() != before:
		return ["Visible reefs must reject construction without spending until both starting productions are established"]
	for index in 12:
		session.dispatch({"type": "collect"})
		session.advance(0.5)
	session.dispatch({"type": "build", "kind": "oil"})
	session.dispatch({"type": "assign", "worker": "w1", "station": "oil"})
	session.advance(4.0)
	before = session.export_profile()
	locked = session.dispatch({"type": "build", "kind": "quartz"})
	if locked.accepted or locked.reason_code != "quartz_locked" or session.export_profile() != before:
		return ["Four oil is below the eight-oil production threshold, even with both stations built"]
	session.advance(4.0)
	for index in 20:
		session.dispatch({"type": "collect"})
		session.advance(0.5)
	if not session.dispatch({"type": "build", "kind": "quartz"}).accepted:
		return ["Renewable production and ordinary collection must unlock the first drill without a random find"]
	if session.snapshot().run.wallet.alloy != 0 or not session.snapshot().derived.quartz.unlocked:
		return ["The first drill costs thirty-two including its relay, without spending the production threshold"]
	return []

func test_beam_accelerates_remaining_charge_but_not_fracture_or_cooling() -> Array:
	var session := _oil_economy()
	session.dispatch({"type": "build", "kind": "quartz"})
	session.dispatch({"type": "assign", "worker": "w2", "station": "quartz_1"})
	session.advance(2.0)
	session.dispatch({"type": "beam", "target": "quartz"})
	session.advance(3.9)
	if session.snapshot().run.wallet.quartz != 0:
		return ["The remaining six units of charge still need three lit seconds and a full fracture"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 4:
		return ["Aiming after two base seconds completes the first fracture at six seconds"]
	session.advance(8.9)
	if session.snapshot().run.wallet.quartz != 4:
		return ["The beam cannot remove four-second cooling or one-second fracture"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 8:
		return ["The next illuminated cycle takes nine seconds including unchanged cooling"]
	return []

func _two_drills() -> GameSession:
	var session := _oil_economy()
	assert(session.dispatch({"type": "build", "kind": "quartz"}).accepted)
	for index in 40:
		session.dispatch({"type": "collect"})
		session.advance(0.5)
	assert(session.dispatch({"type": "build", "kind": "quartz"}).accepted)
	assert(session.dispatch({"type": "buy_worker"}).accepted)
	assert(session.dispatch({"type": "station_enabled", "station": "port", "enabled": false}).accepted)
	assert(session.dispatch({"type": "power", "station": "quartz_1", "request": 1.5, "priority": 0}).accepted)
	assert(session.dispatch({"type": "assign", "worker": "w2", "station": "quartz_1"}).accepted)
	assert(session.dispatch({"type": "assign", "worker": "w3", "station": "quartz_2"}).accepted)
	return session

func test_paid_beam_and_oil_scale_each_drills_allocated_power_without_skipping_cooling() -> Array:
	var session := _two_drills()
	session.dispatch({"type": "beam", "target": "quartz"})
	if not session.dispatch({"type": "oil_boost", "target": "quartz", "enabled": true}).accepted:
		return ["Reefs must accept the same paid district boost as port"]
	session.advance(3.1)
	if session.snapshot().run.wallet.quartz != 0:
		return ["Power1.5 times additive speed2.5 still needs a full fracture after charge"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 4:
		return ["The faster drill pays at3.2 seconds, not as if same-group bonuses multiplied"]
	session.advance(0.9)
	if session.snapshot().run.wallet.quartz != 4:
		return ["The second drill at power1 must keep its independently slower charge"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 8:
		return ["The second drill pays at4.2 seconds while both fit in the four-power budget"]
	session.advance(6.0)
	if session.snapshot().run.wallet.quartz != 8:
		return ["Even paid beam/oil cannot erase the first drill's four-second cooling"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 12:
		return ["After cooling the faster drill pays its second batch at10.3 seconds"]
	return []

func test_retargeting_boost_removes_the_old_effect_until_the_next_paid_step() -> Array:
	var session := _oil_economy()
	session.dispatch({"type": "build", "kind": "quartz"})
	for index in 20:
		session.dispatch({"type": "collect"})
		session.advance(0.5)
	session.dispatch({"type": "buy_worker"})
	session.dispatch({"type": "assign", "worker": "w2", "station": "port"})
	session.dispatch({"type": "assign", "worker": "w3", "station": "quartz_1"})
	session.dispatch({"type": "beam", "target": "port"})
	session.dispatch({"type": "oil_boost", "target": "port", "enabled": true})
	session.advance(0.1)
	var before: Dictionary = session.snapshot()
	session.dispatch({"type": "oil_boost", "target": "quartz", "enabled": true})
	var changed: Dictionary = session.snapshot()
	if changed.derived.oil_boost.active or not is_equal_approx(changed.derived.routes.near.loading_seconds, 0.5):
		return ["Retargeting cannot carry a previously paid port effect into an unpaid reef effect"]
	if changed.run.stations.quartz_1 != before.run.stations.quartz_1 or changed.run.wallet.quartz != 0:
		return ["Changing a fuel target cannot advance the drill or pay cargo"]
	session.advance(6.2)
	if session.snapshot().run.wallet.quartz != 0:
		return ["The reef still needs its remaining charge and a full fracture after retargeting"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 4 or not session.snapshot().derived.oil_boost.active:
		return ["The next prepaid steps fund the reef's1.5 charge speed without the port-only beam leaking in"]
	return []

func test_lens_bought_while_cooling_shortens_next_charge_without_cancelling_cooling() -> Array:
	var session := _oil_economy()
	session.dispatch({"type": "build", "kind": "quartz"})
	session.dispatch({"type": "assign", "worker": "w2", "station": "quartz_1"})
	session.advance(11.0)
	var before: Dictionary = session.snapshot().run.stations.quartz_1
	if not session.dispatch({"type": "upgrade", "id": "quartz_lens", "station": "quartz_1"}).accepted:
		return ["A first base batch must afford the optional drill lens"]
	var upgraded: Dictionary = session.snapshot()
	if upgraded.run.wallet.quartz != 0 or upgraded.run.lifetime_produced.quartz != 4:
		return ["The lens spends four saved quartz, not cumulative production"]
	if upgraded.run.stations.quartz_1.phase != before.phase or upgraded.run.stations.quartz_1.phase_progress != before.phase_progress:
		return ["Buying a lens must preserve the cooling already in progress"]
	session.advance(8.9)
	if session.snapshot().run.wallet.quartz != 0:
		return ["Two remaining cooling seconds plus six charge and one fracture cannot finish early"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 4:
		return ["The next fracture completes at twenty seconds with the lens, not twenty-two"]
	return []

func test_lens_cannot_retroactively_shorten_a_charge_already_started() -> Array:
	var session := _oil_economy()
	session.dispatch({"type": "build", "kind": "quartz"})
	session.dispatch({"type": "assign", "worker": "w2", "station": "quartz_1"})
	session.advance(14.0)
	session.dispatch({"type": "upgrade", "id": "quartz_lens", "station": "quartz_1"})
	session.advance(7.9)
	if session.snapshot().run.wallet.quartz != 0:
		return ["A lens bought one second into the next base charge cannot retroactively shorten that charge"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 4:
		return ["The committed base charge still completes its fracture at twenty-two seconds"]
	session.advance(10.9)
	if session.snapshot().run.wallet.quartz != 4:
		return ["The following lensed cycle still includes four cooling and one fracture second"]
	session.advance(0.1)
	if session.snapshot().run.wallet.quartz != 8:
		return ["Only the following charge uses the six-second lens, paying again at thirty-three seconds"]
	return []
