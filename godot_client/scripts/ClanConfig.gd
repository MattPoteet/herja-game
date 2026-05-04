extends RefCounted

# Clan constants live here so economy, perk strength, war limits, and battle
# rewards can be tuned without rewriting the clan service or UI.
const CLAN_CREATE_COST: int = 10000
const MAX_CLAN_MEMBERS: int = 100
const MIN_CLAN_NAME_LENGTH: int = 3
const MAX_CLAN_NAME_LENGTH: int = 24
const MAX_ACTIVE_WARS: int = 3
const BATTLE_PREP_SECONDS: int = 1800
const BATTLE_DURATION_SECONDS: int = 900
const BATTLE_POINTS_PER_KILL: int = 1
const BATTLE_MAX_PARTICIPANTS_PER_CLAN: int = 50
const WINNER_XP_REWARD: int = 650
const WINNER_GOLD_REWARD: int = 300
const LOSER_XP_REWARD: int = 250
const LOSER_GOLD_REWARD: int = 90
const WINNER_REPUTATION_REWARD: int = 25
const LOSER_REPUTATION_REWARD: int = 8

const PERKS: Dictionary = {
	"xp_boost": {
		"name": "XP Boost",
		"description": "+5% XP from rewards.",
		"xp_multiplier": 1.05
	},
	"gold_boost": {
		"name": "Gold Boost",
		"description": "+5% gold from rewards.",
		"gold_multiplier": 1.05
	},
	"hit_bonus": {
		"name": "Hit Bonus",
		"description": "+3% combat accuracy/damage.",
		"damage_multiplier": 1.03
	},
	"defense_bonus": {
		"name": "Defense Bonus",
		"description": "+3% damage reduction.",
		"damage_taken_multiplier": 0.97
	},
	"boss_hunter": {
		"name": "Boss Hunter",
		"description": "+3% damage against bosses.",
		"boss_damage_multiplier": 1.03
	}
}

const BLOCKED_NAME_PARTS: Array[String] = ["admin", "mod", "owner", "null", "test"]


static func perk_ids() -> Array[String]:
	var ids: Array[String] = []
	for perk_id in PERKS.keys():
		ids.append(str(perk_id))
	return ids


static func perk_name(perk_id: String) -> String:
	return str((PERKS.get(perk_id, {}) as Dictionary).get("name", "XP Boost"))


static func perk_description(perk_id: String) -> String:
	return str((PERKS.get(perk_id, {}) as Dictionary).get("description", "Small clan bonus."))


static func valid_perk_id(perk_id: String) -> String:
	return perk_id if PERKS.has(perk_id) else "xp_boost"


static func validate_clan_name(raw_name: String) -> Dictionary:
	var clean_name: String = raw_name.strip_edges()
	if clean_name.length() < MIN_CLAN_NAME_LENGTH:
		return {"ok": false, "error": "Clan name must be at least %d characters." % MIN_CLAN_NAME_LENGTH}
	if clean_name.length() > MAX_CLAN_NAME_LENGTH:
		return {"ok": false, "error": "Clan name must be %d characters or less." % MAX_CLAN_NAME_LENGTH}
	var lowered: String = clean_name.to_lower()
	for blocked in BLOCKED_NAME_PARTS:
		if lowered.contains(str(blocked)):
			return {"ok": false, "error": "Choose a different clan name."}
	return {"ok": true, "name": clean_name}


static func get_player_clan_perk(player: Node) -> String:
	if player == null:
		return ""
	var clan: Variant = player.get("clan_data")
	if clan is Dictionary and not (clan as Dictionary).is_empty():
		return valid_perk_id(str((clan as Dictionary).get("perk_type", "")))
	return ""


static func apply_clan_xp_bonus(player: Node, xp_amount: int) -> int:
	var perk: String = get_player_clan_perk(player)
	var data: Dictionary = PERKS.get(perk, {}) as Dictionary
	return int(round(float(xp_amount) * float(data.get("xp_multiplier", 1.0))))


static func apply_clan_gold_bonus(player: Node, gold_amount: int) -> int:
	var perk: String = get_player_clan_perk(player)
	var data: Dictionary = PERKS.get(perk, {}) as Dictionary
	return int(round(float(gold_amount) * float(data.get("gold_multiplier", 1.0))))


static func apply_clan_damage_bonus(player: Node, damage: int, is_boss: bool = false) -> int:
	var perk: String = get_player_clan_perk(player)
	var data: Dictionary = PERKS.get(perk, {}) as Dictionary
	var multiplier: float = float(data.get("damage_multiplier", 1.0))
	if is_boss:
		multiplier *= float(data.get("boss_damage_multiplier", 1.0))
	return max(1, int(round(float(damage) * multiplier)))


static func apply_clan_damage_taken(player: Node, damage: int) -> int:
	var perk: String = get_player_clan_perk(player)
	var data: Dictionary = PERKS.get(perk, {}) as Dictionary
	return max(0, int(round(float(damage) * float(data.get("damage_taken_multiplier", 1.0)))))
