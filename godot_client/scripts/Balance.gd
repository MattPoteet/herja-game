extends RefCounted

const BASE_PLAYER_ATTACK: int = 12
const BASE_PLAYER_MAX_HP: int = 100
const XP_BASE_REQUIRED: int = 100
const XP_LEVEL_MULTIPLIER: int = 100
const LEVEL_MAX_HP_GAIN: int = 10
const LEVEL_ATTACK_GAIN: int = 2
const MAX_ACTIVE_ENEMIES: int = 18
const INITIAL_ENEMY_COUNT: int = 12
const ENEMY_RESPAWN_SECONDS: float = 4.5
const ENEMY_MIN_SPAWN_DISTANCE: float = 180.0

const CHARACTER_DAMAGE_MULTIPLIERS: Dictionary = {
	"viking": 1.0,
	"shield_maiden": 0.5,
	"druid": 0.85,
	"mage": 0.75
}

const CHARACTER_ATTACK_RANGES: Dictionary = {
	"viking": 70.0,
	"shield_maiden": 80.0,
	"druid": 72.0,
	"mage": 78.0
}

const POTION_HEALING: Dictionary = {
	"Health Potion": 35,
	"Greater Health Potion": 75,
	"Mead": 20
}

const CONSUMABLE_XP: Dictionary = {
	"Rune Tonic": 45
}

const EQUIPMENT_SLOTS: Array[String] = ["weapon", "armor", "trinket"]
const RARITY_ORDER: Dictionary = {
	"common": 0,
	"rare": 1,
	"legendary": 2
}

const RARITY_DROP_WEIGHTS: Dictionary = {
	"common": 78,
	"rare": 18,
	"legendary": 4
}

