extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal xp_changed(current: int, level: int)
signal inventory_changed(items: Array)
signal profile_changed(player_name: String, character_id: String)
signal equipment_changed(equipment: Dictionary)
signal skills_changed(skill_state: Dictionary)

const Balance = preload("res://scripts/Balance.gd")
const ClanConfig = preload("res://scripts/ClanConfig.gd")
const SkillConfig = preload("res://scripts/SkillConfig.gd")
const SPEED: float = 135.0
const BOW_SHOT_VISIBLE_SECONDS: float = 0.16
const FIREBALL_VISIBLE_SECONDS: float = 0.24

const VIKING_WALK_PATH: String = "res://art/characters/viking/viking_walk.png"
const VIKING_ATTACK_PATH: String = "res://art/characters/viking/viking_attack.png"
const SHIELD_MAIDEN_WALK_PATH: String = "res://art/characters/shield_maiden/shield_maiden_walk.png"
const SHIELD_MAIDEN_ATTACK_PATH: String = "res://art/characters/shield_maiden/shield_maiden_attack.png"
const DRUID_WALK_PATH: String = "res://art/characters/druid/druid_walk.png"
const DRUID_ATTACK_PATH: String = "res://art/characters/druid/druid_attack.png"
const MAGE_WALK_PATH: String = "res://art/characters/mage/mage_walk.png"
const MAGE_ATTACK_PATH: String = "res://art/characters/mage/mage_attack.png"

const SPRITE_COLUMNS: int = 4
const SPRITE_ROWS: int = 4
const SPRITE_SCALE: Vector2 = Vector2(0.18, 0.18)

var stats: Dictionary = {
	"name": "Viking",
	"level": 1,
	"xp": 0,
	"hp": Balance.BASE_PLAYER_MAX_HP,
	"max_hp": Balance.BASE_PLAYER_MAX_HP,
	"attack": Balance.BASE_PLAYER_ATTACK,
	"gold": 0
}

var inventory: Array = []
var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"trinket": ""
}

var facing: Vector2 = Vector2.DOWN
var facing_direction: String = "down"
var is_attacking: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var character_id: String = "viking"
var clan_data: Dictionary = {}
var skill_state: Dictionary = {
	"available_skill_points": 0,
	"total_skill_points_earned": 0,
	"unlocked_skills": {}
}
var skill_cooldowns: Dictionary = {}
var virtual_move_vector: Vector2 = Vector2.ZERO
var virtual_attack_requested: bool = false
var has_move_target: bool = false
var move_target: Vector2 = Vector2.ZERO
var active_attack_target: Node2D

var animated_sprite: AnimatedSprite2D
var name_label: Label


func _ready() -> void:
	_ensure_input_actions()
	_setup_player_visuals()
	health_changed.emit(stats["hp"], stats["max_hp"])
	xp_changed.emit(stats["xp"], stats["level"])


