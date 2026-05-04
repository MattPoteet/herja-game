extends Node

signal account_changed(account: Dictionary)
signal social_changed(account: Dictionary)
signal notifications_changed(notifications: Array)

const Balance = preload("res://scripts/Balance.gd")
const ClanConfig = preload("res://scripts/ClanConfig.gd")
const ACCOUNTS_PATH: String = "user://accounts.json"
const CURRENT_SESSION_PATH: String = "user://current_account.json"
const ACCOUNT_VERSION: int = 2

# Development backend. Run backend with: cd backend && npm install && npm run dev
# For production, deploy the backend and change this URL.
const BACKEND_BASE_URL: String = "https://herja-backend.onrender.com"
const USE_SUPABASE_BACKEND: bool = true
const OWNER_ADMIN_EMAILS: Array[String] = ["matthewpoteet1@gmail.com"]

var accounts: Dictionary = {}
var local_clans: Dictionary = {}
var local_clan_wars: Dictionary = {}
var local_clan_battles: Dictionary = {}
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
		var raw_clans: Variant = data.get("clans", {})
		if raw_clans is Dictionary:
			local_clans = raw_clans as Dictionary
		var raw_wars: Variant = data.get("clan_wars", {})
		if raw_wars is Dictionary:
			local_clan_wars = raw_wars as Dictionary
		var raw_battles: Variant = data.get("clan_battles", {})
		if raw_battles is Dictionary:
			local_clan_battles = raw_battles as Dictionary


