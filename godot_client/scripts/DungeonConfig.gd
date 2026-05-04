extends RefCounted

# Central dungeon tuning values. Adjust these constants to change rarity,
# tier spacing, enemy scaling, and boss reward odds without touching gameplay code.
const MIN_DUNGEON_LEVEL: int = 10
const TIER_LEVEL_STEP: int = 10
const MAX_RANDOM_TIER: int = 20

const ENTRANCE_SPAWN_CHANCE_PER_TILE: float = 0.08
const MAX_ENTRANCES_PER_REFRESH: int = 2
const ENTRANCE_TAP_RADIUS: float = 150.0
const ENTRANCE_MIN_PLAYER_DISTANCE: float = 360.0
const ENTRANCE_MIN_DISTANCE_FROM_OTHER: float = 520.0

const DUNGEON_WIDTH: float = 980.0
const DUNGEON_HEIGHT: float = 680.0
const DUNGEON_ENEMY_COUNT: int = 6
const DUNGEON_ENEMY_XP_MULTIPLIER: float = 1.65
const DUNGEON_ENEMY_GOLD_MULTIPLIER: float = 1.75
const DUNGEON_ENEMY_HEALTH_MULTIPLIER: float = 1.55
const DUNGEON_ENEMY_ATTACK_MULTIPLIER: float = 1.35
const DUNGEON_ENEMY_BONUS_GEAR_CHANCE: float = 0.10

const BOSS_HEALTH_MULTIPLIER: float = 3.8
const BOSS_ATTACK_MULTIPLIER: float = 2.1
const BOSS_XP_MULTIPLIER: float = 5.0
const BOSS_GOLD_MULTIPLIER: float = 5.5
const BOSS_RARE_DROP_CHANCE: float = 0.36
const BOSS_LEGENDARY_DROP_CHANCE: float = 0.10
const BOSS_USEFUL_ITEM_CHANCE: float = 0.45

const USEFUL_BOSS_ITEMS: Array[String] = [
	"Health Potion",
	"Greater Health Potion",
	"Mead",
	"Rune Tonic",
	"Runed Brooch",
	"Small Gem"
]


static func tier_for_level(level: int) -> int:
	return max(MIN_DUNGEON_LEVEL, int(floor(float(max(1, level)) / float(TIER_LEVEL_STEP))) * TIER_LEVEL_STEP)


static func random_tier_for_seed(seed_value: int) -> int:
	var tier_index: int = int(abs(seed_value) % MAX_RANDOM_TIER) + 1
	return max(MIN_DUNGEON_LEVEL, tier_index * TIER_LEVEL_STEP)


static func dungeon_enemy_names_for_tier(tier: int) -> Array[String]:
	if tier >= 50:
		return ["Frost Troll", "Rune Golem", "Draugr Warrior"]
	if tier >= 30:
		return ["Draugr Warrior", "Frost Troll", "Rune Golem"]
	if tier >= 20:
		return ["Draugr Warrior", "Stone Boar", "Frost Troll"]
	return ["Forest Imp", "Stone Boar", "Draugr Warrior"]