func _physics_process(_delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.0:
		has_move_target = false
		active_attack_target = null
	elif virtual_move_vector.length() > 0.0:
		input_vector = virtual_move_vector
		has_move_target = false
		active_attack_target = null
	elif active_attack_target != null and is_instance_valid(active_attack_target):
		var to_attack_target: Vector2 = active_attack_target.global_position - global_position
		if to_attack_target.length() > _attack_range() * 0.82:
			input_vector = to_attack_target.normalized()
		elif not is_attacking:
			attack_target(active_attack_target)
	elif has_move_target:
		var to_move_target: Vector2 = move_target - global_position
		if to_move_target.length() > 8.0:
			input_vector = to_move_target.normalized()
		else:
			has_move_target = false
	if input_vector.length() > 0.0:
		facing = input_vector.normalized()
		_update_facing_direction(input_vector)
	velocity = input_vector * SPEED
	move_and_slide()
	_update_animation(input_vector)
	if Input.is_action_just_pressed("attack") or virtual_attack_requested:
		virtual_attack_requested = false
		attack_nearest_enemy()
	_tick_skill_cooldowns(_delta)


func attack_nearest_enemy() -> void:
	if is_attacking:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_distance: float = _attack_range()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if not enemy_node.visible:
			continue
		var distance: float = global_position.distance_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = enemy_node
	attack_target(closest)


func attack_target(target: Node2D) -> void:
	if is_attacking or target == null or not is_instance_valid(target):
		return
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > _attack_range():
		active_attack_target = target
		has_move_target = false
		return
	if to_target.length() > 0.0:
		facing = to_target.normalized()
		_update_facing_direction(facing)
	_play_attack_animation()
	if character_id == "shield_maiden":
		_show_bow_shot(target)
	elif character_id == "mage":
		_show_fireball(target)
	if target.has_method("take_damage"):
		target.call("take_damage", _attack_damage(target))


func set_move_target(target_position: Vector2) -> void:
	move_target = target_position
	has_move_target = true
	active_attack_target = null


func set_attack_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	active_attack_target = target
	has_move_target = false


func _attack_damage(target: Node = null) -> int:
	var damage: int = Balance.damage_for_character(character_id, total_attack())
	var is_boss: bool = target != null and bool(target.get_meta("dungeon_boss", false) or target.get_meta("world_boss", false))
	return ClanConfig.apply_clan_damage_bonus(self, damage, is_boss)


func _attack_range() -> float:
	return Balance.attack_range_for_character(character_id)


func _show_bow_shot(target: Node2D) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var direction: Vector2 = facing.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var start: Vector2 = global_position + direction * 24.0 + Vector2(0, -24)
	var end: Vector2 = start + direction * _attack_range()
	if target != null:
		end = target.global_position + Vector2(0, -18)
	var shot_direction: Vector2 = (end - start).normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = direction

	var arrow_node: Node2D = Node2D.new()
	arrow_node.name = "BowShot"
	arrow_node.global_position = start
	arrow_node.rotation = shot_direction.angle()
	arrow_node.z_index = 80
	parent_node.add_child(arrow_node)

	var outline: Line2D = Line2D.new()
	outline.width = 5.0
	outline.default_color = Color(0.06, 0.035, 0.015, 0.80)
	outline.add_point(Vector2(-24, 0))
	outline.add_point(Vector2(24, 0))
	arrow_node.add_child(outline)

	var shaft: Line2D = Line2D.new()
	shaft.width = 3.0
	shaft.default_color = Color(0.78, 0.48, 0.20, 1.0)
	shaft.add_point(Vector2(-24, 0))
	shaft.add_point(Vector2(24, 0))
	arrow_node.add_child(shaft)

	var highlight: Line2D = Line2D.new()
	highlight.width = 1.0
	highlight.default_color = Color(1.0, 0.88, 0.48, 0.95)
	highlight.add_point(Vector2(-20, -1))
	highlight.add_point(Vector2(18, -1))
	arrow_node.add_child(highlight)

	var head: Polygon2D = Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(32, 0),
		Vector2(18, -7),
		Vector2(21, 0),
		Vector2(18, 7)
	])
	head.color = Color(0.95, 0.96, 0.90, 0.98)
	arrow_node.add_child(head)

	var feather_top: Line2D = Line2D.new()
	feather_top.width = 3.0
	feather_top.default_color = Color(0.86, 0.20, 0.18, 0.95)
	feather_top.add_point(Vector2(-24, 0))
	feather_top.add_point(Vector2(-34, -7))
	arrow_node.add_child(feather_top)

	var feather_bottom: Line2D = Line2D.new()
	feather_bottom.width = 3.0
	feather_bottom.default_color = Color(0.92, 0.90, 0.82, 0.95)
	feather_bottom.add_point(Vector2(-24, 0))
	feather_bottom.add_point(Vector2(-34, 7))
	arrow_node.add_child(feather_bottom)

	var trail: Line2D = Line2D.new()
	trail.width = 2.0
	trail.default_color = Color(0.95, 0.86, 0.48, 0.38)
	trail.add_point(Vector2(-62, 0))
	trail.add_point(Vector2(-36, 0))
	arrow_node.add_child(trail)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(arrow_node, "global_position", end, BOW_SHOT_VISIBLE_SECONDS)
	tween.tween_property(arrow_node, "modulate:a", 0.0, BOW_SHOT_VISIBLE_SECONDS).set_delay(BOW_SHOT_VISIBLE_SECONDS * 0.45)

	await get_tree().create_timer(BOW_SHOT_VISIBLE_SECONDS).timeout
	if is_instance_valid(arrow_node):
		arrow_node.queue_free()