func save_accounts() -> bool:
	var data: Dictionary = {
		"version": ACCOUNT_VERSION,
		"accounts": accounts,
		"clans": local_clans,
		"clan_wars": local_clan_wars,
		"clan_battles": local_clan_battles,
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


func send_friend_invite(friend_name: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var clean_name: String = friend_name.strip_edges()
	if clean_name.length() < 2:
		return false

	var account: Dictionary = accounts[current_account_id] as Dictionary
	var player_name: String = str(account.get("player_name", "Viking"))
	var friends: Array = _get_friends_from_account(account)
	if friends.has(clean_name):
		_add_notification("You are already friends with %s." % clean_name)
		return false

	var sent: Array = _get_invites_from_account(account, "friend_invites_sent")
	if not sent.has(clean_name):
		sent.append(clean_name)
	account["friend_invites_sent"] = sent
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account

	var local_target_id: String = _find_account_id_by_player_or_email(clean_name)
	if local_target_id != "":
		var target: Dictionary = accounts[local_target_id] as Dictionary
		var incoming: Array = _get_invites_from_account(target, "friend_invites_received")
		if not incoming.has(player_name):
			incoming.append(player_name)
		target["friend_invites_received"] = incoming
		target["notifications"] = _notifications_with_message(target, "%s sent you a friend invite." % player_name)
		target["updated_at_unix"] = Time.get_unix_time_from_system()
		accounts[local_target_id] = target

	save_accounts()
	_add_notification("Friend invite sent to %s." % clean_name)
	social_changed.emit(get_current_account())

	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		_sync_friend_invite_to_backend(clean_name)
	return true


func accept_friend_invite(friend_name: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var clean_name: String = friend_name.strip_edges()
	if clean_name.length() < 2:
		return false

	var account: Dictionary = accounts[current_account_id] as Dictionary
	var received: Array = _get_invites_from_account(account, "friend_invites_received")
	if not received.has(clean_name):
		return false
	received.erase(clean_name)
	account["friend_invites_received"] = received

	var friends: Array = _get_friends_from_account(account)
	if not friends.has(clean_name):
		friends.append(clean_name)
	account["friends"] = friends
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account

	var local_sender_id: String = _find_account_id_by_player_or_email(clean_name)
	if local_sender_id != "":
		var sender: Dictionary = accounts[local_sender_id] as Dictionary
		var player_name: String = str(account.get("player_name", "Viking"))
		var sender_sent: Array = _get_invites_from_account(sender, "friend_invites_sent")
		sender_sent.erase(player_name)
		sender["friend_invites_sent"] = sender_sent
		var sender_friends: Array = _get_friends_from_account(sender)
		if not sender_friends.has(player_name):
			sender_friends.append(player_name)
		sender["friends"] = sender_friends
		sender["notifications"] = _notifications_with_message(sender, "%s accepted your friend invite." % player_name)
		sender["updated_at_unix"] = Time.get_unix_time_from_system()
		accounts[local_sender_id] = sender

	save_accounts()
	_add_notification("Accepted friend invite from %s." % clean_name)
	social_changed.emit(get_current_account())

	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		_sync_friend_invite_response_to_backend(clean_name, true)
	return true


func decline_friend_invite(friend_name: String) -> bool:
	if not _has_current_mutable_account():
		return false
	var clean_name: String = friend_name.strip_edges()
	if clean_name.length() < 2:
		return false

	var account: Dictionary = accounts[current_account_id] as Dictionary
	var received: Array = _get_invites_from_account(account, "friend_invites_received")
	if not received.has(clean_name):
		return false
	received.erase(clean_name)
	account["friend_invites_received"] = received
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	var local_sender_id: String = _find_account_id_by_player_or_email(clean_name)
	if local_sender_id != "":
		var sender: Dictionary = accounts[local_sender_id] as Dictionary
		var player_name: String = str(account.get("player_name", "Viking"))
		var sender_sent: Array = _get_invites_from_account(sender, "friend_invites_sent")
		sender_sent.erase(player_name)
		sender["friend_invites_sent"] = sender_sent
		sender["notifications"] = _notifications_with_message(sender, "%s declined your friend invite." % player_name)
		sender["updated_at_unix"] = Time.get_unix_time_from_system()
		accounts[local_sender_id] = sender
	save_accounts()
	_add_notification("Declined friend invite from %s." % clean_name)
	social_changed.emit(get_current_account())

	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		_sync_friend_invite_response_to_backend(clean_name, false)
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


func create_clan(clan_name: String, perk_type: String, player: Node = null) -> Dictionary:
	if not _has_current_mutable_account():
		return {"ok": false, "error": "Login required."}
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var validation: Dictionary = ClanConfig.validate_clan_name(clan_name)
	if not bool(validation.get("ok", false)):
		return validation
	if not _account_clan(account).is_empty():
		return {"ok": false, "error": "You are already in a clan."}
	var gold: int = _current_gold(account, player)
	if gold < ClanConfig.CLAN_CREATE_COST:
		return {"ok": false, "error": "You need 10,000 gold to create a clan."}
	var clean_clan: String = str(validation.get("name", "Clan"))
	var clean_perk: String = ClanConfig.valid_perk_id(perk_type)

	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		var response: Dictionary = await _sync_clan_create_to_backend(clean_clan, clean_perk)
		if not bool(response.get("ok", false)):
			return {"ok": false, "error": _response_error(response, "Clan creation failed.")}
		account["gold"] = int(response.get("gold", gold - ClanConfig.CLAN_CREATE_COST))
		account["clan"] = response.get("clan", {})
	else:
		if _local_clan_name_exists(clean_clan):
			return {"ok": false, "error": "That clan name is already taken."}
		var clan_id: String = _make_local_id("clan")
		var now: int = Time.get_unix_time_from_system()
		var clan: Dictionary = {
			"id": clan_id,
			"name": clean_clan,
			"leader_id": current_account_id,
			"leader_name": str(account.get("player_name", "Viking")),
			"perk_type": clean_perk,
			"member_count": 1,
			"max_members": ClanConfig.MAX_CLAN_MEMBERS,
			"members": {
				current_account_id: _clan_member_dict(current_account_id, account, "Leader")
			},
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"reputation": 0,
			"created_at_unix": now,
			"updated_at_unix": now
		}
		local_clans[clan_id] = clan
		account["gold"] = gold - ClanConfig.CLAN_CREATE_COST
		account["clan"] = _public_clan_for_account(clan, "Leader")

	if player != null:
		player.stats["gold"] = int(account.get("gold", gold))
		if player.has_method("set_clan_data"):
			player.call("set_clan_data", account.get("clan", {}))
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	social_changed.emit(get_current_account())
	account_changed.emit(get_current_account())
	return {"ok": true, "clan": account.get("clan", {})}


func join_clan(clan_name: String) -> Dictionary:
	if not _has_current_mutable_account():
		return {"ok": false, "error": "Login required."}
	var account: Dictionary = accounts[current_account_id] as Dictionary
	if not _account_clan(account).is_empty():
		return {"ok": false, "error": "You are already in a clan."}
	var validation: Dictionary = ClanConfig.validate_clan_name(clan_name)
	if not bool(validation.get("ok", false)):
		return validation
	var clean_clan: String = str(validation.get("name", "Clan"))

	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		var response: Dictionary = await _sync_clan_join_to_backend(clean_clan)
		if not bool(response.get("ok", false)):
			return {"ok": false, "error": _response_error(response, "Could not join clan.")}
		account["clan"] = response.get("clan", {})
	else:
		var clan_id: String = _local_clan_id_by_name(clean_clan)
		if clan_id == "":
			return {"ok": false, "error": "Clan not found."}
		var clan: Dictionary = local_clans[clan_id] as Dictionary
		if int(clan.get("member_count", 0)) >= ClanConfig.MAX_CLAN_MEMBERS:
			return {"ok": false, "error": "This clan is full."}
		var members: Dictionary = clan.get("members", {}) as Dictionary
		members[current_account_id] = _clan_member_dict(current_account_id, account, "Member")
		clan["members"] = members
		clan["member_count"] = members.size()
		clan["updated_at_unix"] = Time.get_unix_time_from_system()
		local_clans[clan_id] = clan
		account["clan"] = _public_clan_for_account(clan, "Member")

	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	social_changed.emit(get_current_account())
	return {"ok": true, "clan": account.get("clan", {})}


func set_clan(clan_name: String) -> bool:
	var result: Dictionary = await join_clan(clan_name)
	return bool(result.get("ok", false))


func leave_clan() -> bool:
	if not _has_current_mutable_account():
		return false
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var clan: Dictionary = _account_clan(account)
	if clan.is_empty():
		return false
	var role: String = str(clan.get("role", "Member")).to_lower()
	if role == "leader" or role == "founder":
		_add_notification("Leaders must transfer leadership or disband the clan first.")
		return false
	if not bool(account.get("is_guest", false)):
		_sync_clan_leave_to_backend()
	var clan_id: String = str(clan.get("id", ""))
	if local_clans.has(clan_id):
		var clan_data: Dictionary = local_clans[clan_id] as Dictionary
		var members: Dictionary = clan_data.get("members", {}) as Dictionary
		members.erase(current_account_id)
		clan_data["members"] = members
		clan_data["member_count"] = members.size()
		clan_data["updated_at_unix"] = Time.get_unix_time_from_system()
		local_clans[clan_id] = clan_data
	account["clan"] = {}
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	social_changed.emit(get_current_account())
	return true


func disband_clan() -> Dictionary:
	if not _has_current_mutable_account():
		return {"ok": false, "error": "Login required."}
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var clan: Dictionary = _account_clan(account)
	if clan.is_empty():
		return {"ok": false, "error": "You are not in a clan."}
	var role: String = str(clan.get("role", "Member")).to_lower()
	if role != "leader" and role != "founder":
		return {"ok": false, "error": "Only the clan leader can disband the clan."}
	var clan_id: String = str(clan.get("id", ""))
	if USE_SUPABASE_BACKEND and not bool(account.get("is_guest", false)):
		var response: Dictionary = await _sync_clan_disband_to_backend()
		if not bool(response.get("ok", false)):
			return {"ok": false, "error": _response_error(response, "Could not disband clan.")}
	if local_clans.has(clan_id):
		local_clans.erase(clan_id)
	for account_id in accounts.keys():
		var other: Dictionary = accounts[account_id] as Dictionary
		var other_clan: Dictionary = _account_clan(other)
		if str(other_clan.get("id", "")) == clan_id:
			other["clan"] = {}
			other["updated_at_unix"] = Time.get_unix_time_from_system()
			accounts[account_id] = other
	save_accounts()
	social_changed.emit(get_current_account())
	return {"ok": true}


func browse_clans() -> Array:
	var output: Array = []
	for clan_id in local_clans.keys():
		var clan: Dictionary = local_clans[clan_id] as Dictionary
		output.append(_public_clan_for_account(clan, ""))
	return output


func clan_members() -> Array:
	var account: Dictionary = get_current_account()
	var clan: Dictionary = _account_clan(account)
	var clan_id: String = str(clan.get("id", ""))
	if local_clans.has(clan_id):
		var clan_data: Dictionary = local_clans[clan_id] as Dictionary
		var members: Dictionary = clan_data.get("members", {}) as Dictionary
		return members.values()
	return _array_from_variant(clan.get("members", []))


func challenge_clan_to_war(target_clan_name: String) -> Dictionary:
	if not _is_current_clan_leader():
		return {"ok": false, "error": "Only clan leaders can challenge another clan."}
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var source_clan: Dictionary = _account_clan(account)
	var target_id: String = _local_clan_id_by_name(target_clan_name)
	if target_id == "":
		return {"ok": false, "error": "Clan not found."}
	if target_id == str(source_clan.get("id", "")):
		return {"ok": false, "error": "A clan cannot wage war against itself."}
	if _active_wars_for_clan(str(source_clan.get("id", ""))) >= ClanConfig.MAX_ACTIVE_WARS:
		return {"ok": false, "error": "This clan has too many active wars."}
	var war_id: String = _make_local_id("war")
	local_clan_wars[war_id] = {
		"id": war_id,
		"attacking_clan_id": str(source_clan.get("id", "")),
		"attacking_clan_name": str(source_clan.get("name", "")),
		"defending_clan_id": target_id,
		"defending_clan_name": str((local_clans[target_id] as Dictionary).get("name", "")),
		"status": "pending",
		"created_at_unix": Time.get_unix_time_from_system(),
		"accepted_at_unix": 0,
		"completed_at_unix": 0,
		"scheduled_battle_id": "",
		"attacking_score": 0,
		"defending_score": 0
	}
	save_accounts()
	return {"ok": true, "war": local_clan_wars[war_id]}


func respond_to_war(war_id: String, accepted: bool) -> Dictionary:
	if not _is_current_clan_leader():
		return {"ok": false, "error": "Only clan leaders can respond to war challenges."}
	if not local_clan_wars.has(war_id):
		return {"ok": false, "error": "War challenge not found."}
	var war: Dictionary = local_clan_wars[war_id] as Dictionary
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var clan: Dictionary = _account_clan(account)
	if str(war.get("defending_clan_id", "")) != str(clan.get("id", "")):
		return {"ok": false, "error": "This challenge is for another clan."}
	war["status"] = "accepted" if accepted else "cancelled"
	war["accepted_at_unix"] = Time.get_unix_time_from_system() if accepted else 0
	local_clan_wars[war_id] = war
	save_accounts()
	return {"ok": true, "war": war}


func schedule_clan_battle(war_id: String, start_unix: int) -> Dictionary:
	if not _is_current_clan_leader():
		return {"ok": false, "error": "Only clan leaders can schedule clan battles."}
	if not local_clan_wars.has(war_id):
		return {"ok": false, "error": "War not found."}
	var now: int = Time.get_unix_time_from_system()
	if start_unix < now + ClanConfig.BATTLE_PREP_SECONDS:
		return {"ok": false, "error": "Battle must be scheduled at least 30 minutes in the future."}
	var war: Dictionary = local_clan_wars[war_id] as Dictionary
	if str(war.get("status", "")) != "accepted":
		return {"ok": false, "error": "War must be accepted before scheduling a battle."}
	var clan_a: String = str(war.get("attacking_clan_id", ""))
	var clan_b: String = str(war.get("defending_clan_id", ""))
	if _has_overlapping_battle(clan_a, start_unix) or _has_overlapping_battle(clan_b, start_unix):
		return {"ok": false, "error": "One of these clans already has a battle at that time."}
	var battle_id: String = _make_local_id("battle")
	local_clan_battles[battle_id] = {
		"id": battle_id,
		"war_id": war_id,
		"clan_a_id": clan_a,
		"clan_b_id": clan_b,
		"clan_a_name": str(war.get("attacking_clan_name", "")),
		"clan_b_name": str(war.get("defending_clan_name", "")),
		"scheduled_start_unix": start_unix,
		"actual_start_unix": 0,
		"end_unix": start_unix + ClanConfig.BATTLE_DURATION_SECONDS,
		"status": "scheduled",
		"clan_a_score": 0,
		"clan_b_score": 0,
		"winning_clan_id": "",
		"created_by_leader_id": current_account_id,
		"participants": {}
	}
	war["scheduled_battle_id"] = battle_id
	local_clan_wars[war_id] = war
	save_accounts()
	return {"ok": true, "battle": local_clan_battles[battle_id]}


func join_scheduled_battle(battle_id: String) -> Dictionary:
	if not _has_current_mutable_account() or not local_clan_battles.has(battle_id):
		return {"ok": false, "error": "Battle not found."}
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var clan: Dictionary = _account_clan(account)
	var battle: Dictionary = local_clan_battles[battle_id] as Dictionary
	var clan_id: String = str(clan.get("id", ""))
	if clan_id != str(battle.get("clan_a_id", "")) and clan_id != str(battle.get("clan_b_id", "")):
		return {"ok": false, "error": "Only members of the battling clans can join."}
	var participants: Dictionary = battle.get("participants", {}) as Dictionary
	if participants.has(current_account_id):
		return {"ok": true, "participant": participants[current_account_id]}
	participants[current_account_id] = {
		"battle_id": battle_id,
		"player_id": current_account_id,
		"player_name": str(account.get("player_name", "Player")),
		"clan_id": clan_id,
		"kills": 0,
		"deaths": 0,
		"damage_dealt": 0,
		"healing_done": 0,
		"reward_claimed": false,
		"joined_at_unix": Time.get_unix_time_from_system(),
		"left_at_unix": 0
	}
	battle["participants"] = participants
	local_clan_battles[battle_id] = battle
	save_accounts()
	return {"ok": true, "participant": participants[current_account_id]}


func record_clan_battle_kill(battle_id: String, killer_player_id: String, defeated_player_id: String) -> Dictionary:
	if not local_clan_battles.has(battle_id):
		return {"ok": false, "error": "Battle not found."}
	var battle: Dictionary = local_clan_battles[battle_id] as Dictionary
	var participants: Dictionary = battle.get("participants", {}) as Dictionary
	if not participants.has(killer_player_id) or not participants.has(defeated_player_id):
		return {"ok": false, "error": "Both players must be battle participants."}
	var killer: Dictionary = participants[killer_player_id] as Dictionary
	var defeated: Dictionary = participants[defeated_player_id] as Dictionary
	if str(killer.get("clan_id", "")) == str(defeated.get("clan_id", "")):
		return {"ok": false, "error": "Friendly kills do not score."}
	killer["kills"] = int(killer.get("kills", 0)) + 1
	defeated["deaths"] = int(defeated.get("deaths", 0)) + 1
	participants[killer_player_id] = killer
	participants[defeated_player_id] = defeated
	if str(killer.get("clan_id", "")) == str(battle.get("clan_a_id", "")):
		battle["clan_a_score"] = int(battle.get("clan_a_score", 0)) + ClanConfig.BATTLE_POINTS_PER_KILL
	else:
		battle["clan_b_score"] = int(battle.get("clan_b_score", 0)) + ClanConfig.BATTLE_POINTS_PER_KILL
	battle["participants"] = participants
	local_clan_battles[battle_id] = battle
	save_accounts()
	return {"ok": true, "battle": battle}


func complete_clan_battle(battle_id: String) -> Dictionary:
	if not local_clan_battles.has(battle_id):
		return {"ok": false, "error": "Battle not found."}
	var battle: Dictionary = local_clan_battles[battle_id] as Dictionary
	if str(battle.get("status", "")) == "completed":
		return {"ok": true, "battle": battle}
	var clan_a_score: int = int(battle.get("clan_a_score", 0))
	var clan_b_score: int = int(battle.get("clan_b_score", 0))
	var winning_clan_id: String = ""
	if clan_a_score > clan_b_score:
		winning_clan_id = str(battle.get("clan_a_id", ""))
	elif clan_b_score > clan_a_score:
		winning_clan_id = str(battle.get("clan_b_id", ""))
	battle["winning_clan_id"] = winning_clan_id
	battle["status"] = "completed"
	battle["end_unix"] = Time.get_unix_time_from_system()
	local_clan_battles[battle_id] = battle
	_apply_battle_result_to_clans(battle)
	save_accounts()
	return {"ok": true, "battle": battle}


func claim_clan_battle_reward(battle_id: String, player_node: Node = null) -> Dictionary:
	if not _has_current_mutable_account() or not local_clan_battles.has(battle_id):
		return {"ok": false, "error": "Battle not found."}
	var battle: Dictionary = local_clan_battles[battle_id] as Dictionary
	if str(battle.get("status", "")) != "completed":
		return {"ok": false, "error": "Battle is not complete."}
	var participants: Dictionary = battle.get("participants", {}) as Dictionary
	if not participants.has(current_account_id):
		return {"ok": false, "error": "Only participants can claim battle rewards."}
	var participant: Dictionary = participants[current_account_id] as Dictionary
	if bool(participant.get("reward_claimed", false)):
		return {"ok": false, "error": "Battle reward already claimed."}
	var won: bool = str(participant.get("clan_id", "")) == str(battle.get("winning_clan_id", ""))
	var xp: int = ClanConfig.WINNER_XP_REWARD if won else ClanConfig.LOSER_XP_REWARD
	var gold: int = ClanConfig.WINNER_GOLD_REWARD if won else ClanConfig.LOSER_GOLD_REWARD
	if player_node != null and player_node.has_method("gain_reward"):
		player_node.call("gain_reward", xp, gold, "")
	else:
		var account: Dictionary = accounts[current_account_id] as Dictionary
		account["xp"] = int(account.get("xp", 0)) + xp
		account["gold"] = int(account.get("gold", 0)) + gold
		account["updated_at_unix"] = Time.get_unix_time_from_system()
		accounts[current_account_id] = account
	participant["reward_claimed"] = true
	participants[current_account_id] = participant
	battle["participants"] = participants
	local_clan_battles[battle_id] = battle
	save_accounts()
	return {"ok": true, "xp": xp, "gold": gold}


func update_progress_snapshot(player: Node) -> void:
	if player == null or not _has_current_mutable_account():
		return
	var account: Dictionary = accounts[current_account_id] as Dictionary
	account["player_name"] = str(player.stats.get("name", account.get("player_name", "Viking")))
	account["character_id"] = str(player.get("character_id"))
	account["level"] = int(player.stats.get("level", 1))
	account["xp"] = int(player.stats.get("xp", 0))
	account["hp"] = int(player.stats.get("hp", Balance.BASE_PLAYER_MAX_HP))
	account["max_hp"] = int(player.stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP))
	account["attack"] = int(player.stats.get("attack", Balance.BASE_PLAYER_ATTACK))
	account["gold"] = int(player.stats.get("gold", 0))
	account["inventory"] = player.inventory.duplicate(true)
	account["equipment"] = player.get("equipment").duplicate(true)
	account["skills"] = (player.get("skill_state") as Dictionary).duplicate(true)
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
	elif world_map != null and world_map.has_method("world_to_lat_lon"):
		var lat_lon: Vector2 = world_map.call("world_to_lat_lon", player.global_position)
		geo = {"latitude": lat_lon.x, "longitude": lat_lon.y}

	var payload: Dictionary = {
		"account_id": current_account_id,
		"player_name": str(player.stats.get("name", account.get("player_name", "Viking"))),
		"character_id": str(player.get("character_id")),
		"level": int(player.stats.get("level", 1)),
		"xp": int(player.stats.get("xp", 0)),
		"hp": int(player.stats.get("hp", Balance.BASE_PLAYER_MAX_HP)),
		"max_hp": int(player.stats.get("max_hp", Balance.BASE_PLAYER_MAX_HP)),
		"attack": int(player.stats.get("attack", Balance.BASE_PLAYER_ATTACK)),
		"gold": int(player.stats.get("gold", 0)),
		"inventory": player.inventory.duplicate(true),
		"equipment": player.get("equipment").duplicate(true),
		"skills": (player.get("skill_state") as Dictionary).duplicate(true),
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


func _sync_friend_invite_to_backend(friend_name: String) -> void:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/friends/invite", {"friend_name": friend_name}, headers)


func _sync_friend_invite_response_to_backend(friend_name: String, accepted: bool) -> void:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	var action: String = "accept" if accepted else "decline"
	await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/friends/invite/respond", {"friend_name": friend_name, "action": action}, headers)


func _sync_clan_create_to_backend(clan_name: String, perk_type: String) -> Dictionary:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	var response: Dictionary = await _http_json(
		HTTPClient.METHOD_POST,
		BACKEND_BASE_URL + "/clans/create",
		{"clan_name": clan_name, "perk_type": perk_type},
		headers
	)
	var data: Dictionary = response.get("data", {}) as Dictionary
	if bool(response.get("ok", false)):
		response["clan"] = data.get("clan", {})
		response["gold"] = int(data.get("gold", int(account.get("gold", 0))))
	return response


func _sync_clan_join_to_backend(clan_name: String) -> Dictionary:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	var response: Dictionary = await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/clans/join", {"clan_name": clan_name}, headers)
	var data: Dictionary = response.get("data", {}) as Dictionary
	if bool(response.get("ok", false)):
		response["clan"] = data.get("clan", {})
	return response


func _sync_clan_leave_to_backend() -> void:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/clans/leave", {}, headers)


func _sync_clan_disband_to_backend() -> Dictionary:
	var account: Dictionary = get_current_account()
	var headers: Array[String] = _auth_headers(account)
	return await _http_json(HTTPClient.METHOD_POST, BACKEND_BASE_URL + "/clans/disband", {}, headers)


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
		"hp": int(data.get("hp", Balance.BASE_PLAYER_MAX_HP)),
		"max_hp": int(data.get("max_hp", Balance.BASE_PLAYER_MAX_HP)),
		"attack": int(data.get("attack", Balance.BASE_PLAYER_ATTACK)),
		"gold": int(data.get("gold", 0)),
		"inventory": _array_from_variant(data.get("inventory", [])),
		"equipment": data.get("equipment", {}),
		"skills": data.get("skills", {}),
		"last_position": data.get("last_position", {}),
		"last_latitude": data.get("last_latitude", null),
		"last_longitude": data.get("last_longitude", null),
		"friends": _array_from_variant(data.get("friends", [])),
		"friend_invites_received": _array_from_variant(data.get("friend_invites_received", [])),
		"friend_invites_sent": _array_from_variant(data.get("friend_invites_sent", [])),
		"notifications": _array_from_variant(data.get("notifications", [])),
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
		"hp": Balance.BASE_PLAYER_MAX_HP,
		"max_hp": Balance.BASE_PLAYER_MAX_HP,
		"attack": Balance.BASE_PLAYER_ATTACK,
		"gold": 0,
		"inventory": ["Common Viking Axe", "Wood", "Wood", "Wood", "Wood", "Wood", "Stone", "Stone", "Stone", "Herb", "Herb", "Mushroom", "Crystal Vial"],
		"equipment": {"weapon": "", "armor": "", "trinket": ""},
		"skills": {"available_skill_points": 0, "total_skill_points_earned": 0, "unlocked_skills": {}},
		"friends": [],
		"friend_invites_received": [],
		"friend_invites_sent": [],
		"notifications": [],
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


func _get_invites_from_account(account: Dictionary, key: String) -> Array:
	var invites: Array = []
	var raw: Variant = account.get(key, [])
	if raw is Array:
		for invite in raw:
			var invite_name: String = str(invite).strip_edges()
			if invite_name != "" and not invites.has(invite_name):
				invites.append(invite_name)
	return invites


func _find_account_id_by_player_or_email(name_or_email: String) -> String:
	var clean: String = name_or_email.strip_edges()
	var clean_email: String = _normalize_email(clean)
	for account_id in accounts.keys():
		var account: Dictionary = accounts[account_id] as Dictionary
		if str(account.get("player_name", "")).to_lower() == clean.to_lower():
			return str(account_id)
		if _normalize_email(str(account.get("email", account.get("username", "")))) == clean_email:
			return str(account_id)
	return ""


func _account_clan(account: Dictionary) -> Dictionary:
	var raw: Variant = account.get("clan", {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


func _current_gold(account: Dictionary, player: Node = null) -> int:
	if player != null and player.get("stats") is Dictionary:
		return int((player.get("stats") as Dictionary).get("gold", account.get("gold", 0)))
	return int(account.get("gold", 0))


func _local_clan_name_exists(clan_name: String) -> bool:
	return _local_clan_id_by_name(clan_name) != ""


func _local_clan_id_by_name(clan_name: String) -> String:
	var needle: String = clan_name.strip_edges().to_lower()
	for clan_id in local_clans.keys():
		var clan: Dictionary = local_clans[clan_id] as Dictionary
		if str(clan.get("name", "")).to_lower() == needle:
			return str(clan_id)
	return ""


func _clan_member_dict(account_id: String, account: Dictionary, role: String) -> Dictionary:
	return {
		"clan_id": "",
		"player_id": account_id,
		"player_name": str(account.get("player_name", "Player")),
		"role": role,
		"joined_at_unix": Time.get_unix_time_from_system()
	}


func _public_clan_for_account(clan: Dictionary, role: String) -> Dictionary:
	var members: Dictionary = clan.get("members", {}) as Dictionary
	var leader_id: String = str(clan.get("leader_id", clan.get("founder_account_id", "")))
	return {
		"id": str(clan.get("id", "")),
		"name": str(clan.get("name", "Clan")),
		"role": role,
		"leader_id": leader_id,
		"leader_name": str(clan.get("leader_name", "Leader")),
		"perk_type": ClanConfig.valid_perk_id(str(clan.get("perk_type", "xp_boost"))),
		"member_count": int(clan.get("member_count", members.size())),
		"max_members": int(clan.get("max_members", ClanConfig.MAX_CLAN_MEMBERS)),
		"wins": int(clan.get("wins", 0)),
		"losses": int(clan.get("losses", 0)),
		"draws": int(clan.get("draws", 0)),
		"reputation": int(clan.get("reputation", 0)),
		"active_wars": _active_wars_for_clan(str(clan.get("id", "")))
	}


func _is_current_clan_leader() -> bool:
	if not _has_current_mutable_account():
		return false
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var clan: Dictionary = _account_clan(account)
	var role: String = str(clan.get("role", "")).to_lower()
	return role == "leader" or role == "founder"


func _active_wars_for_clan(clan_id: String) -> int:
	var count: int = 0
	for war_id in local_clan_wars.keys():
		var war: Dictionary = local_clan_wars[war_id] as Dictionary
		var status: String = str(war.get("status", ""))
		if status == "completed" or status == "cancelled":
			continue
		if str(war.get("attacking_clan_id", "")) == clan_id or str(war.get("defending_clan_id", "")) == clan_id:
			count += 1
	return count


func _has_overlapping_battle(clan_id: String, start_unix: int) -> bool:
	var end_unix: int = start_unix + ClanConfig.BATTLE_DURATION_SECONDS
	for battle_id in local_clan_battles.keys():
		var battle: Dictionary = local_clan_battles[battle_id] as Dictionary
		var status: String = str(battle.get("status", ""))
		if status == "completed" or status == "cancelled":
			continue
		if str(battle.get("clan_a_id", "")) != clan_id and str(battle.get("clan_b_id", "")) != clan_id:
			continue
		var other_start: int = int(battle.get("scheduled_start_unix", 0))
		var other_end: int = int(battle.get("end_unix", other_start + ClanConfig.BATTLE_DURATION_SECONDS))
		if start_unix < other_end and end_unix > other_start:
			return true
	return false


func _apply_battle_result_to_clans(battle: Dictionary) -> void:
	var clan_a_id: String = str(battle.get("clan_a_id", ""))
	var clan_b_id: String = str(battle.get("clan_b_id", ""))
	var winning_clan_id: String = str(battle.get("winning_clan_id", ""))
	for clan_id in [clan_a_id, clan_b_id]:
		if not local_clans.has(clan_id):
			continue
		var clan: Dictionary = local_clans[clan_id] as Dictionary
		if winning_clan_id == "":
			clan["draws"] = int(clan.get("draws", 0)) + 1
			clan["reputation"] = int(clan.get("reputation", 0)) + ClanConfig.LOSER_REPUTATION_REWARD
		elif clan_id == winning_clan_id:
			clan["wins"] = int(clan.get("wins", 0)) + 1
			clan["reputation"] = int(clan.get("reputation", 0)) + ClanConfig.WINNER_REPUTATION_REWARD
		else:
			clan["losses"] = int(clan.get("losses", 0)) + 1
			clan["reputation"] = int(clan.get("reputation", 0)) + ClanConfig.LOSER_REPUTATION_REWARD
		clan["updated_at_unix"] = Time.get_unix_time_from_system()
		local_clans[clan_id] = clan


func _make_local_id(prefix: String) -> String:
	return prefix + "_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())


func _add_notification(message: String) -> void:
	if not _has_current_mutable_account():
		return
	var account: Dictionary = accounts[current_account_id] as Dictionary
	var notifications: Array = _notifications_with_message(account, message)
	account["notifications"] = notifications
	account["updated_at_unix"] = Time.get_unix_time_from_system()
	accounts[current_account_id] = account
	save_accounts()
	notifications_changed.emit(notifications.duplicate(true))


func _notifications_with_message(account: Dictionary, message: String) -> Array:
	var notifications: Array = _array_from_variant(account.get("notifications", []))
	notifications.push_front({
		"message": message,
		"created_at_unix": Time.get_unix_time_from_system(),
		"read": false
	})
	while notifications.size() > 12:
		notifications.pop_back()
	return notifications


func _array_from_variant(value: Variant) -> Array:
	var output: Array = []
	if value is Array:
		for item in value:
			output.append(item)
	return output
