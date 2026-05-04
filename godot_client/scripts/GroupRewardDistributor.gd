extends RefCounted

const DungeonLootTable = preload("res://scripts/DungeonLootTable.gd")

var rewarded_bosses: Dictionary = {}


func distribute_boss_rewards(local_player: Node, tier: int, dungeon_id: String, hud: Node) -> void:
	var eligible_players: Array[Node] = eligible_players_for_boss(local_player, dungeon_id)
	for reward_player in eligible_players:
		if reward_player == null or not reward_player.has_method("gain_reward"):
			continue
		var reward_key: String = "%s:%d" % [dungeon_id, reward_player.get_instance_id()]
		if rewarded_bosses.has(reward_key):
			continue
		rewarded_bosses[reward_key] = true
		var reward: Dictionary = DungeonLootTable.boss_reward_for_player(reward_player, tier)
		reward_player.call("gain_reward", int(reward.get("xp", 0)), int(reward.get("gold", 0)), str(reward.get("item", "")))
		_show_reward_status(reward, hud)


func eligible_players_for_boss(local_player: Node, _dungeon_id: String) -> Array[Node]:
	# Placeholder for party/server integration. When Herja has authoritative
	# groups, replace this with the server-approved members who helped in dungeon.
	if local_player == null:
		return []
	return [local_player]


func _show_reward_status(reward: Dictionary, hud: Node) -> void:
	if hud == null or not hud.has_method("set_status"):
		return
	var item_name: String = str(reward.get("item", ""))
	var message: String = "Boss defeated: +%d XP, +%d gold" % [int(reward.get("xp", 0)), int(reward.get("gold", 0))]
	if item_name != "":
		message += ", %s" % item_name
	hud.call("set_status", message)