const GEAR_ITEMS: Dictionary = {
	"Common Viking Axe": {
		"slot": "weapon",
		"class": "viking",
		"rarity": "common",
		"level": 1,
		"icon": 0,
		"attack": 3,
		"defense": 0,
		"description": "A sturdy starter axe for Viking fighters."
	},
	"Rare Viking Axe": {
		"slot": "weapon",
		"class": "viking",
		"rarity": "rare",
		"level": 3,
		"icon": 1,
		"attack": 7,
		"defense": 0,
		"description": "A sharpened axe marked with blue steelwork."
	},
	"Legendary Viking Axe": {
		"slot": "weapon",
		"class": "viking",
		"rarity": "legendary",
		"level": 6,
		"icon": 2,
		"attack": 13,
		"defense": 1,
		"description": "A gold-inlaid axe carrying old saga power."
	},
	"Rare Viking Sword": {
		"slot": "weapon",
		"class": "viking",
		"rarity": "rare",
		"level": 10,
		"icon": 1,
		"attack": 16,
		"defense": 1,
		"description": "A dungeon-forged sword balanced for close Viking fights."
	},
	"Legendary Viking Sword": {
		"slot": "weapon",
		"class": "viking",
		"rarity": "legendary",
		"level": 20,
		"icon": 2,
		"attack": 28,
		"defense": 3,
		"description": "A saga blade recovered from a boss hoard."
	},
	"Common Shield Maiden Bow": {
		"slot": "weapon",
		"class": "shield_maiden",
		"rarity": "common",
		"level": 1,
		"icon": 3,
		"attack": 2,
		"defense": 0,
		"description": "A simple hunting bow fitted for quick shots."
	},
	"Rare Shield Maiden Bow": {
		"slot": "weapon",
		"class": "shield_maiden",
		"rarity": "rare",
		"level": 3,
		"icon": 4,
		"attack": 5,
		"defense": 1,
		"description": "A balanced silver bow with a clean draw."
	},
	"Legendary Shield Maiden Bow": {
		"slot": "weapon",
		"class": "shield_maiden",
		"rarity": "legendary",
		"level": 6,
		"icon": 5,
		"attack": 10,
		"defense": 2,
		"description": "An ornate bow built for long-range legends."
	},
	"Rare Shield Maiden Spear": {
		"slot": "weapon",
		"class": "shield_maiden",
		"rarity": "rare",
		"level": 10,
		"icon": 4,
		"attack": 13,
		"defense": 3,
		"description": "A guarded spear for shield maiden dungeon runs."
	},
	"Legendary Shield Maiden Spear": {
		"slot": "weapon",
		"class": "shield_maiden",
		"rarity": "legendary",
		"level": 20,
		"icon": 5,
		"attack": 24,
		"defense": 6,
		"description": "A boss-forged spear with shield runes along the haft."
	},
	"Common Druid Staff": {
		"slot": "weapon",
		"class": "druid",
		"rarity": "common",
		"level": 1,
		"icon": 6,
		"attack": 2,
		"defense": 1,
		"description": "A living branch staff with a small green charm."
	},
	"Rare Druid Staff": {
		"slot": "weapon",
		"class": "druid",
		"rarity": "rare",
		"level": 3,
		"icon": 7,
		"attack": 5,
		"defense": 2,
		"description": "A silver-bound staff with stronger nature magic."
	},
	"Legendary Druid Staff": {
		"slot": "weapon",
		"class": "druid",
		"rarity": "legendary",
		"level": 6,
		"icon": 8,
		"attack": 10,
		"defense": 4,
		"description": "A golden elder staff wrapped in rune vines."
	},
	"Rare Druid Spear": {
		"slot": "weapon",
		"class": "druid",
		"rarity": "rare",
		"level": 10,
		"icon": 7,
		"attack": 13,
		"defense": 4,
		"description": "A greenwood spear carved with stag-bone charms."
	},
	"Legendary Druid Spear": {
		"slot": "weapon",
		"class": "druid",
		"rarity": "legendary",
		"level": 20,
		"icon": 8,
		"attack": 24,
		"defense": 8,
		"description": "An elder spear carrying deep forest magic."
	},
	"Common Mage Wand": {
		"slot": "weapon",
		"class": "mage",
		"rarity": "common",
		"level": 1,
		"icon": 9,
		"attack": 2,
		"defense": 0,
		"description": "A plain wand capped with a raw crystal."
	},
	"Rare Mage Wand": {
		"slot": "weapon",
		"class": "mage",
		"rarity": "rare",
		"level": 3,
		"icon": 10,
		"attack": 6,
		"defense": 1,
		"description": "A refined wand with a bright blue focus."
	},
	"Legendary Mage Wand": {
		"slot": "weapon",
		"class": "mage",
		"rarity": "legendary",
		"level": 6,
		"icon": 11,
		"attack": 12,
		"defense": 1,
		"description": "A jewel-headed wand burning with arcane force."
	},
	"Rare Mage Fire Staff": {
		"slot": "weapon",
		"class": "mage",
		"rarity": "rare",
		"level": 10,
		"icon": 10,
		"attack": 15,
		"defense": 1,
		"description": "A wolf-pelt staff tuned for stronger fireballs."
	},
	"Legendary Mage Fire Staff": {
		"slot": "weapon",
		"class": "mage",
		"rarity": "legendary",
		"level": 20,
		"icon": 11,
		"attack": 27,
		"defense": 2,
		"description": "A boss relic staff with a burning rune focus."
	},
	"Common Viking Armor": {
		"slot": "armor",
		"class": "viking",
		"rarity": "common",
		"level": 1,
		"icon": 12,
		"attack": 0,
		"defense": 3,
		"description": "Fur-lined mail for close fighting."
	},
	"Rare Viking Armor": {
		"slot": "armor",
		"class": "viking",
		"rarity": "rare",
		"level": 3,
		"icon": 13,
		"attack": 1,
		"defense": 7,
		"description": "Reinforced mail with polished iron plates."
	},
	"Legendary Viking Armor": {
		"slot": "armor",
		"class": "viking",
		"rarity": "legendary",
		"level": 6,
		"icon": 14,
		"attack": 3,
		"defense": 13,
		"description": "Saga armor fit for a battle-chief."
	},
	"Common Shield Maiden Armor": {
		"slot": "armor",
		"class": "shield_maiden",
		"rarity": "common",
		"level": 1,
		"icon": 15,
		"attack": 0,
		"defense": 2,
		"description": "Light armor that keeps movement quick."
	},
	"Rare Shield Maiden Armor": {
		"slot": "armor",
		"class": "shield_maiden",
		"rarity": "rare",
		"level": 3,
		"icon": 16,
		"attack": 1,
		"defense": 5,
		"description": "Blue-trimmed armor built for archers."
	},
	"Legendary Shield Maiden Armor": {
		"slot": "armor",
		"class": "shield_maiden",
		"rarity": "legendary",
		"level": 6,
		"icon": 17,
		"attack": 2,
		"defense": 10,
		"description": "Golden battle armor for a legendary archer."
	},
	"Common Druid Armor": {
		"slot": "armor",
		"class": "druid",
		"rarity": "common",
		"level": 1,
		"icon": 18,
		"attack": 0,
		"defense": 2,
		"description": "Leaf-wrapped robes and hardened hide."
	},
	"Rare Druid Armor": {
		"slot": "armor",
		"class": "druid",
		"rarity": "rare",
		"level": 3,
		"icon": 19,
		"attack": 1,
		"defense": 6,
		"description": "Blue-green robes strengthened by nature runes."
	},
	"Legendary Druid Armor": {
		"slot": "armor",
		"class": "druid",
		"rarity": "legendary",
		"level": 6,
		"icon": 20,
		"attack": 2,
		"defense": 11,
		"description": "Elder vestments rooted in ancient magic."
	},
	"Common Mage Robe": {
		"slot": "armor",
		"class": "mage",
		"rarity": "common",
		"level": 1,
		"icon": 21,
		"attack": 1,
		"defense": 1,
		"description": "A plain robe with stitched blue trim."
	},
	"Rare Mage Robe": {
		"slot": "armor",
		"class": "mage",
		"rarity": "rare",
		"level": 3,
		"icon": 22,
		"attack": 2,
		"defense": 4,
		"description": "A silver-lined robe that holds spell energy."
	},
	"Legendary Mage Robe": {
		"slot": "armor",
		"class": "mage",
		"rarity": "legendary",
		"level": 6,
		"icon": 23,
		"attack": 5,
		"defense": 8,
		"description": "A royal robe woven with violet arcane thread."
	},
	"Rusty Axe": {
		"slot": "weapon",
		"class": "viking",
		"rarity": "common",
		"level": 1,
		"icon": 0,
		"attack": 3,
		"defense": 0,
		"description": "Legacy axe. Same stats as a common Viking axe."
	},
	"Bone Charm": {
		"slot": "trinket",
		"class": "any",
		"rarity": "common",
		"level": 1,
		"icon": -1,
		"attack": 1,
		"defense": 1,
		"description": "A small charm that steadies your strikes."
	},
	"Iron Armguard": {
		"slot": "armor",
		"class": "any",
		"rarity": "common",
		"level": 1,
		"icon": -1,
		"attack": 0,
		"defense": 3,
		"description": "A simple iron guard that reduces incoming damage."
	},
	"Runed Brooch": {
		"slot": "trinket",
		"class": "any",
		"rarity": "rare",
		"level": 3,
		"icon": -1,
		"attack": 2,
		"defense": 2,
		"description": "A rune-marked brooch humming with quiet power."
	}
}

