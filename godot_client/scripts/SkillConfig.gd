extends RefCounted

const SKILL_POINTS_PER_LEVEL: int = 1
const RESPEC_ENABLED: bool = true
const RESPEC_GOLD_COST: int = 500

const SKILL_TYPE_PASSIVE: String = "passive"
const SKILL_TYPE_ACTIVE: String = "active"
const SKILL_TYPE_SPECIAL: String = "special"
const SKILL_TYPE_CAPSTONE: String = "capstone"

const CLASS_SKILLS: Dictionary = {
	"viking": [
		{"id": "warriors_strength", "name": "Raider's Strength", "description": "+3 melee damage per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 2, "prerequisites": {}, "effects": {"attack": 3}, "cooldown": 0.0, "x": 0, "y": 0},
		{"id": "iron_skin", "name": "Iron Hide", "description": "+2 armor defense per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 3, "prerequisites": {}, "effects": {"defense": 2}, "cooldown": 0.0, "x": 1, "y": 0},
		{"id": "battle_hunger", "name": "Battle Hunger", "description": "Viking kill-sustain bonus for later heal hooks.", "type": "passive", "max_rank": 2, "cost": 1, "required_level": 5, "prerequisites": {"warriors_strength": 1}, "effects": {"kill_heal": 4}, "cooldown": 0.0, "x": 0, "y": 1},
		{"id": "axe_mastery", "name": "Axe Mastery", "description": "+4 axe and sword damage per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 6, "prerequisites": {"warriors_strength": 2}, "effects": {"attack": 4}, "cooldown": 0.0, "x": 0, "y": 2},
		{"id": "berserker_endurance", "name": "Berserker Endurance", "description": "+12 max HP per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 7, "prerequisites": {"iron_skin": 1}, "effects": {"max_hp": 12}, "cooldown": 0.0, "x": 1, "y": 1},
		{"id": "cleave", "name": "Axe Cleave", "description": "Active: sweep your weapon into nearby enemies.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 4, "prerequisites": {}, "effects": {"area_damage_multiplier": 0.70}, "cooldown": 8.0, "x": 2, "y": 0},
		{"id": "shield_breaker", "name": "Skull Splitter", "description": "Active: heavy Viking strike on one enemy.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 8, "prerequisites": {"cleave": 1}, "effects": {"single_damage_multiplier": 1.45}, "cooldown": 12.0, "x": 2, "y": 1},
		{"id": "war_cry", "name": "War Cry", "description": "Active: intimidate enemies and trigger a battle shout.", "type": "active", "max_rank": 1, "cost": 1, "required_level": 10, "prerequisites": {"warriors_strength": 2}, "effects": {"temporary_attack": 6, "duration": 8.0}, "cooldown": 25.0, "x": 2, "y": 2},
		{"id": "berserker_charge", "name": "Berserker Charge", "description": "Special: surge forward in a brutal area attack.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 14, "prerequisites": {"shield_breaker": 1}, "effects": {"area_damage_multiplier": 1.20}, "cooldown": 35.0, "x": 3, "y": 1},
		{"id": "odins_wrath", "name": "Odin's Wrath", "description": "Special: call down a saga-worthy area strike.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 18, "prerequisites": {"berserker_charge": 1}, "effects": {"area_damage_multiplier": 1.80}, "cooldown": 55.0, "x": 4, "y": 1},
		{"id": "wrath_of_the_north", "name": "Wrath of the North", "description": "Capstone: elite Viking damage and defense.", "type": "capstone", "max_rank": 1, "cost": 1, "required_level": 25, "prerequisites": {"odins_wrath": 1, "berserker_endurance": 2}, "effects": {"attack": 10, "defense": 6}, "cooldown": 90.0, "x": 5, "y": 1}
	],
	"mage": [
		{"id": "arcane_focus", "name": "Arcane Focus", "description": "+3 spell damage per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 2, "prerequisites": {}, "effects": {"attack": 3}, "cooldown": 0.0, "x": 0, "y": 0},
		{"id": "mana_flow", "name": "Rune Channeling", "description": "Reduces spell cooldowns slightly.", "type": "passive", "max_rank": 2, "cost": 1, "required_level": 4, "prerequisites": {}, "effects": {"cooldown_multiplier": 0.94}, "cooldown": 0.0, "x": 1, "y": 0},
		{"id": "elemental_mastery", "name": "Elemental Mastery", "description": "+4 fire, frost, and lightning damage per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 6, "prerequisites": {"arcane_focus": 1}, "effects": {"attack": 4}, "cooldown": 0.0, "x": 0, "y": 1},
		{"id": "spell_precision", "name": "Spell Precision", "description": "+2 precise spell damage per rank.", "type": "passive", "max_rank": 2, "cost": 1, "required_level": 7, "prerequisites": {"arcane_focus": 1}, "effects": {"attack": 2}, "cooldown": 0.0, "x": 1, "y": 1},
		{"id": "mystic_shielding", "name": "Mystic Shielding", "description": "+2 magical defense per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 8, "prerequisites": {}, "effects": {"defense": 2}, "cooldown": 0.0, "x": 1, "y": 2},
		{"id": "fireball", "name": "Fireball", "description": "Active: focused fire projectile.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 3, "prerequisites": {}, "effects": {"single_damage_multiplier": 1.25}, "cooldown": 7.0, "x": 2, "y": 0},
		{"id": "frost_nova", "name": "Frost Nova", "description": "Active: frost burst around the mage.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 9, "prerequisites": {"fireball": 1}, "effects": {"area_damage_multiplier": 0.90}, "cooldown": 16.0, "x": 2, "y": 1},
		{"id": "chain_lightning", "name": "Chain Lightning", "description": "Active: lightning arcs through nearby enemies.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 12, "prerequisites": {"elemental_mastery": 1}, "effects": {"area_damage_multiplier": 1.10}, "cooldown": 20.0, "x": 3, "y": 1},
		{"id": "meteor_strike", "name": "Meteor Strike", "description": "Special: heavy area fire impact.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 16, "prerequisites": {"chain_lightning": 1}, "effects": {"area_damage_multiplier": 1.70}, "cooldown": 45.0, "x": 4, "y": 1},
		{"id": "blizzard", "name": "Blizzard", "description": "Special: wide frost storm damage.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 20, "prerequisites": {"frost_nova": 1}, "effects": {"area_damage_multiplier": 1.55}, "cooldown": 50.0, "x": 4, "y": 2},
		{"id": "archmage_ascension", "name": "Archmage Ascension", "description": "Capstone: major spell power and faster casting.", "type": "capstone", "max_rank": 1, "cost": 1, "required_level": 25, "prerequisites": {"meteor_strike": 1, "blizzard": 1}, "effects": {"attack": 12, "cooldown_multiplier": 0.85}, "cooldown": 90.0, "x": 5, "y": 1}
	],
	"druid": [
		{"id": "natures_blessing", "name": "Nature's Blessing", "description": "+5% nature healing per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 2, "prerequisites": {}, "effects": {"healing_multiplier": 1.05}, "cooldown": 0.0, "x": 0, "y": 0},
		{"id": "thorn_skin", "name": "Thorn Skin", "description": "+2 barkskin defense per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 4, "prerequisites": {}, "effects": {"defense": 2}, "cooldown": 0.0, "x": 1, "y": 0},
		{"id": "wild_growth", "name": "Wild Growth", "description": "+10 max HP per rank from nature vitality.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 5, "prerequisites": {"natures_blessing": 1}, "effects": {"max_hp": 10}, "cooldown": 0.0, "x": 0, "y": 1},
		{"id": "spirit_bond", "name": "Stag Spirit Bond", "description": "+3 nature spear and spirit damage per rank.", "type": "passive", "max_rank": 2, "cost": 1, "required_level": 7, "prerequisites": {}, "effects": {"attack": 3}, "cooldown": 0.0, "x": 1, "y": 1},
		{"id": "herbal_wisdom", "name": "Herbal Wisdom", "description": "Improves healing and potion-focused druid play.", "type": "passive", "max_rank": 2, "cost": 1, "required_level": 8, "prerequisites": {"natures_blessing": 1}, "effects": {"healing_multiplier": 1.10}, "cooldown": 0.0, "x": 1, "y": 2},
		{"id": "root_snare", "name": "Root Snare", "description": "Active: lash a target with roots.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 3, "prerequisites": {}, "effects": {"single_damage_multiplier": 1.05}, "cooldown": 9.0, "x": 2, "y": 0},
		{"id": "healing_bloom", "name": "Healing Bloom", "description": "Active: bloom life magic to heal yourself.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 6, "prerequisites": {"natures_blessing": 1}, "effects": {"heal": 34}, "cooldown": 18.0, "x": 2, "y": 1},
		{"id": "poison_spores", "name": "Poison Spores", "description": "Active: burst poisonous spores around you.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 10, "prerequisites": {"root_snare": 1}, "effects": {"area_damage_multiplier": 0.85}, "cooldown": 16.0, "x": 3, "y": 1},
		{"id": "entangling_forest", "name": "Entangling Forest", "description": "Special: summon roots for area nature damage.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 15, "prerequisites": {"poison_spores": 1}, "effects": {"area_damage_multiplier": 1.30}, "cooldown": 42.0, "x": 4, "y": 1},
		{"id": "moonwell", "name": "Moonwell", "description": "Special: call moonlit healing for a large self heal.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 18, "prerequisites": {"healing_bloom": 2}, "effects": {"heal": 95}, "cooldown": 55.0, "x": 4, "y": 2},
		{"id": "avatar_of_the_wild", "name": "Avatar of the Wild", "description": "Capstone: stag-skull druid power, health, and defense.", "type": "capstone", "max_rank": 1, "cost": 1, "required_level": 25, "prerequisites": {"entangling_forest": 1, "moonwell": 1}, "effects": {"attack": 8, "defense": 5, "max_hp": 20}, "cooldown": 90.0, "x": 5, "y": 1}
	],
	"shield_maiden": [
		{"id": "bow_discipline", "name": "Bow Discipline", "description": "+3 ranged damage per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 2, "prerequisites": {}, "effects": {"attack": 3}, "cooldown": 0.0, "x": 0, "y": 0},
		{"id": "eagle_eye", "name": "Eagle Eye", "description": "+2 precision damage per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 4, "prerequisites": {}, "effects": {"attack": 2}, "cooldown": 0.0, "x": 1, "y": 0},
		{"id": "hunters_footwork", "name": "Hunter's Footwork", "description": "+2 defense per rank while kiting.", "type": "passive", "max_rank": 2, "cost": 1, "required_level": 6, "prerequisites": {"bow_discipline": 1}, "effects": {"defense": 2}, "cooldown": 0.0, "x": 0, "y": 1},
		{"id": "fletchers_craft", "name": "Fletcher's Craft", "description": "+4 bow damage per rank.", "type": "passive", "max_rank": 3, "cost": 1, "required_level": 7, "prerequisites": {"eagle_eye": 1}, "effects": {"attack": 4}, "cooldown": 0.0, "x": 1, "y": 1},
		{"id": "rangers_resolve", "name": "Ranger's Resolve", "description": "+10 max HP per rank.", "type": "passive", "max_rank": 2, "cost": 1, "required_level": 9, "prerequisites": {"hunters_footwork": 1}, "effects": {"max_hp": 10}, "cooldown": 0.0, "x": 1, "y": 2},
		{"id": "quick_shot", "name": "Quick Shot", "description": "Active: fast precise arrow.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 3, "prerequisites": {}, "effects": {"single_damage_multiplier": 1.20}, "cooldown": 8.0, "x": 2, "y": 0},
		{"id": "pinning_arrow", "name": "Pinning Arrow", "description": "Active: strong arrow meant to stop a target.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 8, "prerequisites": {"quick_shot": 1}, "effects": {"single_damage_multiplier": 1.32}, "cooldown": 13.0, "x": 2, "y": 1},
		{"id": "arrow_volley", "name": "Arrow Volley", "description": "Active: rain arrows on nearby enemies.", "type": "active", "max_rank": 2, "cost": 1, "required_level": 10, "prerequisites": {"fletchers_craft": 1}, "effects": {"area_damage_multiplier": 0.95}, "cooldown": 18.0, "x": 3, "y": 1},
		{"id": "falcon_dive", "name": "Falcon Dive", "description": "Special: devastating focused bow strike.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 15, "prerequisites": {"pinning_arrow": 1}, "effects": {"single_damage_multiplier": 1.80}, "cooldown": 35.0, "x": 4, "y": 1},
		{"id": "storm_of_arrows", "name": "Storm of Arrows", "description": "Special: wide arrow storm around the target area.", "type": "special", "max_rank": 1, "cost": 1, "required_level": 18, "prerequisites": {"arrow_volley": 1}, "effects": {"area_damage_multiplier": 1.50}, "cooldown": 50.0, "x": 4, "y": 2},
		{"id": "valkyrie_marksman", "name": "Valkyrie Marksman", "description": "Capstone: elite archer damage and survivability.", "type": "capstone", "max_rank": 1, "cost": 1, "required_level": 25, "prerequisites": {"falcon_dive": 1, "storm_of_arrows": 1}, "effects": {"attack": 9, "defense": 5}, "cooldown": 90.0, "x": 5, "y": 1}
	]
}


static func skills_for_class(class_type: String) -> Array:
	return (CLASS_SKILLS.get(class_type, CLASS_SKILLS["viking"]) as Array).duplicate(true)


static func skill_definition(class_type: String, skill_id: String) -> Dictionary:
	for skill in skills_for_class(class_type):
		var data: Dictionary = skill as Dictionary
		if str(data.get("id", "")) == skill_id:
			return data.duplicate(true)
	return {}


static func skill_rank(skill_state: Dictionary, skill_id: String) -> int:
	var unlocked: Dictionary = skill_state.get("unlocked_skills", {}) as Dictionary
	return int(unlocked.get(skill_id, 0))


static func passive_bonus(skill_state: Dictionary, class_type: String, effect_key: String) -> float:
	var total: float = 0.0
	for skill in skills_for_class(class_type):
		var data: Dictionary = skill as Dictionary
		if str(data.get("type", "")) != SKILL_TYPE_PASSIVE and str(data.get("type", "")) != SKILL_TYPE_CAPSTONE:
			continue
		var rank: int = skill_rank(skill_state, str(data.get("id", "")))
		if rank <= 0:
			continue
		var effects: Dictionary = data.get("effects", {}) as Dictionary
		if effects.has(effect_key):
			total += float(effects.get(effect_key, 0.0)) * float(rank)
	return total


static func cooldown_for_skill(skill_state: Dictionary, class_type: String, skill_id: String) -> float:
	var data: Dictionary = skill_definition(class_type, skill_id)
	var cooldown: float = float(data.get("cooldown", 0.0))
	for skill in skills_for_class(class_type):
		var passive: Dictionary = skill as Dictionary
		var rank: int = skill_rank(skill_state, str(passive.get("id", "")))
		if rank <= 0:
			continue
		var effects: Dictionary = passive.get("effects", {}) as Dictionary
		if effects.has("cooldown_multiplier"):
			cooldown *= pow(float(effects.get("cooldown_multiplier", 1.0)), rank)
	return cooldown
