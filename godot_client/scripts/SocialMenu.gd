extends CanvasLayer

signal admin_teleport_requested(player_name: String)
const ClanConfig = preload("res://scripts/ClanConfig.gd")

var account_manager: Node
var player: Node

var panel: Panel
var title_label: Label
var profile_label: Label
var friends_label: Label
var invites_label: Label
var notifications_label: Label
var clan_label: Label
var friend_input: LineEdit
var clan_input: LineEdit
var perk_select: OptionButton
var war_input: LineEdit
var war_id_input: LineEdit
var battle_time_input: LineEdit
var admin_label: Label
var admin_teleport_input: LineEdit
var admin_teleport_button: Button
var status_label: Label


func setup(manager: Node, player_node: Node) -> void:
	account_manager = manager
	player = player_node
	_build_ui()
	visible = false
	if account_manager != null and account_manager.has_signal("social_changed"):
		account_manager.social_changed.connect(_on_social_changed)
	_refresh()


func toggle_visible() -> void:
	visible = not visible
	if visible:
		_refresh()


func _build_ui() -> void:
	layer = 60
	panel = Panel.new()
	panel.position = Vector2(820, 70)
	panel.size = Vector2(420, 620)
	add_child(panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(18, 16)
	scroll.size = Vector2(384, 588)
	panel.add_child(scroll)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	title_label = Label.new()
	title_label.text = "Social"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	box.add_child(title_label)

	profile_label = Label.new()
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(profile_label)

	friends_label = Label.new()
	friends_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	friends_label.custom_minimum_size = Vector2(0, 90)
	box.add_child(friends_label)

	invites_label = Label.new()
	invites_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	invites_label.custom_minimum_size = Vector2(0, 86)
	box.add_child(invites_label)

	friend_input = LineEdit.new()
	friend_input.placeholder_text = "Friend player name or email"
	box.add_child(friend_input)

	var friend_buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(friend_buttons)

	var add_friend_button: Button = Button.new()
	add_friend_button.text = "Send Invite"
	add_friend_button.pressed.connect(_on_send_invite_pressed)
	friend_buttons.add_child(add_friend_button)

	var accept_invite_button: Button = Button.new()
	accept_invite_button.text = "Accept"
	accept_invite_button.pressed.connect(_on_accept_invite_pressed)
	friend_buttons.add_child(accept_invite_button)

	var decline_invite_button: Button = Button.new()
	decline_invite_button.text = "Decline"
	decline_invite_button.pressed.connect(_on_decline_invite_pressed)
	friend_buttons.add_child(decline_invite_button)

	var remove_friend_button: Button = Button.new()
	remove_friend_button.text = "Remove"
	remove_friend_button.pressed.connect(_on_remove_friend_pressed)
	friend_buttons.add_child(remove_friend_button)

	notifications_label = Label.new()
	notifications_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notifications_label.custom_minimum_size = Vector2(0, 70)
	box.add_child(notifications_label)

	clan_label = Label.new()
	clan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(clan_label)

	clan_input = LineEdit.new()
	clan_input.placeholder_text = "Clan name"
	box.add_child(clan_input)

	perk_select = OptionButton.new()
	for perk_id in ClanConfig.perk_ids():
		perk_select.add_item("%s - %s" % [ClanConfig.perk_name(perk_id), ClanConfig.perk_description(perk_id)])
		perk_select.set_item_metadata(perk_select.get_item_count() - 1, perk_id)
	box.add_child(perk_select)

	var clan_buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(clan_buttons)

	var create_clan_button: Button = Button.new()
	create_clan_button.text = "Create Clan"
	create_clan_button.pressed.connect(_on_create_clan_pressed)
	clan_buttons.add_child(create_clan_button)

	var join_clan_button: Button = Button.new()
	join_clan_button.text = "Join Clan"
	join_clan_button.pressed.connect(_on_join_clan_pressed)
	clan_buttons.add_child(join_clan_button)

	var leave_clan_button: Button = Button.new()
	leave_clan_button.text = "Leave Clan"
	leave_clan_button.pressed.connect(_on_leave_clan_pressed)
	clan_buttons.add_child(leave_clan_button)

	var disband_clan_button: Button = Button.new()
	disband_clan_button.text = "Disband"
	disband_clan_button.pressed.connect(_on_disband_clan_pressed)
	clan_buttons.add_child(disband_clan_button)

	war_input = LineEdit.new()
	war_input.placeholder_text = "Enemy clan name for war challenge"
	box.add_child(war_input)

	var war_buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(war_buttons)

	var challenge_button: Button = Button.new()
	challenge_button.text = "Challenge War"
	challenge_button.pressed.connect(_on_challenge_war_pressed)
	war_buttons.add_child(challenge_button)

	war_id_input = LineEdit.new()
	war_id_input.placeholder_text = "War ID for accept/decline/schedule"
	box.add_child(war_id_input)

	var war_response_buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(war_response_buttons)

	var accept_war_button: Button = Button.new()
	accept_war_button.text = "Accept War"
	accept_war_button.pressed.connect(_on_accept_war_pressed)
	war_response_buttons.add_child(accept_war_button)

	var decline_war_button: Button = Button.new()
	decline_war_button.text = "Decline War"
	decline_war_button.pressed.connect(_on_decline_war_pressed)
	war_response_buttons.add_child(decline_war_button)

	battle_time_input = LineEdit.new()
	battle_time_input.placeholder_text = "Battle start unix time, 30+ min future"
	box.add_child(battle_time_input)

	var schedule_button: Button = Button.new()
	schedule_button.text = "Schedule Battle"
	schedule_button.pressed.connect(_on_schedule_battle_pressed)
	box.add_child(schedule_button)

	admin_label = Label.new()
	admin_label.text = "Admin"
	admin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(admin_label)

	admin_teleport_input = LineEdit.new()
	admin_teleport_input.placeholder_text = "Online username"
	box.add_child(admin_teleport_input)

	admin_teleport_button = Button.new()
	admin_teleport_button.text = "Teleport To Player"
	admin_teleport_button.pressed.connect(_on_admin_teleport_pressed)
	box.add_child(admin_teleport_button)

	status_label = Label.new()
	status_label.text = "Press O to open/close this panel."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	box.add_child(close_button)


func _refresh() -> void:
	if account_manager == null:
		return
	var account: Dictionary = account_manager.call("get_current_account") as Dictionary
	var player_name: String = str(account.get("player_name", "Viking"))
	var username: String = str(account.get("username", ""))
	var character_id: String = str(account.get("character_id", "viking"))
	profile_label.text = "Player: %s\nUsername: %s\nCharacter: %s" % [player_name, username, _character_display(character_id)]

	var friends: Array = []
	var raw_friends: Variant = account.get("friends", [])
	if raw_friends is Array:
		for friend in raw_friends:
			friends.append(str(friend))
	if friends.is_empty():
		friends_label.text = "Friends: none yet"
	else:
		friends_label.text = "Friends:\n- " + "\n- ".join(friends)

	var received_invites: Array = _string_array(account.get("friend_invites_received", []))
	var sent_invites: Array = _string_array(account.get("friend_invites_sent", []))
	var invite_lines: Array[String] = []
	if received_invites.is_empty():
		invite_lines.append("Incoming invites: none")
	else:
		invite_lines.append("Incoming invites:\n- " + "\n- ".join(received_invites))
	if sent_invites.is_empty():
		invite_lines.append("Outgoing invites: none")
	else:
		invite_lines.append("Outgoing invites:\n- " + "\n- ".join(sent_invites))
	invites_label.text = "\n".join(invite_lines)

	var notifications: Array = _notification_texts(account.get("notifications", []))
	if notifications.is_empty():
		notifications_label.text = "Notifications: none"
	else:
		notifications_label.text = "Notifications:\n- " + "\n- ".join(notifications.slice(0, min(3, notifications.size())))

	var clan: Variant = account.get("clan", {})
	if clan is Dictionary and not (clan as Dictionary).is_empty():
		var clan_dict: Dictionary = clan as Dictionary
		var perk_type: String = str(clan_dict.get("perk_type", "xp_boost"))
		clan_label.text = "Clan: %s\nRole: %s\nLeader: %s\nMembers: %d / %d\nPerk: %s\nRecord: %dW %dL %dD  Rep %d\nActive wars: %d" % [
			str(clan_dict.get("name", "Clan")),
			str(clan_dict.get("role", "Member")),
			str(clan_dict.get("leader_name", "Leader")),
			int(clan_dict.get("member_count", 1)),
			int(clan_dict.get("max_members", ClanConfig.MAX_CLAN_MEMBERS)),
			ClanConfig.perk_name(perk_type),
			int(clan_dict.get("wins", 0)),
			int(clan_dict.get("losses", 0)),
			int(clan_dict.get("draws", 0)),
			int(clan_dict.get("reputation", 0)),
			int(clan_dict.get("active_wars", 0))
		]
	else:
		clan_label.text = "Clan: none\nCreate cost: 10,000 gold\nMax members: 100"

	var is_admin: bool = _is_admin()
	admin_label.visible = is_admin
	admin_teleport_input.visible = is_admin
	admin_teleport_button.visible = is_admin
	if is_admin:
		admin_label.text = "Admin tools: teleport to an online player's current map position."


func _character_display(character_id: String) -> String:
	match character_id:
		"shield_maiden": return "Shield Maiden"
		"druid": return "Druid"
		"mage": return "Mage"
		_: return "Viking"


func _on_send_invite_pressed() -> void:
	if account_manager != null and bool(account_manager.call("send_friend_invite", friend_input.text)):
		status_label.text = "Invite sent."
		friend_input.text = ""
	else:
		status_label.text = "Enter a valid player name or email."
	_refresh()


func _on_accept_invite_pressed() -> void:
	if account_manager != null and bool(account_manager.call("accept_friend_invite", friend_input.text)):
		status_label.text = "Invite accepted."
		friend_input.text = ""
	else:
		status_label.text = "Type an incoming invite name to accept."
	_refresh()


func _on_decline_invite_pressed() -> void:
	if account_manager != null and bool(account_manager.call("decline_friend_invite", friend_input.text)):
		status_label.text = "Invite declined."
		friend_input.text = ""
	else:
		status_label.text = "Type an incoming invite name to decline."
	_refresh()


func _on_remove_friend_pressed() -> void:
	if account_manager != null and bool(account_manager.call("remove_friend", friend_input.text)):
		status_label.text = "Friend removed if it existed."
		friend_input.text = ""
	else:
		status_label.text = "Enter a friend name to remove."
	_refresh()


func _on_create_clan_pressed() -> void:
	if account_manager == null:
		return
	var result: Dictionary = await account_manager.call("create_clan", clan_input.text, _selected_perk_id(), player)
	if bool(result.get("ok", false)):
		status_label.text = "Clan created."
		clan_input.text = ""
	else:
		status_label.text = str(result.get("error", "Clan creation failed."))
	_refresh()


func _on_join_clan_pressed() -> void:
	if account_manager == null:
		return
	var result: Dictionary = await account_manager.call("join_clan", clan_input.text)
	if bool(result.get("ok", false)):
		status_label.text = "Joined clan."
		clan_input.text = ""
	else:
		status_label.text = str(result.get("error", "Could not join clan."))
	_refresh()


func _on_leave_clan_pressed() -> void:
	if account_manager != null and bool(account_manager.call("leave_clan")):
		status_label.text = "Clan left."
	else:
		status_label.text = "No clan to leave."
	_refresh()


func _on_disband_clan_pressed() -> void:
	if account_manager == null:
		return
	var result: Dictionary = await account_manager.call("disband_clan")
	status_label.text = "Clan disbanded." if bool(result.get("ok", false)) else str(result.get("error", "Could not disband clan."))
	_refresh()


func _on_challenge_war_pressed() -> void:
	if account_manager == null:
		return
	var result: Dictionary = account_manager.call("challenge_clan_to_war", war_input.text) as Dictionary
	if bool(result.get("ok", false)):
		var war: Dictionary = result.get("war", {}) as Dictionary
		status_label.text = "War challenge sent. War ID: %s" % str(war.get("id", ""))
	else:
		status_label.text = str(result.get("error", "Could not challenge clan."))


func _on_accept_war_pressed() -> void:
	_respond_to_war(true)


func _on_decline_war_pressed() -> void:
	_respond_to_war(false)


func _respond_to_war(accepted: bool) -> void:
	if account_manager == null:
		return
	var result: Dictionary = account_manager.call("respond_to_war", war_id_input.text.strip_edges(), accepted) as Dictionary
	if bool(result.get("ok", false)):
		status_label.text = "War accepted." if accepted else "War declined."
	else:
		status_label.text = str(result.get("error", "Could not update war."))


func _on_schedule_battle_pressed() -> void:
	if account_manager == null:
		return
	var start_unix: int = int(battle_time_input.text.strip_edges())
	var result: Dictionary = account_manager.call("schedule_clan_battle", war_id_input.text.strip_edges(), start_unix) as Dictionary
	if bool(result.get("ok", false)):
		var battle: Dictionary = result.get("battle", {}) as Dictionary
		status_label.text = "Battle scheduled. Battle ID: %s" % str(battle.get("id", ""))
	else:
		status_label.text = str(result.get("error", "Could not schedule battle."))


func _on_admin_teleport_pressed() -> void:
	if not _is_admin():
		status_label.text = "Admin privileges required."
		return
	var target_name: String = admin_teleport_input.text.strip_edges()
	if target_name.length() < 2:
		status_label.text = "Enter an online username."
		return
	admin_teleport_requested.emit(target_name)
	status_label.text = "Teleport requested for %s." % target_name


func _on_social_changed(_account: Dictionary) -> void:
	_refresh()

func _on_close_pressed() -> void:
	visible = false


func _string_array(raw: Variant) -> Array:
	var output: Array = []
	if raw is Array:
		for item in raw:
			output.append(str(item))
	return output


func _notification_texts(raw: Variant) -> Array:
	var output: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				output.append(str((item as Dictionary).get("message", "")))
			else:
				output.append(str(item))
	return output


func _is_admin() -> bool:
	if account_manager == null:
		return false
	if account_manager.has_method("is_current_account_admin"):
		return bool(account_manager.call("is_current_account_admin"))
	var account: Dictionary = account_manager.call("get_current_account") as Dictionary
	return bool(account.get("is_admin", false))


func _selected_perk_id() -> String:
	if perk_select == null:
		return "xp_boost"
	var metadata: Variant = perk_select.get_item_metadata(perk_select.selected)
	return ClanConfig.valid_perk_id(str(metadata))
