extends Node

signal account_changed(account: Dictionary)
signal social_changed(account: Dictionary)

const ACCOUNTS_PATH: String = "user://accounts.json"
const CURRENT_SESSION_PATH: String = "user://current_account.json"
const ACCOUNT_VERSION: int = 2

# Development backend. Run backend with: cd backend && npm install && npm run dev
# For production, deploy the backend and change this URL.
const BACKEND_BASE_URL: String = "http://127.0.0.1:8787"
const USE_SUPABASE_BACKEND: bool = true
const OWNER_ADMIN_EMAILS: Array[String] = ["matthewpoteet1@gmail.com"]

var accounts: Dictionary = {}
var current_account_id: String = ""


func _ready() -> void:
	load_accounts()
	load_last_session()


func load_accounts() -> void:
	accounts = {}
	if not FileAccess.file_exists(ACCOUNTS_PATH):
		return

	var file: FileAccess = FileAccess.open(ACCOUNTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open local account cache file.")
		return

	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var data: Dictionary = parsed as Dictionary
		var raw_accounts: Variant = data.get("accounts", {})
		if raw_accounts is Dictionary:
			accounts = raw_accounts as Dictionary


func save_accounts() -> bool:
	var data: Dictionary = {
		"version": ACCOUNT_VERSION,
		"accounts": accounts,
		"saved_at_unix": Time.get_unix_time_from_system()
	}

	var file: FileAccess = FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save local account cache.")
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_last_session() -> void:
	if not FileAccess.file_exists(CURRENT_SESSION_PATH):
		return

	var file: FileAccess = FileAccess.open(CURRENT_SESSION_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		var data: Dictionary = parsed as Dictionary
		var account_id: String = str(data.get("account_id", ""))
		if accounts.has(account_id):
			current_account_id = account_id


func save_current_session() -> void:
	var file: FileAccess = FileAccess.open(CURRENT_SESSION_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"account_id": current_account_id}, "\t"))
	file.close()


func has_last_session() -> bool:
	return current_account_id != "" and accounts.has(current_account_id)


func get_current_account() -> Dictionary:
	if current_account_id == "" or not accounts.has(current_account_id):
		return {}
	return (accounts[current_account_id] as Dictionary).duplicate(true)


func create_account(email: String, password: String, player_name: String, character_id: String) -> Dictionary:
	var clean_email: String = _normalize_email(email)
	var clean_player_name: String = _clean_player_name(player_name)
	var clean_character_id: String = _clean_character_id(character_id)

	if not _is_valid_email(clean_email):
		return {"ok": false, "error": "Enter a valid email address."}
	if password.length() < 6:
		return {"ok": false, "error": "Password must be at least 6 characters for Supabase Auth."}
	if clean_player_name.length() < 2:
		return {"ok": false, "error": "Player name must be at least 2 characters."}

	if USE_SUPABASE_BACKEND:
		var response: Dictionary = await _http_json(
			HTTPClient.METHOD_POST,
			BACKEND_BASE_URL + "/auth/signup",
			{
				"email": clean_email,
				"password": password,
				"player_name": clean_player_name,
				"character_id": clean_character_id
			}
		)
		if not bool(response.get("ok", false)):
			return {"ok": false, "error": _response_error(response, "Supabase signup failed. Make sure the backend is running and configured.")}

		var account: Dictionary = _account_from_backend(response.get("account", {}), response.get("session", {}))
		return _finish_login(account)

	return _create_local_account(clean_email, password, clean_player_name, clean_character_id)


func login_account(email: String, password: String) -> Dictionary:
	var clean_email: String = _normalize_email(email)
	if not _is_valid_email(clean_email):
		return {"ok": false, "error": "Enter a valid email address."}
	if password.length() < 1:
		return {"ok": false, "error": "Enter your password."}

	if USE_SUPABASE_BACKEND:
		var response: Dictionary = await _http_json(
			HTTPClient.METHOD_POST,
			BACKEND_BASE_URL + "/auth/login",
			{
				"email": clean_email,
				"password": password
			}
		)
		if not bool(response.get("ok", false)):
			return {"ok": false, "error": _response_error(response, "Supabase login failed.")}

		var account: Dictionary = _account_from_backend(response.get("account", {}), response.get("session", {}))
		return _finish_login(account)

	return _login_local_account(clean_email, password)


