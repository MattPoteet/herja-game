extends CanvasLayer

var account_manager: Node
var player: Node

var panel: Panel
var title_label: Label
var profile_label: Label
var friends_label: Label
var clan_label: Label
var friend_input: LineEdit
var clan_input: LineEdit
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
	panel.size = Vector2(420, 520)
	add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(18, 16)
	box.size = Vector2(384, 488)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

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

	friend_input = LineEdit.new()
	friend_input.placeholder_text = "Friend player name"
	box.add_child(friend_input)

	var friend_buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(friend_buttons)

	var add_friend_button: Button = Button.new()
	add_friend_button.text = "Add Friend"
	add_friend_button.pressed.connect(_on_add_friend_pressed)
	friend_buttons.add_child(add_friend_button)

	var remove_friend_button: Button = Button.new()
	remove_friend_button.text = "Remove"
	remove_friend_button.pressed.connect(_on_remove_friend_pressed)
	friend_buttons.add_child(remove_friend_button)

	clan_label = Label.new()
	clan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(clan_label)

	clan_input = LineEdit.new()
	clan_input.placeholder_text = "Clan name"
	box.add_child(clan_input)

	var clan_buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(clan_buttons)

	var create_clan_button: Button = Button.new()
	create_clan_button.text = "Create / Join Clan"
	create_clan_button.pressed.connect(_on_set_clan_pressed)
	clan_buttons.add_child(create_clan_button)

	var leave_clan_button: Button = Button.new()
	leave_clan_button.text = "Leave Clan"
	leave_clan_button.pressed.connect(_on_leave_clan_pressed)
	clan_buttons.add_child(leave_clan_button)

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

	var clan: Variant = account.get("clan", {})
	if clan is Dictionary and not (clan as Dictionary).is_empty():
		var clan_dict: Dictionary = clan as Dictionary
		clan_label.text = "Clan: %s\nRole: %s" % [str(clan_dict.get("name", "Clan")), str(clan_dict.get("role", "Member"))]
	else:
		clan_label.text = "Clan: none"


func _character_display(character_id: String) -> String:
	match character_id:
		"shield_maiden": return "Shield Maiden"
		"druid": return "Druid"
		"mage": return "Mage"
		_: return "Viking"


func _on_add_friend_pressed() -> void:
	if account_manager != null and bool(account_manager.call("add_friend", friend_input.text)):
		status_label.text = "Friend added."
		friend_input.text = ""
	else:
		status_label.text = "Enter a valid friend name."
	_refresh()


func _on_remove_friend_pressed() -> void:
	if account_manager != null and bool(account_manager.call("remove_friend", friend_input.text)):
		status_label.text = "Friend removed if it existed."
		friend_input.text = ""
	else:
		status_label.text = "Enter a friend name to remove."
	_refresh()


func _on_set_clan_pressed() -> void:
	if account_manager != null and bool(account_manager.call("set_clan", clan_input.text)):
		status_label.text = "Clan saved."
		clan_input.text = ""
	else:
		status_label.text = "Enter a valid clan name."
	_refresh()


func _on_leave_clan_pressed() -> void:
	if account_manager != null and bool(account_manager.call("leave_clan")):
		status_label.text = "Clan left."
	else:
		status_label.text = "No clan to leave."
	_refresh()


func _on_social_changed(_account: Dictionary) -> void:
	_refresh()

func _on_close_pressed() -> void:
	visible = false
