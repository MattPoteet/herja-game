extends Node

signal gps_origin_ready(latitude: float, longitude: float, from_device: bool)

const DEFAULT_LATITUDE: float = 35.3229
const DEFAULT_LONGITUDE: float = -83.8074
const GPS_OVERRIDE_PATH: String = "user://gps_override.json"

var latitude: float = DEFAULT_LATITUDE
var longitude: float = DEFAULT_LONGITUDE
var has_real_fix: bool = false
var source_label: String = "default"

func initialize() -> void:
	_load_override_position()
	_try_mobile_gps_plugin()
	gps_origin_ready.emit(latitude, longitude, has_real_fix)

func get_origin() -> Dictionary:
	return {
		"latitude": latitude,
		"longitude": longitude,
		"has_real_fix": has_real_fix,
		"source": source_label
	}

func set_debug_origin(new_latitude: float, new_longitude: float) -> void:
	latitude = new_latitude
	longitude = new_longitude
	has_real_fix = true
	source_label = "debug_override"

	var file: FileAccess = FileAccess.open(GPS_OVERRIDE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"latitude": latitude, "longitude": longitude}, "\t"))
		file.close()

func _load_override_position() -> void:
	if not FileAccess.file_exists(GPS_OVERRIDE_PATH):
		return

	var file: FileAccess = FileAccess.open(GPS_OVERRIDE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		var data: Dictionary = parsed as Dictionary
		latitude = float(data.get("latitude", latitude))
		longitude = float(data.get("longitude", longitude))
		has_real_fix = true
		source_label = "saved_override"

func _try_mobile_gps_plugin() -> void:
	# Godot itself does not ship one universal GPS API for every export target.
	# This hook supports common GPS/location plugins if you add one later.
	# Without a plugin, the game still uses a GPS coordinate origin and lets the
	# player move freely over the coordinate-based world.
	var singleton_names: Array[String] = ["GodotLocation", "Location", "GPS"]
	for singleton_name: String in singleton_names:
		if not Engine.has_singleton(singleton_name):
			continue

		var gps_singleton: Object = Engine.get_singleton(singleton_name)
		if gps_singleton == null:
			continue

		if gps_singleton.has_method("start"):
			gps_singleton.call("start")

		var fix: Variant = null
		if gps_singleton.has_method("get_last_known_location"):
			fix = gps_singleton.call("get_last_known_location")
		elif gps_singleton.has_method("get_location"):
			fix = gps_singleton.call("get_location")

		if fix is Dictionary:
			var data: Dictionary = fix as Dictionary
			if data.has("latitude") and data.has("longitude"):
				latitude = float(data["latitude"])
				longitude = float(data["longitude"])
				has_real_fix = true
				source_label = singleton_name
				return