func continue_last_session() -> Dictionary:
	if has_last_session():
		account_changed.emit(get_current_account())
		return {"ok": true, "account": get_current_account()}
	return {"ok": false, "error": "No saved account session found."}


func create_guest_account() -> Dictionary:
	var email: String = "guest_" + str(Time.get_unix_time_from_system()) + "@local.herja"
	var account_id: String = _make_local_account_id(email)
	var account: Dictionary = _new_local_account(account_id, email, "guest", "Guest Viking", "viking")
	account["is_guest"] = true
	accounts[account_id] = account
	current_account_id = account_id
	save_accounts()
	save_current_session()
	account_changed.emit(get_current_account())
	return {"ok": true, "account": get_current_account()}


func logout() -> void:
	current_account_id = ""
	save_current_session()
	account_changed.emit({})


func set_player_name(player_name: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var account: Dictionary = accounts[current_account_id] as Dictionary
	account["player_name"] = _clean_player_name(player_name)
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	account_changed.emit(get_current_account())
	return true


func set_character(character_id: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var account: Dictionary = accounts[current_account_id] as Dictionary
	account["character_id"] = _clean_character_id(character_id)
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	account_changed.emit(get_current_account())
	return true


func add_friend(friend_name: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var clean_name: String = friend_name.strip_edges()
	if clean_name.length() < 2:
		return false

	var account: Dictionary = accounts[current_account_id] as Dictionary
	var friends: Array = _get_friends_from_account(account)
	if not friends.has(clean_name):
		friends.append(clean_name)
	account["friends"] = friends
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	social_changed.emit(get_current_account())

	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		_sync_friend_to_backend(clean_name)
	return true


func remove_friend(friend_name: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var friends: Array = _get_friends_from_account(account)
	friends.erase(friend_name)
	account["friends"] = friends
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	social_changed.emit(get_current_account())
	return true


func set_clan(clan_name: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var clean_clan: String = clan_name.strip_edges()
	if clean_clan.length() < 2:
		return false
	var account: Dictionary = accounts[current_account_id] as Dictionary
	account["clan"] = {
		"name": clean_clan,
		"role": "Founder",
		"joined_at_unix": Time.get_unix_time_from_system()
	}
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	social_changed.emit(get_current_account())

	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		_sync_clan_to_backend(clean_clan)
	return true


func leave_clan() -> bool:
	if not _has_current_mutable_account():
		return false
	var account: Dictionary = accounts[current_account_id] as Dictionary
	account["clan"] = {}
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	social_changed.emit(get_current_account())
	return true


func update_progress_snapshot(player: Node) -> void:
	if player == null or not _has_current_mutable_account():
		return
	var account: Dictionary = accounts[current_account_id] as Dictionary
	account["player_name"] = str(player.stats.get("name", account.get("player_name", "Viking")))
	account["character_id"] = str(player.get("character_id"))
	account["level"] = int(player.stats.get("level", 1))
	account["xp"] = int(player.stats.get("xp", 0))
	account["hp"] = int(player.stats.get("hp", 100))
	account["max_hp"] = int(player.stats.get("max_hp", 100))
	account["attack"] = int(player.stats.get("attack", 12))
	account["gold"] = int(player.stats.get("gold", 0))
	account["inventory"] = player.inventory.duplicate(true)
	account["last_position"] = {"x": player.global_position.x, "y": player.global_position.y}
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()


func sync_progress_to_supabase(player: Node, world_map: Node) -> void:
	if player == null or not _has_current_mutable_account():
		return
	var account: Dictionary = accounts[current_account_id] as Dictionary
	if bool(account.get("is_guest", false)):
		return

	var geo: Dictionary = {}
	if world_map != null and world_map.has_method("world_to_geo"):
		geo = world_map.call("world_to_geo", player.global_position)

	var payload: Dictionary = {
		"account_id": current_account_id,
		"player_name": str(player.stats.get("name", account.get("player_name", "Viking"))),
		"character_id": str(player.get("character_id")),
		"level": int(player.stats.get("level", 1)),
		"xp": int(player.stats.get("xp", 0)),
		"hp": int(player.stats.get("hp", 100)),
		"max_hp": int(player.stats.get("max_hp", 100)),
		"attack": int(player.stats.get("attack", 12)),
		"gold": int(player.stats.get("gold", 0)),
		"inventory": player.inventory.duplicate(true),
		"last_position": {"x": player.global_position.x, "y": player.global_position.y},
		"last_latitude": geo.get("latitude", null),
		"last_longitude": geo.get("longitude", null)
	}

	var headers: Array[String] = _auth_headers(account)
	await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/progress/save", payload, headers)


func _sync_friend_to_backend(friend_name: String) -> void:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/friends/add", {"friend_name": friend_name}, headers)


func _sync_clan_to_backend(clan_name: String) -> void:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/clans/create-or-join", {"clan_name": clan_name}, headers)


func _finish_login(account: Dictionary) -> Dictionary:
	if account.is_empty():
		return {"ok": false, "error": "Backend returned an empty account."}

	var account_id: String = str(account.get("id", ""))
	if account_id == "":
		return {"ok": false, "error": "Backend returned an account without an id."}

	accounts[account_id] = account
	current_account_id = account_id
	save_accounts()
	save_current_session()
	account_changed.emit(get_current_account())
	return {"ok": true, "account": get_current_account()}


func _account_from_backend(raw_account: Variant, raw_session: Variant) -> Dictionary:
	var data: Dictionary = {}
	if raw_account is Dictionary:
		data = raw_account as Dictionary
	var session: Dictionary = {}
	if raw_session is Dictionary:
		session = raw_session as Dictionary

	var account: Dictionary = {
		"id": str(data.get("id", "")),
		"email": str(data.get("email", data.get("username", ""))),
		"username": str(data.get("email", data.get("username", ""))),
		"player_name": str(data.get("player_name", "Viking")),
		"character_id": str(data.get("character_id", "viking")),
		"level": int(data.get("level", 1)),
		"xp": int(data.get("xp", 0)),
		"hp": int(data.get("hp", 100)),
		"max_hp": int(data.get("max_hp", 100)),
		"attack": int(data.get("attack", 12)),
		"gold": int(data.get("gold", 0)),
		"inventory": _array_from_variant(data.get("inventory", [])),
		"friends": _array_from_variant(data.get("friends", [])),
		"clan": data.get("clan", {}),
		"is_admin": bool(data.get("is_admin", false)) or _is_admin_email(str(data.get("email", data.get("username", "")))),
		"access_token": str(session.get("access_token", "")),
		"refresh_token": str(session.get("refresh_token", "")),
		"is_guest": false,
		"created_at_unix": Time.get_unix_time_from_system(),
		"updated_at_unix": Time.get_unix_time_from_system(),
		"last_login_unix": Time.get_unix_time_from_system()
	}
	return account


func _http_json(method: int, url: String, payload: Dictionary = {}, extra_headers: Array[String] = []) -> Dictionary:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.timeout = 15.0

	var headers: Array[String] = ["Content-Type: application/json"]
	for header in extra_headers:
		headers.append(header)

	var body: String = ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var err: Error = http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "Could not start HTTP request. Error code: " + str(err)}

	var completed: Array = await http.request_completed
	http.queue_free()

	var response_code: int = int(completed[1])
	var raw_body: PackedByteArray = completed[3] as PackedByteArray
	var response_text: String = raw_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	var parsed_dict: Dictionary = {}
	if parsed is Dictionary:
		parsed_dict = parsed as Dictionary

	var ok: bool = response_code >= 200 and response_code < 300
	if ok and parsed_dict.has("ok"):
		ok = bool(parsed_dict.get("ok", true))

	return {
		"ok": ok,
		"status": response_code,
		"error": parsed_dict.get("error", response_text),
		"account": parsed_dict.get("account", {}),
		"session": parsed_dict.get("session", {}),
		"data": parsed_dict
	}


func _auth_headers(account: Dictionary) -> Array[String]:
	var token: String = str(account.get("access_token", ""))
	if token == "":
		return []
	return ["Authorization: Bearer " + token]


func _response_error(response: Dictionary, fallback: String) -> String:
	var err: String = str(response.get("error", ""))
	if err == "":
		return fallback
	return err


func _create_local_account(email: String, password: String, player_name: String, character_id: String) -> Dictionary:
	if _email_exists(email):
		return {"ok": false, "error": "That email already exists on this device."}
	var account_id: String = _make_local_account_id(email)
	var account: Dictionary = _new_local_account(account_id, email, password, player_name, character_id)
	accounts[account_id] = account
	current_account_id = account_id
	save_accounts()
	save_current_session()
	account_changed.emit(get_current_account())
	return {"ok": true, "account": get_current_account()}


func _login_local_account(email: String, password: String) -> Dictionary:
	for account_id in accounts.keys():
		var account: Dictionary = accounts[account_id] as Dictionary
		if str(account.get("email", account.get("username", ""))) == email:
			var password_hash: String = _hash_password(email, password, str(account.get("salt", "")))
			if password_hash == str(account.get("password_hash", "")):
				current_account_id = str(account.get("id", account_id))
				account["last_login_unix"] = Time.get_unix_time_from_system()
				accounts[current_account_id] = account
				save_accounts()
				save_current_session()
				account_changed.emit(get_current_account())
				return {"ok": true, "account": get_current_account()}
			return {"ok": false, "error": "Wrong password."}
	return {"ok": false, "error": "No account found for that email."}


func _new_local_account(account_id: String, email: String, password: String, player_name: String, character_id: String) -> Dictionary:
	var salt: String = str(randi()) + "_" + str(Time.get_unix_time_from_system())
	return {
		"id": account_id,
		"email": email,
		"username": email,
		"password_hash": _hash_password(email, password, salt),
		"salt": salt,
		"player_name": player_name,
		"character_id": character_id,
		"level": 1,
		"xp": 0,
		"hp": 100,
		"max_hp": 100,
		"attack": 12,
		"gold": 0,
		"inventory": ["Wood", "Wood", "Wood", "Wood", "Wood", "Stone", "Stone", "Stone", "Herb", "Herb", "Mushroom", "Crystal Vial"],
		"friends": [],
		"clan": {},
		"is_admin": _is_admin_email(email),
		"is_guest": false,
		"created_at_unix": Time.get_unix_time_from_system(),
		"updated_at_unix": Time.get_unix_time_from_system(),
		"last_login_unix": Time.get_unix_time_from_system()
	}


func _hash_password(email: String, password: String, salt: String) -> String:
	return (email + ":" + salt + ":" + password).sha256_text()


func _make_local_account_id(email: String) -> String:
	return (email + ":" + str(Time.get_unix_time_from_system()) + ":" + str(randi())).sha256_text().substr(0, 24)


func _normalize_email(email: String) -> String:
	return email.strip_edges().to_lower()


func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".") and email.length() >= 6


func _clean_player_name(player_name: String) -> String:
	var cleaned: String = player_name.strip_edges()
	if cleaned == "":
		return "Viking"
	return cleaned.substr(0, 24)


func _clean_character_id(character_id: String) -> String:
	var allowed: Array[String] = ["viking", "shield_maiden", "druid", "mage"]
	if allowed.has(character_id):
		return character_id
	return "viking"


func is_current_account_admin() -> bool:
	if not _has_current_mutable_account():
		return false

	var account: Dictionary = accounts[current_account_id] as Dictionary
	if bool(account.get("is_admin", false)):
		return true

	var email: String = _normalize_email(str(account.get("email", account.get("username", ""))))
	return _is_admin_email(email)


func _is_admin_email(email: String) -> bool:
	var clean_email: String = _normalize_email(email)
	for admin_email in OWNER_ADMIN_EMAILS:
		if clean_email == _normalize_email(admin_email):
			return true
	return false


func _email_exists(email: String) -> bool:
	for account_id in accounts.keys():
		var account: Dictionary = accounts[account_id] as Dictionary
		if str(account.get("email", account.get("username", ""))) == email:
			return true
	return false


func _has_current_mutable_account() -> bool:
	return current_account_id != "" and accounts.has(current_account_id)


func _get_friends_from_account(account: Dictionary) -> Array:
	var friends: Array = []
	var raw: Variant = account.get("friends", [])
	if raw is Array:
		for friend in raw:
			friends.append(str(friend))
	return friends


func _array_from_variant(value: Variant) -> Array:
	var output: Array = []
	if value is Array:
		for item in value:
			output.append(item)
	return output