func _show_fireball(target: Node2D) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var direction: Vector2 = facing.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var start: Vector2 = global_position + direction * 24.0 + Vector2(0, -34)
	var end: Vector2 = start + direction * _attack_range()
	if target != null:
		end = target.global_position + Vector2(0, -18)

	var fireball: Node2D = Node2D.new()
	fireball.name = "MageFireball"
	fireball.global_position = start
	fireball.z_index = 84
	parent_node.add_child(fireball)

	var glow: Polygon2D = Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0, -18),
		Vector2(14, -10),
		Vector2(18, 0),
		Vector2(10, 14),
		Vector2(0, 18),
		Vector2(-14, 10),
		Vector2(-18, 0),
		Vector2(-10, -14)
	])
	glow.color = Color(1.0, 0.28, 0.04, 0.82)
	fireball.add_child(glow)

	var core: Polygon2D = Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0, -10),
		Vector2(8, -5),
		Vector2(10, 0),
		Vector2(5, 8),
		Vector2(0, 10),
		Vector2(-8, 5),
		Vector2(-10, 0),
		Vector2(-5, -8)
	])
	core.color = Color(1.0, 0.86, 0.20, 0.96)
	fireball.add_child(core)

	var trail: Line2D = Line2D.new()
	trail.width = 5.0
	trail.default_color = Color(1.0, 0.34, 0.04, 0.42)
	trail.add_point(Vector2(-34, 0))
	trail.add_point(Vector2(-10, 0))
	fireball.add_child(trail)

	var travel_direction: Vector2 = (end - start).normalized()
	if travel_direction != Vector2.ZERO:
		fireball.rotation = travel_direction.angle()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fireball, "global_position", end, FIREBALL_VISIBLE_SECONDS)
	tween.tween_property(fireball, "scale", Vector2(1.35, 1.35), FIREBALL_VISIBLE_SECONDS)
	tween.tween_property(fireball, "modulate:a", 0.0, FIREBALL_VISIBLE_SECONDS).set_delay(FIREBALL_VISIBLE_SECONDS * 0.55)

	await get_tree().create_timer(FIREBALL_VISIBLE_SECONDS).timeout
	if is_instance_valid(fireball):
		fireball.queue_free()


func gain_reward(xp_amount: int, gold_amount: int, item_name: String = "") -> void:
	xp_amount = ClanConfig.apply_clan_xp_bonus(self, xp_amount)
	gold_amount = ClanConfig.apply_clan_gold_bonus(self, gold_amount)
	stats["xp"] += xp_amount
	stats["gold"] += gold_amount
	if item_name != "":
		inventory.append(item_name)
		inventory_changed.emit(inventory)
	while int(stats["xp"]) >= Balance.xp_required_for_level(int(stats["level"])):
		var current_level: int = int(stats["level"])
		stats["xp"] = int(stats["xp"]) - Balance.xp_required_for_level(current_level)
		_level_up_once()
	xp_changed.emit(int(stats["xp"]), int(stats["level"]))
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))


func apply_account_profile(account: Dictionary) -> void:
	if account.is_empty():
		return
	stats["name"] = str(account.get("player_name", stats.get("name", "Viking")))
	character_id = str(account.get("character_id", character_id))
	if account.has("level"):
		stats["level"] = int(account.get("level", stats.get("level", 1)))
	if account.has("xp"):
		stats["xp"] = int(account.get("xp", stats.get("xp", 0)))
	if account.has("gold"):
		stats["gold"] = int(account.get("gold", stats.get("gold", 0)))
	if account.has("hp"):
		stats["hp"] = int(account.get("hp", stats.get("hp", Balance.BASE_PLAYER_MAX_HP)))
	if account.has("max_hp"):
		stats["max_hp"] = int(account.get("max_hp", stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)))
	if account.has("attack"):
		stats["attack"] = int(account.get("attack", stats.get("attack", Balance.BASE_PLAYER_ATTACK)))
	if account.has("inventory") and account.get("inventory") is Array:
		inventory = (account.get("inventory") as Array).duplicate(true)
	if account.has("equipment") and account.get("equipment") is Dictionary:
		equipment = _clean_equipment(account.get("equipment") as Dictionary)
	if account.has("clan") and account.get("clan") is Dictionary:
		clan_data = (account.get("clan") as Dictionary).duplicate(true)
	if account.has("skills") and account.get("skills") is Dictionary:
		skill_state = _clean_skill_state(account.get("skills") as Dictionary)
	_apply_character_style()
	refresh_after_load()