const ENEMY_STATS: Dictionary = {
	"Wild Wisp": {
		"weight": 48,
		"min_level": 1,
		"max_level": 4,
		"hp": 24,
		"attack": 3,
		"xp": 18,
		"gold": 3,
		"move_speed": 56.0,
		"chase_range": 260.0,
		"attack_range": 34.0,
		"preferred_range": 30.0,
		"attack_cooldown": 1.15,
		"lunge_distance": 8.0,
		"gear_chance": 0.08,
		"loot": ["Herb", "Herb", "Small Gem", "Rune Dust", "Crystal Vial", "", ""]
	},
	"Forest Imp": {
		"weight": 34,
		"min_level": 1,
		"max_level": 6,
		"hp": 40,
		"attack": 6,
		"xp": 34,
		"gold": 6,
		"move_speed": 48.0,
		"chase_range": 240.0,
		"attack_range": 36.0,
		"preferred_range": 32.0,
		"attack_cooldown": 1.45,
		"lunge_distance": 12.0,
		"gear_chance": 0.12,
		"loot": ["Herb", "Wood", "Mushroom", "Fur", "Stone", "Crystal Vial", ""]
	},
	"Stone Boar": {
		"weight": 18,
		"min_level": 2,
		"max_level": 8,
		"hp": 64,
		"attack": 10,
		"xp": 55,
		"gold": 11,
		"move_speed": 38.0,
		"chase_range": 220.0,
		"attack_range": 42.0,
		"preferred_range": 38.0,
		"attack_cooldown": 2.0,
		"lunge_distance": 20.0,
		"gear_chance": 0.16,
		"loot": ["Bone Charm", "Iron Ore", "Small Gem", "Stone", "Rune Dust", "Crystal Vial", ""]
	},
	"Draugr Warrior": {
		"weight": 28,
		"min_level": 3,
		"max_level": 12,
		"hp": 92,
		"attack": 15,
		"xp": 86,
		"gold": 18,
		"move_speed": 44.0,
		"chase_range": 260.0,
		"attack_range": 48.0,
		"preferred_range": 42.0,
		"attack_cooldown": 1.55,
		"lunge_distance": 18.0,
		"gear_chance": 0.22,
		"loot": ["Iron Ore", "Bone Charm", "Runed Brooch", "Rune Dust", "Small Gem", ""]
	},
	"Frost Troll": {
		"weight": 18,
		"min_level": 5,
		"max_level": 18,
		"hp": 155,
		"attack": 22,
		"xp": 145,
		"gold": 32,
		"move_speed": 34.0,
		"chase_range": 250.0,
		"attack_range": 56.0,
		"preferred_range": 50.0,
		"attack_cooldown": 2.1,
		"lunge_distance": 26.0,
		"gear_chance": 0.28,
		"loot": ["Fur", "Iron Ore", "Crystal Vial", "Small Gem", "Rune Dust", "Runed Brooch", ""]
	},
	"Rune Golem": {
		"weight": 12,
		"min_level": 8,
		"max_level": 99,
		"hp": 240,
		"attack": 32,
		"xp": 240,
		"gold": 55,
		"move_speed": 28.0,
		"chase_range": 230.0,
		"attack_range": 62.0,
		"preferred_range": 56.0,
		"attack_cooldown": 2.45,
		"lunge_distance": 18.0,
		"gear_chance": 0.36,
		"loot": ["Runed Brooch", "Small Gem", "Rune Dust", "Crystal Vial", "Iron Ore", ""]
	}
}


