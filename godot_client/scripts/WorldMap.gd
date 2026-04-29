extends Node2D

signal gps_changed(latitude: float, longitude: float, zoom: int)
signal section_loading_started(section: Vector2i)
signal section_loading_finished(section: Vector2i)

# Free prototype map tiles. For public production, use your own tile server or a
# provider plan that allows your traffic volume.
const TILE_SIZE: int = 256
const DEFAULT_ZOOM: int = 16
const DEFAULT_LATITUDE: float = 35.3229
const DEFAULT_LONGITUDE: float = -83.8074
const TILE_URL_TEMPLATE: String = "https://tile.openstreetmap.org/%d/%d/%d.png"
const USER_AGENT: String = "Herja/0.1 Godot prototype"

# Section loading settings.
# The map only keeps this many OSM tiles loaded at once. When the player crosses
# into the next section, Herja shows a loading overlay, unloads old tiles, and
# loads the next section.
const SECTION_WIDTH_TILES: int = 7
const SECTION_HEIGHT_TILES: int = 5
const SECTION_LOAD_SECONDS: float = 1.25
const SECTION_PRELOAD_BORDER: int = 1

var zoom: int = DEFAULT_ZOOM
var player: Node2D
var loaded_tiles: Dictionary = {}
var pending_tiles: Dictionary = {}
var structure_nodes: Dictionary = {}
var active_section: Vector2i = Vector2i(-999999, -999999)
var loading_section: bool = false
var tile_layer: Node2D
var structure_layer: Node2D
var fallback_layer: Node2D
var origin_world_position: Vector2

var loading_layer: CanvasLayer
var loading_panel: Panel
var loading_label: Label


func _ready() -> void:
	origin_world_position = lat_lon_to_world(DEFAULT_LATITUDE, DEFAULT_LONGITUDE, zoom)
	_ensure_layers()
	_ensure_loading_overlay()


func setup(player_node: Node2D) -> void:
	player = player_node
	_ensure_layers()
	_ensure_loading_overlay()
	if player != null:
		player.global_position = origin_world_position
		player.set("spawn_position", origin_world_position)
	generate_world()


func generate_world() -> void:
	_ensure_layers()
	_ensure_loading_overlay()
	var center: Vector2 = origin_world_position
	if player != null:
		center = player.global_position
	var section: Vector2i = world_to_section(center)
	active_section = section
	_load_section(section, false)


func _process(_delta: float) -> void:
	if player == null:
		return

	var gps: Vector2 = world_to_lat_lon(player.global_position, zoom)
	gps_changed.emit(gps.x, gps.y, zoom)

	if loading_section:
		return

	var current_section: Vector2i = world_to_section(player.global_position)
	if current_section != active_section:
		_begin_section_transition(current_section)


func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / float(TILE_SIZE))), int(floor(pos.y / float(TILE_SIZE))))


func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x * TILE_SIZE), float(tile.y * TILE_SIZE))


func world_to_section(pos: Vector2) -> Vector2i:
	var tile: Vector2i = world_to_tile(pos)
	return Vector2i(
		int(floor(float(tile.x) / float(SECTION_WIDTH_TILES))),
		int(floor(float(tile.y) / float(SECTION_HEIGHT_TILES)))
	)


func section_to_start_tile(section: Vector2i) -> Vector2i:
	return Vector2i(section.x * SECTION_WIDTH_TILES, section.y * SECTION_HEIGHT_TILES)


func section_to_center_world(section: Vector2i) -> Vector2:
	var start_tile: Vector2i = section_to_start_tile(section)
	return tile_to_world(start_tile) + Vector2(
		float(SECTION_WIDTH_TILES * TILE_SIZE) * 0.5,
		float(SECTION_HEIGHT_TILES * TILE_SIZE) * 0.5
	)


func random_walkable_position() -> Vector2:
	var center: Vector2 = origin_world_position
	if player != null:
		center = player.global_position
	var angle: float = randf() * TAU
	var distance: float = randf_range(450.0, 1400.0)
	return center + Vector2(cos(angle), sin(angle)) * distance


func is_walkable(_tile: Vector2i) -> bool:
	# GPS map mode allows the player to move anywhere. Later, you can block oceans,
	# buildings, or private claim areas with gameplay rules.
	return true


func get_player_lat_lon() -> Vector2:
	if player == null:
		return Vector2(DEFAULT_LATITUDE, DEFAULT_LONGITUDE)
	return world_to_lat_lon(player.global_position, zoom)


func lat_lon_to_world(latitude: float, longitude: float, map_zoom: int = DEFAULT_ZOOM) -> Vector2:
	var lat: float = clamp(latitude, -85.05112878, 85.05112878)
	var lon: float = clamp(longitude, -180.0, 180.0)
	var scale: float = pow(2.0, float(map_zoom)) * float(TILE_SIZE)
	var lat_rad: float = deg_to_rad(lat)
	var x: float = (lon + 180.0) / 360.0 * scale
	var y: float = (1.0 - log(tan(lat_rad) + 1.0 / cos(lat_rad)) / PI) / 2.0 * scale
	return Vector2(x, y)