func set_clan_data(new_clan_data: Dictionary) -> void:
	clan_data = new_clan_data.duplicate(true)
	profile_changed.emit(str(stats.get("name", "Viking")), character_id)


func set_character(new_character_id: String) -> void:
	character_id = new_character_id
	_unequip_invalid_gear()
	_apply_character_style()
	profile_changed.emit(str(stats.get("name", "Viking")), character_id)


func set_virtual_move_vector(move_vector: Vector2) -> void:
	virtual_move_vector = move_vector.limit_length(1.0)


func request_virtual_attack() -> void:
	virtual_attack_requested = true


func refresh_after_load() -> void:
	if name_label != null:
		name_label.text = str(stats.get("name", "Viking"))
	_apply_character_style()
	health_changed.emit(int(stats.get("hp", Balance.BASE_PLAYER_MAX_HP)), int(stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)))
	xp_changed.emit(int(stats.get("xp", 0)), int(stats.get("level", 1)))
	inventory_changed.emit(inventory)
	equipment_changed.emit(equipment.duplicate(true))
	skills_changed.emit(skill_state.duplicate(true))
	profile_changed.emit(str(stats.get("name", "Viking")), character_id)


func _apply_character_style() -> void:
	if animated_sprite == null:
		return
	var sprite_frames: SpriteFrames = _build_character_sprite_frames()
	if sprite_frames != null:
		animated_sprite.sprite_frames = sprite_frames
	animated_sprite.modulate = _character_modulate()


func add_item(item_name: String) -> void:
	if item_name == "":
		return
	inventory.append(item_name)
	inventory_changed.emit(inventory)


func add_items(items: Array) -> void:
	for item in items:
		var item_name: String = str(item)
		if item_name != "":
			inventory.append(item_name)
	inventory_changed.emit(inventory)


func total_attack() -> int:
	return int(stats.get("attack", Balance.BASE_PLAYER_ATTACK)) + _equipment_attack_bonus() + int(SkillConfig.passive_bonus(skill_state, character_id, "attack"))


func total_defense() -> int:
	return _equipment_defense_bonus() + int(SkillConfig.passive_bonus(skill_state, character_id, "defense"))


func available_skill_points() -> int:
	return int(skill_state.get("available_skill_points", 0))


func unlocked_skill_rank(skill_id: String) -> int:
	return SkillConfig.skill_rank(skill_state, skill_id)


func can_unlock_skill(skill_id: String) -> Dictionary:
	var skill: Dictionary = SkillConfig.skill_definition(character_id, skill_id)
	if skill.is_empty():
		return {"ok": false, "error": "This skill is not available for your class."}
	if available_skill_points() < int(skill.get("cost", 1)):
		return {"ok": false, "error": "Not enough skill points."}
	if int(stats.get("level", 1)) < int(skill.get("required_level", 1)):
		return {"ok": false, "error": "Requires level %d." % int(skill.get("required_level", 1))}
	var current_rank: int = unlocked_skill_rank(skill_id)
	if current_rank >= int(skill.get("max_rank", 1)):
		return {"ok": false, "error": "Skill is already at max rank."}
	var prerequisites: Dictionary = skill.get("prerequisites", {}) as Dictionary
	for prereq_id in prerequisites.keys():
		var required_rank: int = int(prerequisites[prereq_id])
		if unlocked_skill_rank(str(prereq_id)) < required_rank:
			var prereq: Dictionary = SkillConfig.skill_definition(character_id, str(prereq_id))
			return {"ok": false, "error": "Requires %s Rank %d." % [str(prereq.get("name", prereq_id)), required_rank]}
	return {"ok": true}


