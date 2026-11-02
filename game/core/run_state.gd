class_name RunState
extends RefCounted

static func create(seed_value: int, cycle: int = 0) -> Dictionary:
	var wallet: Dictionary = {}
	var produced: Dictionary = {}
	for id in ContentCatalog.RESOURCES:
		wallet[id] = 0.0
		produced[id] = 0.0
	wallet.alloy = 40.0
	return {
		"run_id": "%d-%d" % [seed_value, cycle], "seed": seed_value, "tick": 0,
		"wallet": wallet, "lifetime_produced": produced, "last_collect_tick": -5,
		"stations": {}, "workers": {}, "upgrades": {}, "goals": {},
		"finds": {}, "project_stages": {}, "beam_target": "",
		"oil_boost_target": "", "oil_boost_enabled": false,
		"generator_enabled": false,
	}