func world_to_lat_lon(world_position: Vector2, map_zoom: int = DEFAULT_ZOOM) -> Vector2:
	var scale: float = pow(2.0, float(map_zoom)) * float(TILE_SIZE)
	var lon: float = world_position.x / scale * 360.0 - 180.0
	var n: float = PI - 2.0 * PI * world_position.y / scale
	var lat: float = rad_to_deg(atan(sinh(n)))
	return Vector2(lat, lon)


func _ensure_layers() -> void:
	if fallback_layer == null:
		fallback_layer = get_node_or_null("FallbackLayer") as Node2D
		if fallback_layer == null:
			fallback_layer = Node2D.new()
			fallback_layer.name = "FallbackLayer"
			fallback_layer.z_index = -20
			add_child(fallback_layer)

	if tile_layer == null:
		tile_layer = get_node_or_null("TileLayer") as Node2D
		if tile_layer == null:
			tile_layer = Node2D.new()
			tile_layer.name = "TileLayer"
			tile_layer.z_index = -10
			add_child(tile_layer)

	if structure_layer == null:
		structure_layer = get_node_or_null("StructureLayer") as Node2D
		if structure_layer == null:
			structure_layer = Node2D.new()
			structure_layer.name = "StructureLayer"
			structure_layer.z_index = 5
			add_child(structure_layer)


func _ensure_loading_overlay() -> void:
	if loading_layer != null:
		return

	loading_layer = CanvasLayer.new()
	loading_layer.name = "MapLoadingLayer"
	loading_layer.layer = 90
	loading_layer.visible = false
	add_child(loading_layer)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.025, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	loading_layer.add_child(dim)

	loading_panel = Panel.new()
	loading_panel.position = Vector2(430, 276)
	loading_panel.size = Vector2(420, 130)
	loading_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.97), Color(0.56, 0.45, 0.24), 16))
	loading_layer.add_child(loading_panel)

	loading_label = Label.new()
	loading_label.position = Vector2(24, 24)
	loading_label.size = Vector2(372, 82)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_label.add_theme_font_size_override("font_size", 22)
	loading_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74))
	loading_panel.add_child(loading_label)


func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _begin_section_transition(new_section: Vector2i) -> void:
	loading_section = true
	active_section = new_section
	section_loading_started.emit(new_section)
	_show_loading_overlay("Loading map section...\nEntering region %d, %d" % [new_section.x, new_section.y])
	if player != null:
		player.set_physics_process(false)

	_load_section(new_section, true)
	await get_tree().create_timer(SECTION_LOAD_SECONDS).timeout

	if player != null:
		player.set_physics_process(true)
	_hide_loading_overlay()
	loading_section = false
	section_loading_finished.emit(new_section)


func _show_loading_overlay(message: String) -> void:
	_ensure_loading_overlay()
	loading_label.text = message
	loading_layer.visible = true


func _hide_loading_overlay() -> void:
	if loading_layer != null:
		loading_layer.visible = false


func _load_section(section: Vector2i, clear_old: bool) -> void:
	var needed: Dictionary = {}
	var start_tile: Vector2i = section_to_start_tile(section)
	var min_x: int = start_tile.x - SECTION_PRELOAD_BORDER
	var max_x: int = start_tile.x + SECTION_WIDTH_TILES + SECTION_PRELOAD_BORDER - 1
	var min_y: int = start_tile.y - SECTION_PRELOAD_BORDER
	var max_y: int = start_tile.y + SECTION_HEIGHT_TILES + SECTION_PRELOAD_BORDER - 1

	_draw_fallback_section(section)

	for ty: int in range(min_y, max_y + 1):
		for tx: int in range(min_x, max_x + 1):
			var tile: Vector2i = Vector2i(tx, ty)
			var key: String = _tile_key(tile)
			needed[key] = true
			if not loaded_tiles.has(key) and not pending_tiles.has(key):
				_request_single_tile(tile)
			_ensure_structures_for_tile(tile)

	if clear_old:
		_cleanup_far_tiles(needed)


func _request_single_tile(tile: Vector2i) -> void:
	var max_tile: int = int(pow(2.0, float(zoom)))
	if tile.y < 0 or tile.y >= max_tile:
		return

	var wrapped_x: int = tile.x % max_tile
	if wrapped_x < 0:
		wrapped_x += max_tile

	var url: String = TILE_URL_TEMPLATE % [zoom, wrapped_x, tile.y]
	var sprite: Sprite2D = Sprite2D.new()
	sprite.centered = false
	sprite.position = tile_to_world(tile)
	sprite.z_index = -10
	tile_layer.add_child(sprite)

	loaded_tiles[_tile_key(tile)] = sprite
	pending_tiles[_tile_key(tile)] = true

	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = 12.0
	add_child(request)
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: " + USER_AGENT,
		"X-Requested-With: com.krampussolutions.herja"
	])
	request.request_completed.connect(_on_tile_request_completed.bind(_tile_key(tile), sprite, request))
	var err: int = request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		pending_tiles.erase(_tile_key(tile))
		request.queue_free()


