class_name ContentCatalog
extends RefCounted

const STEP: float = 0.1
const MANUAL_COOLDOWN_TICKS: int = 5
const MAX_CATCHUP_STEPS: int = 10
const BACKGROUND_SECONDS: float = 2.0
const RESOURCES: Array[String] = ["alloy", "oil", "quartz", "biomass", "data", "resonance"]

const PORT_PRICE: float = 20.0
const WORKER_CAPACITY: float = 4.0
const PORT_ROUTES: Dictionary = {
	"near": {"name": "Ближний обломок", "travel_seconds": 2.0, "loading_seconds": 1.0, "cargo_limit": 4.0},
	"far": {"name": "Дальнее судно", "travel_seconds": 3.0, "loading_seconds": 2.0, "cargo_limit": 12.0},
}

const WORKER_BASE_PRICE: float = 12.0
const WORKER_PRICE_GROWTH: float = 1.4

const CARGO_HOLD_PRICE: float = 16.0
const CARGO_HOLD_CAPACITY: float = 8.0

static func worker_price(worker_count: int) -> float:
	return ceilf(WORKER_BASE_PRICE * pow(WORKER_PRICE_GROWTH, maxi(0, worker_count - 1)))
