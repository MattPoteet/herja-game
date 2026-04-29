extends Node

# Starter multiplayer/presence client.
# This connects to the included Node backend WebSocket server.

var socket: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_server: bool = false
var server_url: String = "ws://127.0.0.1:8787"
var player_id: String = "player_%s" % randi()
var send_timer: float = 0.0
var account_manager: Node


func set_account_manager(manager: Node) -> void:
	account_manager = manager
	if account_manager != null and account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		if not account.is_empty():
			player_id = str(account.get("id", player_id))


func connect_to_server() -> void:
	var err: int = socket.connect_to_url(server_url)
	if err != OK:
		print("WebSocket connection failed: ", err)


func _process(delta: float) -> void:
	socket.poll()
	var state: int = socket.get_ready_state()
	is_connected_to_server = state == WebSocketPeer.STATE_OPEN
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var msg: String = socket.get_packet().get_string_from_utf8()
			_handle_message(msg)


func send_player_state(pos: Vector2, stats: Dictionary) -> void:
	send_timer += get_process_delta_time()
	if send_timer < 0.25:
		return
	send_timer = 0.0
	if not is_connected_to_server:
		return

	var clan_name: String = ""
	var character_id: String = "viking"
	if account_manager != null and account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		character_id = str(account.get("character_id", "viking"))
		var clan: Variant = account.get("clan", {})
		if clan is Dictionary and not (clan as Dictionary).is_empty():
			clan_name = str((clan as Dictionary).get("name", ""))

	var payload: Dictionary = {
		"type": "player_state",
		"id": player_id,
		"x": pos.x,
		"y": pos.y,
		"name": str(stats.get("name", "Player")),
		"level": int(stats.get("level", 1)),
		"character_id": character_id,
		"clan": clan_name
	}
	socket.send_text(JSON.stringify(payload))


func _handle_message(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.get("type") == "presence_snapshot":
		# Hook this into remote player rendering when ready.
		print("Online players: ", parsed.get("players", {}).size())
