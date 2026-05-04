extends Node2D

const AccountManagerScript: Script = preload("res://scripts/AccountManager.gd")
const AccountScreenScript: Script = preload("res://scripts/AccountScreen.gd")
const SaveManagerScript: Script = preload("res://scripts/SaveManager.gd")
const SocialMenuScript: Script = preload("res://scripts/SocialMenu.gd")
const BuildingManagerScript: Script = preload("res://scripts/BuildingManager.gd")
const InventoryMenuScript: Script = preload("res://scripts/InventoryMenu.gd")
const RemotePlayerScript: Script = preload("res://scripts/RemotePlayer.gd")
const MobileControlsScript: Script = preload("res://scripts/MobileControls.gd")
const ChatPanelScript: Script = preload("res://scripts/ChatPanel.gd")
const AdManagerScript: Script = preload("res://scripts/AdManager.gd")

@onready var player: CharacterBody2D = $Player
@onready var world_map: Node2D = $WorldMap
@onready var network_client: Node = $NetworkClient
@onready var spawn_manager: Node = $SpawnManager
@onready var hud: CanvasLayer = $HUD

var account_manager: Node
var save_manager: Node
var account_screen: CanvasLayer
var social_menu: CanvasLayer
var building_manager: Node2D
var inventory_menu: CanvasLayer
var remote_players_layer: Node2D
var remote_players: Dictionary = {}
var mobile_controls: CanvasLayer
var chat_panel: CanvasLayer
var ad_manager: CanvasLayer
var ad_break_active: bool = false
var game_started: bool = false
var autosave_timer: float = 0.0
const AUTOSAVE_SECONDS: float = 8.0
const TAP_ENEMY_RADIUS: float = 42.0


func _ready() -> void:
	_ensure_global_input_actions()
	_set_game_visible(false)

	account_manager = AccountManagerScript.new()
	account_manager.name = "AccountManager"
	add_child(account_manager)

	save_manager = SaveManagerScript.new()
	save_manager.name = "SaveManager"
	add_child(save_manager)

	_show_account_screen()


func _process(delta: float) -> void:
	if not game_started:
		return
	if ad_break_active:
		return

	if Input.is_action_just_pressed("manual_save"):
		_save_now("Manual save complete.")

	if Input.is_action_just_pressed("social_menu") and social_menu != null:
		social_menu.call("toggle_visible")

	if Input.is_action_just_pressed("inventory_menu") and inventory_menu != null:
		inventory_menu.call("toggle_visible", "inventory")

	if Input.is_action_just_pressed("main_menu") and inventory_menu != null:
		inventory_menu.call("toggle_visible", "equipment")

	if Input.is_action_just_pressed("build_menu") and inventory_menu != null:
		inventory_menu.call("show_tab", "build")

	if Input.is_action_just_pressed("craft_menu") and inventory_menu != null:
		inventory_menu.call("show_tab", "craft")

	if Input.is_action_just_pressed("multiplayer_chat") and chat_panel != null:
		chat_panel.call("focus_chat")

	if Input.is_action_just_pressed("interact") and building_manager != null and building_manager.has_method("use_nearest_structure"):
		building_manager.call("use_nearest_structure")

	autosave_timer += delta
	if autosave_timer >= AUTOSAVE_SECONDS:
		autosave_timer = 0.0
		_save_now("Autosaved.")

	if network_client.is_connected_to_server:
		network_client.send_player_state(player.global_position, player.stats)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if game_started:
			_save_now("")


