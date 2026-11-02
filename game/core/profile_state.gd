class_name ProfileState
extends RefCounted

static func create(seed_value: int) -> Dictionary:
	return {
		"schema_version": 1, "content_version": 1, "revision": 0,
		"profile_id": "profile-%d-%d" % [seed_value, Time.get_ticks_usec()],
		"meta": {"total_echo": 0, "allocation": {"engineering": 0, "economy": 0, "specialization": 0},
			"claimed_milestone_ids": [], "discovered_locations": ["ship", "port", "oil"],
			"story_flags": [], "cycle_index": 0, "automation_preferences": {}},
		"run": RunState.create(seed_value),
	}