static func xp_required_for_level(level: int) -> int:
	return max(XP_BASE_REQUIRED, max(1, level) * XP_LEVEL_MULTIPLIER)


static func max_hp_gain_for_level(_level: int) -> int:
	return LEVEL_MAX_HP_GAIN


static func attack_gain_for_level(_level: int) -> int:
	return LEVEL_ATTACK_GAIN


static func attack_range_for_character(character_id: String) -> float:
	return float(CHARACTER_ATTACK_RANGES.get(character_id, CHARACTER_ATTACK_RANGES["viking"]))


static func damage_for_character(character_id: String, base_damage: int) -> int:
	var multiplier: float = float(CHARACTER_DAMAGE_MULTIPLIERS.get(character_id, 1.0))
	return max(1, int(round(float(base_damage) * multiplier)))


static func potion_healing(item_name: String) -> int:
	return int(POTION_HEALING.get(item_name, 0))


static func consumable_xp(item_name: String) -> int:
	return int(CONSUMABLE_XP.get(item_name, 0))


static func potion_description(item_name: String) -> String:
	var healing: int = potion_healing(item_name)
	if healing <= 0:
		return ""
	return "Restores %d HP when used." % healing


static func consumable_description(item_name: String) -> String:
	var healing: int = potion_healing(item_name)
	var xp: int = consumable_xp(item_name)
	var parts: Array[String] = []
	if healing > 0:
		parts.append("restores %d HP" % healing)
	if xp > 0:
		parts.append("grants %d XP" % xp)
	if parts.is_empty():
		return ""
	var description: String = " and ".join(parts)
	return "%s%s when used." % [description.substr(0, 1).to_upper(), description.substr(1)]


static func equipment_slots() -> Array[String]:
	return EQUIPMENT_SLOTS.duplicate()


static func is_gear(item_name: String) -> bool:
	return GEAR_ITEMS.has(item_name)


static func gear_data(item_name: String) -> Dictionary:
	return (GEAR_ITEMS.get(item_name, {}) as Dictionary).duplicate(true)


static func gear_slot(item_name: String) -> String:
	return str(gear_data(item_name).get("slot", ""))


static func gear_attack(item_name: String) -> int:
	return int(gear_data(item_name).get("attack", 0))


static func gear_defense(item_name: String) -> int:
	return int(gear_data(item_name).get("defense", 0))


static func gear_level(item_name: String) -> int:
	return int(gear_data(item_name).get("level", 1))


static func gear_class(item_name: String) -> String:
	return str(gear_data(item_name).get("class", "any"))


static func gear_rarity(item_name: String) -> String:
	return str(gear_data(item_name).get("rarity", "common"))


static func gear_icon_index(item_name: String) -> int:
	return int(gear_data(item_name).get("icon", -1))


static func can_equip_gear(item_name: String, character_id: String, level: int) -> bool:
	if not is_gear(item_name):
		return false
	var required_class: String = gear_class(item_name)
	if required_class != "any" and required_class != character_id:
		return false
	return level >= gear_level(item_name)


