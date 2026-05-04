extends RefCounted

const Balance = preload("res://scripts/Balance.gd")
const DungeonConfig = preload("res://scripts/DungeonConfig.gd")


static func boss_reward_for_player(player: Node, tier: int) -> Dictionary:
	var level: int = tier
	var character_id: String = "viking"
	if player != null:
		if player.get("stats") is Dictionary:
			level = max(tier, int((player.get("stats") as Dictionary).get("level", tier)))
		character_id = str(player.get("character_id"))

	var base_xp: int = 65 + tier * 12
	var base_gold: int = 12 + tier * 3
	var reward: Dictionary = {
		"xp": int(round(float(base_xp) * DungeonConfig.BOSS_XP_MULTIPLIER)),
		"gold": int(round(float(base_gold) * DungeonConfig.BOSS_GOLD_MULTIPLIER)),
		"item": ""
	}

	var roll: float = randf()
	if roll <= DungeonConfig.BOSS_LEGENDARY_DROP_CHANCE:
		reward["item"] = class_weapon_for_rarity(character_id, level, "legendary")
	elif roll <= DungeonConfig.BOSS_LEGENDARY_DROP_CHANCE + DungeonConfig.BOSS_RARE_DROP_CHANCE:
		reward["item"] = class_weapon_for_rarity(character_id, level, "rare")
	elif randf() <= DungeonConfig.BOSS_USEFUL_ITEM_CHANCE:
		reward["item"] = str(DungeonConfig.USEFUL_BOSS_ITEMS.pick_random())

	return reward


static func class_weapon_for_rarity(character_id: String, player_level: int, rarity: String) -> String:
	var candidates: Array[String] = []
	for item_name in Balance.GEAR_ITEMS.keys():
		var name: String = str(item_name)
		if Balance.gear_slot(name) != "weapon":
			continue
		if Balance.gear_rarity(name) != rarity:
			continue
		if Balance.gear_level(name) > player_level:
			continue
		var required_class: String = Balance.gear_class(name)
		if required_class != "any" and required_class != character_id:
			continue
		candidates.append(name)
	if candidates.is_empty() and rarity != "rare":
		return class_weapon_for_rarity(character_id, player_level, "rare")
	if candidates.is_empty():
		return Balance.random_gear_for_level(player_level, character_id)
	return str(candidates.pick_random())