func _input(event: InputEvent) -> void:
	if not game_started:
		return
	if ad_break_active:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not _is_touch_over_mobile_controls(touch.position):
			_handle_world_tap(touch.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and get_viewport().gui_get_hovered_control() == null:
			_handle_world_tap(mouse.position)


func _show_account_screen() -> void:
	account_screen = AccountScreenScript.new()
	add_child(account_screen)
	account_screen.call("setup", account_manager)
	account_screen.account_ready.connect(_on_account_ready)


func _on_account_ready(account: Dictionary) -> void:
	_start_game(account)


func _start_game(account: Dictionary) -> void:
	_set_game_visible(true)
	game_started = true

	if player.has_method("apply_account_profile"):
		player.call("apply_account_profile", account)

	if world_map.has_method("setup"):
		world_map.call("setup", player)
	else:
		world_map.generate_world()

	var loaded: bool = bool(save_manager.call("load_player", player, world_map, account_manager))
	if not loaded and player.has_method("refresh_after_load"):
		player.call("refresh_after_load")

	spawn_manager.setup(world_map, player)
	hud.setup(player, account_manager)
	if hud.has_signal("menu_pressed"):
		hud.menu_pressed.connect(_on_hud_menu_pressed)
	if account_manager.has_signal("notifications_changed"):
		account_manager.notifications_changed.connect(_on_notifications_changed)
	if world_map.has_signal("gps_changed") and hud.has_method("set_gps"):
		world_map.gps_changed.connect(hud.set_gps)
	if world_map.has_signal("section_loading_started"):
		world_map.section_loading_started.connect(_on_section_loading_started)
	if world_map.has_signal("section_loading_finished"):
		world_map.section_loading_finished.connect(_on_section_loading_finished)

	building_manager = BuildingManagerScript.new()
	building_manager.name = "BuildingManager"
	add_child(building_manager)
	building_manager.call("setup", player, account_manager, hud)

	social_menu = SocialMenuScript.new()
	add_child(social_menu)
	social_menu.call("setup", account_manager, player)
	if social_menu.has_signal("admin_teleport_requested"):
		social_menu.connect("admin_teleport_requested", Callable(self, "_on_admin_teleport_requested"))

	inventory_menu = InventoryMenuScript.new()
	add_child(inventory_menu)
	inventory_menu.call("setup", player, building_manager, account_manager, hud)

	chat_panel = ChatPanelScript.new()
	add_child(chat_panel)
	if chat_panel.has_signal("message_submitted"):
		chat_panel.connect("message_submitted", Callable(self, "_on_chat_message_submitted"))

	ad_manager = AdManagerScript.new()
	add_child(ad_manager)
	if ad_manager.has_signal("ad_break_started"):
		ad_manager.connect("ad_break_started", Callable(self, "_on_ad_break_started"))
	if ad_manager.has_signal("ad_break_finished"):
		ad_manager.connect("ad_break_finished", Callable(self, "_on_ad_break_finished"))

	_setup_mobile_controls()

	if network_client.has_method("set_account_manager"):
		network_client.call("set_account_manager", account_manager)
	var presence_callable: Callable = Callable(self, "_on_presence_snapshot")
	if network_client.has_signal("presence_snapshot") and not network_client.is_connected("presence_snapshot", presence_callable):
		network_client.connect("presence_snapshot", presence_callable)
	var chat_callable: Callable = Callable(self, "_on_chat_message_received")
	if network_client.has_signal("chat_message_received") and not network_client.is_connected("chat_message_received", chat_callable):
		network_client.connect("chat_message_received", chat_callable)
	var connection_callable: Callable = Callable(self, "_on_network_connection_status_changed")
	if network_client.has_signal("connection_status_changed") and not network_client.is_connected("connection_status_changed", connection_callable):
		network_client.connect("connection_status_changed", connection_callable)
	_ensure_remote_players_layer()
	network_client.connect_to_server()
	_save_now("Account loaded. Press M or the Menu button for gear, inventory, crafting, and building.")


func _save_now(message: String) -> void:
	if save_manager == null or player == null:
		return
	var ok: bool = bool(save_manager.call("save_player", player, world_map, account_manager))
	if hud != null and hud.has_method("set_status") and message != "":
		if ok:
			hud.call("set_status", message)
		else:
			hud.call("set_status", "Save failed.")


func _set_game_visible(is_visible: bool) -> void:
	if player != null:
		player.visible = is_visible
		player.set_physics_process(is_visible)
	if world_map != null:
		world_map.visible = is_visible
		world_map.set_process(is_visible)
	if spawn_manager != null:
		spawn_manager.set_process(is_visible)
	if hud != null:
		hud.visible = is_visible
		hud.set_process(is_visible)
	if building_manager != null:
		building_manager.visible = is_visible
		building_manager.set_process(is_visible)
	if inventory_menu != null:
		inventory_menu.visible = false
	if chat_panel != null:
		chat_panel.visible = is_visible
	if ad_manager != null and not ad_break_active:
		ad_manager.visible = false


func _setup_mobile_controls() -> void:
	if mobile_controls != null:
		return
	mobile_controls = MobileControlsScript.new()
	add_child(mobile_controls)
	mobile_controls.connect("move_changed", Callable(self, "_on_mobile_move_changed"))
	mobile_controls.connect("attack_pressed", Callable(self, "_on_mobile_attack_pressed"))
	mobile_controls.connect("inventory_pressed", Callable(self, "_on_mobile_inventory_pressed"))
	mobile_controls.connect("build_pressed", Callable(self, "_on_mobile_build_pressed"))
	mobile_controls.connect("social_pressed", Callable(self, "_on_mobile_social_pressed"))
	mobile_controls.connect("save_pressed", Callable(self, "_on_mobile_save_pressed"))


func _on_mobile_move_changed(move_vector: Vector2) -> void:
	if player != null and player.has_method("set_virtual_move_vector"):
		player.call("set_virtual_move_vector", move_vector)


func _on_mobile_attack_pressed() -> void:
	if player != null and player.has_method("request_virtual_attack"):
		player.call("request_virtual_attack")


func _on_mobile_inventory_pressed() -> void:
	if inventory_menu != null:
		inventory_menu.call("toggle_visible", "inventory")


func _on_hud_menu_pressed() -> void:
	if inventory_menu != null:
		inventory_menu.call("toggle_visible", "equipment")


func _on_notifications_changed(notifications: Array) -> void:
	if hud == null or not hud.has_method("set_status") or notifications.is_empty():
		return
	var latest: Variant = notifications[0]
	if latest is Dictionary:
		hud.call("set_status", str((latest as Dictionary).get("message", "")))
	else:
		hud.call("set_status", str(latest))


func _on_chat_message_submitted(message: String) -> void:
	if network_client == null or player == null:
		return
	if network_client.has_method("send_chat_message") and bool(network_client.call("send_chat_message", message, player.stats)):
		return
	if chat_panel != null and chat_panel.has_method("add_system_message"):
		chat_panel.call("add_system_message", "Chat is offline.")


func _on_chat_message_received(message: Dictionary) -> void:
	if chat_panel == null or not chat_panel.has_method("add_chat_message"):
		return
	chat_panel.call(
		"add_chat_message",
		str(message.get("name", "Player")),
		str(message.get("message", "")),
		str(message.get("clan", ""))
	)


func _on_network_connection_status_changed(is_connected: bool) -> void:
	if chat_panel != null and chat_panel.has_method("set_connection_status"):
		chat_panel.call("set_connection_status", is_connected)
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", "Multiplayer connected." if is_connected else "Multiplayer offline.")


func _on_section_loading_started(_section: Vector2i) -> void:
	if ad_manager != null and ad_manager.has_method("should_show_for_next_load") and bool(ad_manager.call("should_show_for_next_load")):
		_start_ad_break_deferred()


func _on_section_loading_finished(_section: Vector2i) -> void:
	if ad_break_active:
		_set_gameplay_paused_for_ad(true)


func _start_ad_break_deferred() -> void:
	if ad_manager == null or ad_break_active:
		return
	call_deferred("_start_ad_break")


func _start_ad_break() -> void:
	if ad_manager == null or ad_break_active:
		return
	ad_manager.call("show_ad_break")


func _on_ad_break_started() -> void:
	ad_break_active = true
	_set_gameplay_paused_for_ad(true)
	_set_status("Sponsored break. Gameplay is paused.")


func _on_ad_break_finished() -> void:
	ad_break_active = false
	_set_gameplay_paused_for_ad(false)
	_set_status("Ad break complete.")


func _set_gameplay_paused_for_ad(paused: bool) -> void:
	if player != null:
		player.set_physics_process(not paused)
		if paused:
			player.set("velocity", Vector2.ZERO)
			player.set("has_move_target", false)
			player.set("active_attack_target", null)
	if spawn_manager != null:
		if spawn_manager.has_method("set_spawning_paused"):
			spawn_manager.call("set_spawning_paused", paused)
		else:
			spawn_manager.set_process(not paused)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("set_combat_paused"):
			enemy.call("set_combat_paused", paused)
		else:
			enemy.set_process(not paused)


func _on_admin_teleport_requested(target_name: String) -> void:
	if account_manager == null or not account_manager.has_method("is_current_account_admin") or not bool(account_manager.call("is_current_account_admin")):
		_set_status("Admin privileges required.")
		return
	var target: Node2D = _remote_player_by_name(target_name)
	if target == null:
		_set_status("No online player found named %s." % target_name)
		return
	if player == null:
		return
	var target_position: Vector2 = target.global_position
	var remote_target: Variant = target.get("target_position")
	if remote_target is Vector2:
		target_position = remote_target
	player.global_position = target_position
	_clear_player_navigation()
	_set_status("Teleported to %s." % str(target.get("display_name")))
	_save_now("")


func _remote_player_by_name(target_name: String) -> Node2D:
	var needle: String = target_name.strip_edges().to_lower()
	for remote_id in remote_players.keys():
		var remote_player: Node2D = remote_players.get(remote_id, null) as Node2D
		if remote_player == null or not is_instance_valid(remote_player):
			continue
		var display_name: String = str(remote_player.get("display_name"))
		var username: String = str(remote_player.get("username"))
		var player_id_text: String = str(remote_player.get("player_id"))
		if display_name.to_lower() == needle or username.to_lower() == needle or player_id_text.to_lower() == needle:
			return remote_player
	return null


func _clear_player_navigation() -> void:
	if player == null:
		return
	player.set("has_move_target", false)
	player.set("move_target", player.global_position)
	player.set("active_attack_target", null)
	player.set("velocity", Vector2.ZERO)


func _set_status(message: String) -> void:
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", message)


func _on_mobile_build_pressed() -> void:
	if inventory_menu != null:
		inventory_menu.call("show_tab", "build")


func _on_mobile_social_pressed() -> void:
	if social_menu != null:
		social_menu.call("toggle_visible")


func _on_mobile_save_pressed() -> void:
	_save_now("Manual save complete.")


func _handle_world_tap(screen_position: Vector2) -> void:
	if player == null:
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var tapped_enemy: Node2D = _enemy_at_world_position(world_position)
	if tapped_enemy != null and player.has_method("set_attack_target"):
		player.call("set_attack_target", tapped_enemy)
		if hud != null and hud.has_method("set_status"):
			hud.call("set_status", "Targeting %s." % str(tapped_enemy.get("enemy_name")))
		return
	if player.has_method("set_move_target"):
		player.call("set_move_target", world_position)
		if hud != null and hud.has_method("set_status"):
			hud.call("set_status", "Moving to tap.")


func _is_touch_over_mobile_controls(screen_position: Vector2) -> bool:
	if mobile_controls == null:
		return false
	if mobile_controls.has_method("is_screen_position_over_controls"):
		return bool(mobile_controls.call("is_screen_position_over_controls", screen_position))
	return false


func _enemy_at_world_position(world_position: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = TAP_ENEMY_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		var distance: float = enemy_node.global_position.distance_to(world_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy_node
	return nearest


func _ensure_remote_players_layer() -> void:
	if remote_players_layer != null:
		return
	remote_players_layer = Node2D.new()
	remote_players_layer.name = "RemotePlayers"
	remote_players_layer.z_index = 3
	add_child(remote_players_layer)


func _on_presence_snapshot(players: Dictionary) -> void:
	if remote_players_layer == null:
		return

	var local_id: String = ""
	if network_client != null:
		local_id = str(network_client.get("player_id"))

	var seen: Dictionary = {}
	for id_variant in players.keys():
		var remote_id: String = str(id_variant)
		if remote_id == local_id:
			continue
		var state_variant: Variant = players.get(id_variant, {})
		if not state_variant is Dictionary:
			continue
		seen[remote_id] = true
		var remote_player: Node2D = remote_players.get(remote_id, null) as Node2D
		if remote_player == null:
			remote_player = RemotePlayerScript.new()
			remote_player.name = "RemotePlayer_" + remote_id.replace("-", "_")
			remote_player.set("player_id", remote_id)
			remote_players_layer.add_child(remote_player)
			remote_players[remote_id] = remote_player
		remote_player.call("apply_state", state_variant as Dictionary)

	for remote_id in remote_players.keys().duplicate():
		if seen.has(str(remote_id)):
			continue
		var stale_player: Node = remote_players.get(remote_id, null) as Node
		if stale_player != null:
			stale_player.queue_free()
		remote_players.erase(remote_id)


func _ensure_global_input_actions() -> void:
	_add_key_action("main_menu", [KEY_M, KEY_ESCAPE])
	_add_key_action("manual_save", [KEY_F5])
	_add_key_action("social_menu", [KEY_O])
	_add_key_action("inventory_menu", [KEY_I])
	_add_key_action("build_menu", [KEY_B])
	_add_key_action("craft_menu", [KEY_C])
	_add_key_action("multiplayer_chat", [KEY_ENTER, KEY_T])


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