static func gear_description(item_name: String) -> String:
	var data: Dictionary = gear_data(item_name)
	if data.is_empty():
		return ""
	var parts: Array[String] = []
	var required_class: String = str(data.get("class", "any"))
	var required_level: int = int(data.get("level", 1))
	if required_class != "any":
		parts.append(_class_display(required_class))
	parts.append(str(data.get("rarity", "common")).capitalize())
	parts.append("Lv %d" % required_level)
	var attack: int = int(data.get("attack", 0))
	var defense: int = int(data.get("defense", 0))
	if attack != 0:
		parts.append("+%d attack" % attack)
	if defense != 0:
		parts.append("+%d defense" % defense)
	return "%s %s." % [str(data.get("description", "Gear item.")), " | ".join(parts)]


static func random_enemy_loot(enemy_name: String, player_level: int, character_id: String) -> String:
	var data: Dictionary = enemy_data(enemy_name)
	var gear_chance: float = float(data.get("gear_chance", 0.0))
	if randf() <= gear_chance:
		var gear: String = random_gear_for_level(player_level, character_id)
		if gear != "":
			return gear
	var raw_loot: Variant = data.get("loot", [])
	if raw_loot is Array and not (raw_loot as Array).is_empty():
		return str((raw_loot as Array).pick_random())
	return ""


static func random_gear_for_level(player_level: int, character_id: String) -> String:
	var candidates_by_rarity: Dictionary = {
		"common": [],
		"rare": [],
		"legendary": []
	}
	for item_name in GEAR_ITEMS.keys():
		var name: String = str(item_name)
		var data: Dictionary = gear_data(name)
		if str(data.get("slot", "")) == "trinket":
			continue
		if int(data.get("level", 1)) > player_level:
			continue
		var required_class: String = str(data.get("class", "any"))
		if required_class != "any" and required_class != character_id:
			continue
		var rarity: String = str(data.get("rarity", "common"))
		if candidates_by_rarity.has(rarity):
			(candidates_by_rarity[rarity] as Array).append(name)

	var available_rarities: Array[String] = []
	var total_weight: int = 0
	for rarity in RARITY_DROP_WEIGHTS.keys():
		if (candidates_by_rarity[str(rarity)] as Array).is_empty():
			continue
		available_rarities.append(str(rarity))
		total_weight += int(RARITY_DROP_WEIGHTS[rarity])
	if available_rarities.is_empty():
		return ""

	var roll: int = randi_range(1, max(1, total_weight))
	var running: int = 0
	for rarity in available_rarities:
		running += int(RARITY_DROP_WEIGHTS[rarity])
		if roll <= running:
			return str((candidates_by_rarity[rarity] as Array).pick_random())
	return str((candidates_by_rarity[available_rarities[0]] as Array).pick_random())


static func enemy_names() -> Array:
	return ENEMY_STATS.keys()


static func enemy_data(enemy_name: String) -> Dictionary:
	var data: Variant = ENEMY_STATS.get(enemy_name, ENEMY_STATS["Wild Wisp"])
	return (data as Dictionary).duplicate(true)


static func random_enemy_name() -> String:
	return random_enemy_name_for_level(1)


static func random_enemy_name_for_level(player_level: int) -> String:
	var level: int = max(1, player_level)
	var total_weight: int = 0
	for enemy_name in ENEMY_STATS.keys():
		var data: Dictionary = ENEMY_STATS[enemy_name] as Dictionary
		if not _enemy_available_for_level(data, level):
			continue
		total_weight += int(data.get("weight", 1))
	var roll: int = randi_range(1, max(1, total_weight))
	var running: int = 0
	for enemy_name in ENEMY_STATS.keys():
		var data: Dictionary = ENEMY_STATS[enemy_name] as Dictionary
		if not _enemy_available_for_level(data, level):
			continue
		running += int(data.get("weight", 1))
		if roll <= running:
			return str(enemy_name)
	return "Wild Wisp"


static func _enemy_available_for_level(data: Dictionary, player_level: int) -> bool:
	var min_level: int = int(data.get("min_level", 1))
	var max_level: int = int(data.get("max_level", 99))
	return player_level >= min_level and player_level <= max_level


static func _class_display(character_id: String) -> String:
	match character_id:
		"shield_maiden": return "Shield Maiden"
		"druid": return "Druid"
		"mage": return "Mage"
		_: return "Viking"