func unlock_skill(skill_id: String) -> Dictionary:
	var check: Dictionary = can_unlock_skill(skill_id)
	if not bool(check.get("ok", false)):
		return check
	var skill: Dictionary = SkillConfig.skill_definition(character_id, skill_id)
	var unlocked: Dictionary = skill_state.get("unlocked_skills", {}) as Dictionary
	unlocked[skill_id] = int(unlocked.get(skill_id, 0)) + 1
	skill_state["unlocked_skills"] = unlocked
	skill_state["available_skill_points"] = available_skill_points() - int(skill.get("cost", 1))
	_apply_skill_unlock_effects(skill)
	skills_changed.emit(skill_state.duplicate(true))
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))
	return {"ok": true, "skill": skill}


func reset_skill_tree() -> Dictionary:
	if not SkillConfig.RESPEC_ENABLED:
		return {"ok": false, "error": "Respec is disabled."}
	if int(stats.get("gold", 0)) < SkillConfig.RESPEC_GOLD_COST:
		return {"ok": false, "error": "You need %d gold to reset skills." % SkillConfig.RESPEC_GOLD_COST}
	var max_hp_bonus: int = int(SkillConfig.passive_bonus(skill_state, character_id, "max_hp"))
	stats["gold"] = int(stats.get("gold", 0)) - SkillConfig.RESPEC_GOLD_COST
	stats["max_hp"] = max(Balance.BASE_PLAYER_MAX_HP, int(stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)) - max_hp_bonus)
	stats["hp"] = min(int(stats.get("hp", stats["max_hp"])), int(stats["max_hp"]))
	skill_state["available_skill_points"] = int(skill_state.get("total_skill_points_earned", 0))
	skill_state["unlocked_skills"] = {}
	skills_changed.emit(skill_state.duplicate(true))
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))
	return {"ok": true}


func active_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for skill in SkillConfig.skills_for_class(character_id):
		var data: Dictionary = skill as Dictionary
		var kind: String = str(data.get("type", ""))
		if kind == SkillConfig.SKILL_TYPE_ACTIVE or kind == SkillConfig.SKILL_TYPE_SPECIAL or kind == SkillConfig.SKILL_TYPE_CAPSTONE:
			if unlocked_skill_rank(str(data.get("id", ""))) > 0:
				ids.append(str(data.get("id", "")))
	return ids


func use_skill_ability(skill_id: String) -> Dictionary:
	if unlocked_skill_rank(skill_id) <= 0:
		return {"ok": false, "error": "Unlock this skill first."}
	var skill: Dictionary = SkillConfig.skill_definition(character_id, skill_id)
	if skill.is_empty():
		return {"ok": false, "error": "This skill is not available for your class."}
	var cooldown_left: float = float(skill_cooldowns.get(skill_id, 0.0))
	if cooldown_left > 0.0:
		return {"ok": false, "error": "%s ready in %.1fs." % [str(skill.get("name", "Skill")), cooldown_left]}
	var effects: Dictionary = skill.get("effects", {}) as Dictionary
	if effects.has("heal"):
		var healing: int = int(effects.get("heal", 0)) * max(1, unlocked_skill_rank(skill_id))
		stats["hp"] = min(int(stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)), int(stats.get("hp", 0)) + healing)
		health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))
		_show_floating_text("+%d" % healing, Color(0.45, 1.0, 0.50), Vector2(0, -92))
	elif effects.has("area_damage_multiplier"):
		_damage_nearby_enemies(float(effects.get("area_damage_multiplier", 1.0)) * float(max(1, unlocked_skill_rank(skill_id))))
	elif effects.has("single_damage_multiplier"):
		var target_enemy: Node2D = active_attack_target if active_attack_target != null and is_instance_valid(active_attack_target) else _nearest_enemy_in_range()
		if target_enemy != null and target_enemy.has_method("take_damage"):
			target_enemy.call("take_damage", int(round(float(_attack_damage(target_enemy)) * float(effects.get("single_damage_multiplier", 1.0)))))
		else:
			return {"ok": false, "error": "No enemy in range."}
	elif effects.has("temporary_attack") or effects.has("temporary_defense"):
		_show_floating_text(str(skill.get("name", "Skill")), Color(0.95, 0.82, 0.38), Vector2(0, -96))
		# TODO: replace this placeholder with a timed buff system once Herja has one.
	skill_cooldowns[skill_id] = SkillConfig.cooldown_for_skill(skill_state, character_id, skill_id)
	return {"ok": true}