func _on_tile_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	tile_key: String,
	sprite: Sprite2D,
	request: HTTPRequest
) -> void:
	pending_tiles.erase(tile_key)
	if response_code == 200 and body.size() > 0:
		var image: Image = Image.new()
		var err: int = image.load_png_from_buffer(body)
		if err == OK:
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if is_instance_valid(sprite):
				sprite.texture = texture
				sprite.modulate = Color(0.86, 0.92, 0.86)
	else:
		print("Map tile failed: ", tile_key, " HTTP ", response_code)
	request.queue_free()


func _cleanup_far_tiles(needed: Dictionary) -> void:
	var tile_keys: Array = loaded_tiles.keys()
	for key in tile_keys:
		if not needed.has(key):
			var node: Node = loaded_tiles[key]
			if is_instance_valid(node):
				node.queue_free()
			loaded_tiles.erase(key)
			pending_tiles.erase(key)

	var structure_keys: Array = structure_nodes.keys()
	for key in structure_keys:
		var tile_part: String = str(key).split("|")[0]
		if not needed.has(tile_part):
			var structure: Node = structure_nodes[key]
			if is_instance_valid(structure):
				structure.queue_free()
			structure_nodes.erase(key)


func _draw_fallback_section(section: Vector2i) -> void:
	for child in fallback_layer.get_children():
		child.queue_free()

	var start_tile: Vector2i = section_to_start_tile(section)
	for y: int in range(start_tile.y - SECTION_PRELOAD_BORDER, start_tile.y + SECTION_HEIGHT_TILES + SECTION_PRELOAD_BORDER):
		for x: int in range(start_tile.x - SECTION_PRELOAD_BORDER, start_tile.x + SECTION_WIDTH_TILES + SECTION_PRELOAD_BORDER):
			var rect: ColorRect = ColorRect.new()
			rect.size = Vector2(TILE_SIZE, TILE_SIZE)
			rect.position = tile_to_world(Vector2i(x, y))
			if (x + y) % 3 == 0:
				rect.color = Color(0.13, 0.33, 0.17)
			elif (x + y) % 3 == 1:
				rect.color = Color(0.16, 0.42, 0.20)
			else:
				rect.color = Color(0.12, 0.27, 0.16)
			fallback_layer.add_child(rect)


func _ensure_structures_for_tile(tile: Vector2i) -> void:
	var seed_value: int = int(abs(tile.x * 928371 + tile.y * 364479 + zoom * 811))
	if seed_value % 5 != 0:
		return

	var tile_key: String = _tile_key(tile)
	var structure_key: String = tile_key + "|0"
	if structure_nodes.has(structure_key):
		return

	var types: Array[String] = ["Longhouse", "Rune Stone", "Watchtower", "Dock", "Farmstead", "Shrine"]
	var type_name: String = types[seed_value % types.size()]
	var offset_x: float = 48.0 + float((seed_value / 7) % 150)
	var offset_y: float = 48.0 + float((seed_value / 19) % 150)
	var world_pos: Vector2 = tile_to_world(tile) + Vector2(offset_x, offset_y)

	var marker: Node2D = _make_structure_marker(type_name)
	marker.position = world_pos
	structure_layer.add_child(marker)
	structure_nodes[structure_key] = marker


func _make_structure_marker(type_name: String) -> Node2D:
	var marker: Node2D = Node2D.new()
	marker.name = "Viking" + type_name.replace(" ", "")
	marker.z_index = 6

	var icon: ColorRect = ColorRect.new()
	icon.size = Vector2(20, 20)
	icon.position = Vector2(-10, -10)
	match type_name:
		"Longhouse": icon.color = Color(0.45, 0.24, 0.10)
		"Rune Stone": icon.color = Color(0.42, 0.42, 0.46)
		"Watchtower": icon.color = Color(0.35, 0.20, 0.08)
		"Dock": icon.color = Color(0.25, 0.16, 0.08)
		"Farmstead": icon.color = Color(0.52, 0.42, 0.16)
		"Shrine": icon.color = Color(0.30, 0.22, 0.45)
		_: icon.color = Color(0.4, 0.3, 0.2)
	marker.add_child(icon)

	var outline: ColorRect = ColorRect.new()
	outline.size = Vector2(26, 26)
	outline.position = Vector2(-13, -13)
	outline.color = Color(1.0, 0.85, 0.38, 0.26)
	outline.z_index = -1
	marker.add_child(outline)

	var label: Label = Label.new()
	label.text = type_name
	label.position = Vector2(-36, 13)
	label.size = Vector2(120, 20)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	marker.add_child(label)

	return marker


func _tile_key(tile: Vector2i) -> String:
	return str(tile.x) + ":" + str(tile.y)
