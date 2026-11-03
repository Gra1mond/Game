class_name FixedClock
extends RefCounted

var _accumulator: float = 0.0

# Frame pacing belongs outside the deterministic simulation. Keep backlog, never multiply payouts.
func frame(session: GameSession, delta: float) -> int:
	if delta >= ContentCatalog.BACKGROUND_SECONDS:
		session.dispatch({"type": "pause", "paused": true})
		_accumulator = 0.0
		return 0
	if session.is_paused():
		return 0
	_accumulator += maxf(delta, 0.0)
	var steps := 0
	while _accumulator + 0.00000001 >= ContentCatalog.STEP and steps < ContentCatalog.MAX_CATCHUP_STEPS:
		_accumulator -= ContentCatalog.STEP
		session.advance(ContentCatalog.STEP)
		steps += 1
	return steps