func equip_item(item_name: String) -> bool:
	if not Balance.is_gear(item_name):
		return false
	if not Balance.can_equip_gear(item_name, character_id, int(stats.get("level", 1))):
		return false
	var index: int = inventory.find(item_name)
	if index < 0:
		return false
	var slot: String = Balance.gear_slot(item_name)
	if slot == "":
		return false
	var previous: String = str(equipment.get(slot, ""))
	if previous != "":
		inventory.append(previous)
	inventory.remove_at(index)
	equipment[slot] = item_name
	inventory_changed.emit(inventory)
	equipment_changed.emit(equipment.duplicate(true))
	return true


func unequip_slot(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	var item_name: String = str(equipment.get(slot, ""))
	if item_name == "":
		return false
	equipment[slot] = ""
	inventory.append(item_name)
	inventory_changed.emit(inventory)
	equipment_changed.emit(equipment.duplicate(true))
	return true


func get_inventory_counts() -> Dictionary:
	var counts: Dictionary = {}
	for item in inventory:
		var item_name: String = str(item)
		counts[item_name] = int(counts.get(item_name, 0)) + 1
	return counts


func has_items(recipe: Dictionary) -> bool:
	var counts: Dictionary = get_inventory_counts()
	for item_name in recipe.keys():
		if int(counts.get(item_name, 0)) < int(recipe[item_name]):
			return false
	return true


func remove_items(recipe: Dictionary) -> bool:
	if not has_items(recipe):
		return false
	for item_name in recipe.keys():
		var needed: int = int(recipe[item_name])
		var removed: int = 0
		var i: int = inventory.size() - 1
		while i >= 0 and removed < needed:
			if str(inventory[i]) == str(item_name):
				inventory.remove_at(i)
				removed += 1
			i -= 1
	inventory_changed.emit(inventory)
	return true


func use_item(item_name: String) -> bool:
	var index: int = inventory.find(item_name)
	if index < 0:
		return false
	var used: bool = false
	match item_name:
		"Health Potion":
			stats["hp"] = min(int(stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)), int(stats.get("hp", Balance.BASE_PLAYER_MAX_HP)) + Balance.potion_healing(item_name))
			used = true
		"Greater Health Potion":
			stats["hp"] = min(int(stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)), int(stats.get("hp", Balance.BASE_PLAYER_MAX_HP)) + Balance.potion_healing(item_name))
			used = true
		"Mead":
			stats["hp"] = min(int(stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)), int(stats.get("hp", Balance.BASE_PLAYER_MAX_HP)) + Balance.potion_healing(item_name))
			used = true
		"Rune Tonic":
			_gain_xp(Balance.consumable_xp(item_name))
			used = true
		_:
			return false
	if not used:
		return false
	inventory.remove_at(index)
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))
	inventory_changed.emit(inventory)
	return true


func take_damage(amount: int) -> void:
	var damage: int = max(0, amount - total_defense())
	damage = ClanConfig.apply_clan_damage_taken(self, damage)
	if damage <= 0:
		_show_floating_text("Blocked", Color(0.58, 0.82, 1.0), Vector2(0, -88))
		return
	_show_floating_text("-%d" % damage, Color(1.0, 0.34, 0.28), Vector2(0, -88))
	_flash_hit()
	stats["hp"] = max(0, int(stats["hp"]) - damage)
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))
	if int(stats["hp"]) <= 0:
		respawn()


func _gain_xp(xp_amount: int) -> void:
	if xp_amount <= 0:
		return
	stats["xp"] = int(stats.get("xp", 0)) + xp_amount
	while int(stats["xp"]) >= Balance.xp_required_for_level(int(stats["level"])):
		var current_level: int = int(stats["level"])
		stats["xp"] = int(stats["xp"]) - Balance.xp_required_for_level(current_level)
		_level_up_once()
	xp_changed.emit(int(stats["xp"]), int(stats["level"]))
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))


func _level_up_once() -> void:
	stats["level"] = int(stats["level"]) + 1
	stats["max_hp"] = int(stats["max_hp"]) + Balance.max_hp_gain_for_level(int(stats["level"]))
	stats["attack"] = int(stats["attack"]) + Balance.attack_gain_for_level(int(stats["level"]))
	stats["hp"] = int(stats["max_hp"])
	_grant_skill_points(SkillConfig.SKILL_POINTS_PER_LEVEL)


