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

# Net station budget: ship service and the standing main-beam reserve are already excluded.
const EMERGENCY_POWER: float = 2.0
const RELAY_RANGE: float = 160.0
const RELAY_POWER: float = 0.25
const PORT_POWER: float = 0.75
const BEAM_RESERVED_POWER: float = 0.25
const BEAM_TARGETS: Array[String] = ["port", "oil", "quartz"]
const PORT_BEAM_LOADING_SPEED: float = 2.0
const MAX_POWER_REQUEST: float = 2.0
const MIN_PRIORITY: int = -100
const MAX_PRIORITY: int = 100
const REGIONS: Dictionary = {
	"ship": {"name": "Плавучий маяк", "position": [0.0, 0.0]},
	"port": {"name": "Кладбище кораблей", "position": [160.0, 0.0]},
	"oil": {"name": "Масляные болота", "position": [0.0, 160.0]},
	"quartz": {"name": "Кварцевые рифы", "position": [320.0, 0.0]},
	"coastal": {"name": "Береговая башня", "position": [480.0, 0.0]},
}
const RELAY_PRICES: Dictionary = {"port": 10.0, "oil": 10.0, "quartz": 12.0, "coastal": 16.0}

static func port_price(run: Dictionary) -> float:
	return PORT_PRICE - (float(RELAY_PRICES.port) if run.relays.has("port") else 0.0)

static func worker_price(worker_count: int) -> float:
	return ceilf(WORKER_BASE_PRICE * pow(WORKER_PRICE_GROWTH, maxi(0, worker_count - 1)))
