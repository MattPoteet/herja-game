extends Node2D

const AccountManagerScript: Script = preload("res://scripts/AccountManager.gd")
const AccountScreenScript: Script = preload("res://scripts/AccountScreen.gd")
const SaveManagerScript: Script = preload("res://scripts/SaveManager.gd")
const SocialMenuScript: Script = preload("res://scripts/SocialMenu.gd")
const BuildingManagerScript: Script = preload("res://scripts/BuildingManager.gd")
const InventoryMenuScript: Script = preload("res://scripts/InventoryMenu.gd")

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
var game_started: bool = false
var autosave_timer: float = 0.0
const AUTOSAVE_SECONDS: float = 8.0


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

	if Input.is_action_just_pressed("manual_save"):
		_save_now("Manual save complete.")

	if Input.is_action_just_pressed("social_menu") and social_menu != null:
		social_menu.call("toggle_visible")

	if Input.is_action_just_pressed("inventory_menu") and inventory_menu != null:
		inventory_menu.call("toggle_visible", "inventory")

	if Input.is_action_just_pressed("build_menu") and inventory_menu != null:
		inventory_menu.call("show_tab", "build")

	if Input.is_action_just_pressed("craft_menu") and inventory_menu != null:
		inventory_menu.call("show_tab", "craft")

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
	if world_map.has_signal("gps_changed") and hud.has_method("set_gps"):
		world_map.gps_changed.connect(hud.set_gps)

	building_manager = BuildingManagerScript.new()
	building_manager.name = "BuildingManager"
	add_child(building_manager)
	building_manager.call("setup", player, account_manager, hud)

	social_menu = SocialMenuScript.new()
	add_child(social_menu)
	social_menu.call("setup", account_manager, player)

	inventory_menu = InventoryMenuScript.new()
	add_child(inventory_menu)
	inventory_menu.call("setup", player, building_manager, account_manager, hud)

	if network_client.has_method("set_account_manager"):
		network_client.call("set_account_manager", account_manager)
	network_client.connect_to_server()
	_save_now("Account loaded. Press I for inventory, C for potions, B to build.")


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


func _ensure_global_input_actions() -> void:
	_add_key_action("manual_save", [KEY_F5])
	_add_key_action("social_menu", [KEY_O])
	_add_key_action("inventory_menu", [KEY_I])
	_add_key_action("build_menu", [KEY_B])
	_add_key_action("craft_menu", [KEY_C])


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