func _grant_skill_points(amount: int) -> void:
	if amount <= 0:
		return
	skill_state["available_skill_points"] = available_skill_points() + amount
	skill_state["total_skill_points_earned"] = int(skill_state.get("total_skill_points_earned", 0)) + amount
	skills_changed.emit(skill_state.duplicate(true))


func _apply_skill_unlock_effects(skill: Dictionary) -> void:
	var effects: Dictionary = skill.get("effects", {}) as Dictionary
	if effects.has("max_hp"):
		var gain: int = int(effects.get("max_hp", 0))
		stats["max_hp"] = int(stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)) + gain
		stats["hp"] = min(int(stats["max_hp"]), int(stats.get("hp", stats["max_hp"])) + gain)


func _damage_nearby_enemies(multiplier: float) -> void:
	var base_damage: int = max(1, int(round(float(_attack_damage()) * multiplier)))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if not enemy_node.visible:
			continue
		if global_position.distance_to(enemy_node.global_position) <= _attack_range() * 1.65 and enemy.has_method("take_damage"):
			enemy.call("take_damage", base_damage)


func _nearest_enemy_in_range() -> Node2D:
	var closest: Node2D = null
	var closest_distance: float = _attack_range() * 1.25
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if not enemy_node.visible:
			continue
		var distance: float = global_position.distance_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = enemy_node
	return closest


func _tick_skill_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0.0, float(skill_cooldowns[skill_id]) - delta)


func _clean_skill_state(raw: Dictionary) -> Dictionary:
	var unlocked: Dictionary = {}
	var raw_unlocked: Variant = raw.get("unlocked_skills", {})
	if raw_unlocked is Dictionary:
		for skill_id in (raw_unlocked as Dictionary).keys():
			unlocked[str(skill_id)] = max(0, int((raw_unlocked as Dictionary)[skill_id]))
	return {
		"available_skill_points": max(0, int(raw.get("available_skill_points", 0))),
		"total_skill_points_earned": max(0, int(raw.get("total_skill_points_earned", 0))),
		"unlocked_skills": unlocked
	}


func respawn() -> void:
	if spawn_position != Vector2.ZERO:
		global_position = spawn_position
	else:
		global_position = Vector2(640, 360)
	stats["hp"] = int(stats["max_hp"])
	health_changed.emit(int(stats["hp"]), int(stats["max_hp"]))


func _flash_hit() -> void:
	if animated_sprite == null:
		return
	animated_sprite.modulate = Color(1.0, 0.38, 0.30)
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", _character_modulate(), 0.16)


func _show_floating_text(text: String, color: Color, offset: Vector2) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var label: Label = Label.new()
	label.text = text
	label.global_position = global_position + offset
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(label)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -30), 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.18)
	tween.finished.connect(label.queue_free)


func _setup_player_visuals() -> void:
	_setup_collision()
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
	animated_sprite.centered = true
	animated_sprite.position = Vector2(0, -24)
	animated_sprite.scale = SPRITE_SCALE
	animated_sprite.z_index = 10
	var sprite_frames: SpriteFrames = _build_character_sprite_frames()
	if sprite_frames != null:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("idle_down")
	else:
		_draw_placeholder()
	_setup_name_label()
	_apply_character_style()


func _setup_collision() -> void:
	if get_node_or_null("CollisionShape2D") != null:
		return
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 16.0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	collision.position = Vector2(0, 8)
	add_child(collision)


