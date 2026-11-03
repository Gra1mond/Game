class_name ContentCatalog
extends RefCounted

const STEP: float = 0.1
const MANUAL_COOLDOWN_TICKS: int = 5
const MAX_CATCHUP_STEPS: int = 10
const BACKGROUND_SECONDS: float = 2.0
const RESOURCES: Array[String] = ["alloy", "oil", "quartz", "biomass", "data", "resonance"]

const STATION_PRICES: Dictionary = {"port": 20.0, "oil": 20.0}
const OIL_POWER: float = 0.75
const OIL_PRESSURE_SECONDS: float = 2.0
const OIL_PUMP_SECONDS: float = 2.0
const OIL_BATCH: float = 4.0
const OIL_OVERDRIVE_PUMP_SECONDS: float = 1.0
const OIL_OVERDRIVE_BATCH: float = 6.0
const OIL_HEAT_PER_BATCH: float = 20.0
const OIL_HEAT_LIMIT: float = 60.0
const OIL_COOLING_RATE: float = 10.0
const OIL_STEADY_COOLING_RATE: float = 5.0
const OIL_BEAM_PRESSURE_SPEED: float = 2.0
const GENERATOR_PRICE: float = 12.0
const GENERATOR_CAPACITY: float = 2.0
const GENERATOR_OIL_PER_SECOND: float = 0.5
const OIL_BOOST_PER_SECOND: float = 0.5
const OIL_BOOST_BONUS: float = 0.5
const QUARTZ_DRILL_PRICE: float = 20.0
const QUARTZ_PRICE_GROWTH: float = 1.5
const QUARTZ_POWER: float = 1.0
const QUARTZ_CHARGE_SECONDS: float = 8.0
const QUARTZ_FRACTURE_SECONDS: float = 1.0
const QUARTZ_COOLING_SECONDS: float = 4.0
const QUARTZ_BATCH: float = 4.0
const QUARTZ_UNLOCK_PRODUCTION: Dictionary = {"alloy": 8.0, "oil": 8.0}
const QUARTZ_BEAM_CHARGE_SPEED: float = 2.0
const QUARTZ_LENS_PRICE: float = 4.0
const QUARTZ_LENS_CHARGE_SECONDS: float = 6.0
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

static func station_price(run: Dictionary, region: String) -> float:
	if region == "quartz":
		return ceilf(QUARTZ_DRILL_PRICE * pow(QUARTZ_PRICE_GROWTH, quartz_count(run))) + (0.0 if run.relays.has("quartz") else float(RELAY_PRICES.quartz))
	return float(STATION_PRICES[region]) - (float(RELAY_PRICES[region]) if run.relays.has(region) else 0.0)

static func worker_price(worker_count: int) -> float:
	return ceilf(WORKER_BASE_PRICE * pow(WORKER_PRICE_GROWTH, maxi(0, worker_count - 1)))

static func quartz_count(run: Dictionary) -> int:
	var count := 0
	for id: String in run.stations:
		if run.stations[id].kind == "quartz":
			count += 1
	return count