func _setup_name_label() -> void:
	name_label = get_node_or_null("NameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		add_child(name_label)
	name_label.text = str(stats["name"])
	name_label.position = Vector2(-30, -68)
	name_label.z_index = 20


func _build_character_sprite_frames() -> SpriteFrames:
	var walk_path: String = _walk_sprite_path()
	var attack_path: String = _attack_sprite_path()
	var walk_texture: Texture2D = load(walk_path) as Texture2D
	var attack_texture: Texture2D = load(attack_path) as Texture2D
	if walk_texture == null or attack_texture == null:
		push_warning("Character sprites could not load for %s. Walk: %s Attack: %s" % [character_id, walk_path, attack_path])
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_directional_animations(frames, walk_texture, "idle", 1, true, 1.0)
	_add_directional_animations(frames, walk_texture, "walk", 4, true, 7.0)
	_add_directional_animations(frames, attack_texture, "attack", 4, false, 10.0)
	return frames


func _walk_sprite_path() -> String:
	match character_id:
		"shield_maiden": return SHIELD_MAIDEN_WALK_PATH
		"druid": return DRUID_WALK_PATH
		"mage": return MAGE_WALK_PATH
		_: return VIKING_WALK_PATH


func _attack_sprite_path() -> String:
	match character_id:
		"shield_maiden": return SHIELD_MAIDEN_ATTACK_PATH
		"druid": return DRUID_ATTACK_PATH
		"mage": return MAGE_ATTACK_PATH
		_: return VIKING_ATTACK_PATH


func _character_modulate() -> Color:
	return Color.WHITE


func _add_directional_animations(frames: SpriteFrames, texture: Texture2D, prefix: String, columns_to_use: int, loop: bool, speed: float) -> void:
	var directions: Array[String] = ["down", "left", "right", "up"]
	var frame_width: int = int(floor(float(texture.get_width()) / float(SPRITE_COLUMNS)))
	var frame_height: int = int(floor(float(texture.get_height()) / float(SPRITE_ROWS)))
	for row: int in range(SPRITE_ROWS):
		var anim_name: String = prefix + "_" + directions[row]
		if frames.has_animation(anim_name):
			frames.remove_animation(anim_name)
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, speed)
		for column: int in range(columns_to_use):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(column * frame_width), float(row * frame_height), float(frame_width), float(frame_height))
			frames.add_frame(anim_name, atlas)


func _update_facing_direction(input_vector: Vector2) -> void:
	if abs(input_vector.x) > abs(input_vector.y):
		if input_vector.x > 0.0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		if input_vector.y > 0.0:
			facing_direction = "down"
		else:
			facing_direction = "up"


func _update_animation(input_vector: Vector2) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if is_attacking:
		return
	var anim_name: String = ""
	if input_vector.length() > 0.0:
		anim_name = "walk_" + facing_direction
	else:
		anim_name = "idle_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		_play_sprite_animation(anim_name)


func _play_attack_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var anim_name: String = "attack_" + facing_direction
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return
	is_attacking = true
	_play_sprite_animation(anim_name)
	await animated_sprite.animation_finished
	is_attacking = false


func _play_sprite_animation(anim_name: String) -> void:
	if animated_sprite.animation == anim_name and animated_sprite.is_playing():
		return
	animated_sprite.play(anim_name)


func _draw_placeholder() -> void:
	var body: ColorRect = ColorRect.new()
	body.name = "PlaceholderBody"
	body.color = Color(0.2, 0.8, 0.4)
	body.size = Vector2(28, 34)
	body.position = Vector2(-14, -17)
	add_child(body)


func _equipment_attack_bonus() -> int:
	var bonus: int = 0
	for item_name in equipment.values():
		bonus += Balance.gear_attack(str(item_name))
	return bonus


func _equipment_defense_bonus() -> int:
	var bonus: int = 0
	for item_name in equipment.values():
		bonus += Balance.gear_defense(str(item_name))
	return bonus


func _clean_equipment(raw_equipment: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for slot in Balance.equipment_slots():
		var item_name: String = str(raw_equipment.get(slot, ""))
		clean[slot] = item_name if item_name == "" or Balance.gear_slot(item_name) == slot else ""
	return clean


func _unequip_invalid_gear() -> void:
	var changed: bool = false
	for slot in Balance.equipment_slots():
		var item_name: String = str(equipment.get(slot, ""))
		if item_name == "":
			continue
		if Balance.can_equip_gear(item_name, character_id, int(stats.get("level", 1))):
			continue
		equipment[slot] = ""
		inventory.append(item_name)
		changed = true
	if changed:
		inventory_changed.emit(inventory)
		equipment_changed.emit(equipment.duplicate(true))


func _ensure_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("attack", [KEY_SPACE])
	_add_key_action("interact", [KEY_E])


func _add_key_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key in keys:
		var exists: bool = false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var key_event: InputEventKey = event as InputEventKey
				if key_event.keycode == key:
					exists = true
		if not exists:
			var new_event: InputEventKey = InputEventKey.new()
			new_event.keycode = key
			InputMap.action_add_event(action_name, new_event)
