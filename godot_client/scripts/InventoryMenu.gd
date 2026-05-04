extends CanvasLayer

const Balance = preload("res://scripts/Balance.gd")

const POTION_RECIPES: Dictionary = {
	"Health Potion": {
		"recipe": {"Herb": 2, "Mushroom": 1, "Crystal Vial": 1},
		"description": "Restores health."
	},
	"Greater Health Potion": {
		"recipe": {"Herb": 4, "Mushroom": 2, "Crystal Vial": 1, "Small Gem": 1},
		"description": "Restores more health."
	},
	"Mead": {
		"recipe": {"Herb": 1, "Wood": 1},
		"description": "A simple Viking drink that restores health."
	},
	"Rune Tonic": {
		"recipe": {"Rune Dust": 2, "Bone Charm": 1, "Crystal Vial": 1},
		"description": "A magical tonic that grants experience."
	}
}

var player: Node
var building_manager: Node
var account_manager: Node
var hud: Node

var panel: Panel
var title_label: Label
var summary_label: Label
var footer_label: Label
var current_tab: String = "inventory"
var tab_buttons: Dictionary = {}

var inventory_tab: VBoxContainer
var equipment_tab: VBoxContainer
var craft_tab: VBoxContainer
var build_tab: VBoxContainer

var inventory_list: VBoxContainer
var equipment_list: VBoxContainer
var crafting_list: VBoxContainer
var building_list: VBoxContainer


func setup(player_node: Node, building_node: Node, manager: Node = null, hud_node: Node = null) -> void:
	player = player_node
	building_manager = building_node
	account_manager = manager
	hud = hud_node
	_build_ui()
	visible = false
	if player != null and player.has_signal("inventory_changed"):
		player.inventory_changed.connect(_on_inventory_changed)
	if player != null and player.has_signal("equipment_changed"):
		player.equipment_changed.connect(_on_equipment_changed)
	_refresh()


func toggle_visible(tab_name: String = "") -> void:
	if tab_name != "":
		current_tab = tab_name
	visible = not visible
	_refresh()


func show_tab(tab_name: String) -> void:
	current_tab = tab_name
	visible = true
	_refresh()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.64)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	add_child(dim)

	panel = Panel.new()
	panel.position = Vector2(195, 54)
	panel.size = Vector2(890, 615)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.98), Color(0.28, 0.33, 0.43), 18))
	add_child(panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.position = Vector2(22, 18)
	root.size = Vector2(846, 578)
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	title_label = Label.new()
	title_label.text = "Herja"
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74))
	header.add_child(title_label)

	var header_copy: Label = Label.new()
	header_copy.text = "Character, gear, crafting, and settlement building"
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_copy.add_theme_color_override("font_color", Color(0.74, 0.80, 0.88))
	header.add_child(header_copy)

	var close_hint: Label = Label.new()
	close_hint.text = "Press I or Menu to close"
	close_hint.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74))
	header.add_child(close_hint)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size = Vector2(0, 42)
	summary_label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98))
	root.add_child(summary_label)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_add_tab_button(tabs, "Inventory", "inventory")
	_add_tab_button(tabs, "Equipment", "equipment")
	_add_tab_button(tabs, "Craft Potions", "craft")
	_add_tab_button(tabs, "Build", "build")

	inventory_tab = VBoxContainer.new()
	inventory_tab.add_theme_constant_override("separation", 8)
	root.add_child(inventory_tab)

	equipment_tab = VBoxContainer.new()
	equipment_tab.add_theme_constant_override("separation", 8)
	root.add_child(equipment_tab)

	craft_tab = VBoxContainer.new()
	craft_tab.add_theme_constant_override("separation", 8)
	root.add_child(craft_tab)

	build_tab = VBoxContainer.new()
	build_tab.add_theme_constant_override("separation", 8)
	root.add_child(build_tab)

	inventory_list = _make_scroll_list(inventory_tab)
	equipment_list = _make_scroll_list(equipment_tab)
	crafting_list = _make_scroll_list(craft_tab)
	building_list = _make_scroll_list(build_tab)

	footer_label = Label.new()
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.text = "Menu opens gear and inventory. Keyboard shortcuts still work: I inventory, C craft, B build, O social, F5 save."
	footer_label.add_theme_color_override("font_color", Color(0.76, 0.80, 0.86))
	root.add_child(footer_label)


func _make_scroll_list(parent: VBoxContainer) -> VBoxContainer:
	var holder: Panel = Panel.new()
	holder.custom_minimum_size = Vector2(0, 420)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.08, 0.11, 0.98), Color(0.20, 0.24, 0.32), 14))
	parent.add_child(holder)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(818, 404)
	holder.add_child(scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


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


func _button_style(button: Button, is_active: bool = false) -> void:
	var normal_bg: Color = Color(0.13, 0.16, 0.22) if not is_active else Color(0.33, 0.22, 0.10)
	var border: Color = Color(0.29, 0.36, 0.48) if not is_active else Color(0.86, 0.72, 0.46)
	button.add_theme_stylebox_override("normal", _panel_style(normal_bg, border, 10))
	button.add_theme_stylebox_override("hover", _panel_style(normal_bg.lightened(0.1), border.lightened(0.08), 10))
	button.add_theme_stylebox_override("pressed", _panel_style(normal_bg.darkened(0.12), border, 10))
	button.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))


func _small_action_style(button: Button) -> void:
	button.custom_minimum_size = Vector2(120, 34)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.15, 0.20, 0.28), Color(0.35, 0.46, 0.60), 9))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.19, 0.25, 0.34), Color(0.47, 0.60, 0.78), 9))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.11, 0.16, 0.22), Color(0.47, 0.60, 0.78), 9))
	button.add_theme_color_override("font_color", Color(0.95, 0.97, 0.99))


func _add_tab_button(parent: HBoxContainer, label: String, tab_name: String) -> void:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(150, 38)
	button.pressed.connect(func() -> void:
		current_tab = tab_name
		_refresh()
	)
	parent.add_child(button)
	tab_buttons[tab_name] = button


func _is_admin() -> bool:
	if account_manager == null:
		return false
	if account_manager.has_method("is_current_account_admin"):
		return bool(account_manager.call("is_current_account_admin"))
	if account_manager.has_method("get_current_account"):
		var account: Dictionary = account_manager.call("get_current_account") as Dictionary
		return bool(account.get("is_admin", false))
	return false


func _refresh() -> void:
	if player == null:
		return

	var counts: Dictionary = {}
	if player.has_method("get_inventory_counts"):
		counts = player.call("get_inventory_counts") as Dictionary

	var account_name: String = str(player.stats.get("name", "Viking"))
	var level: int = int(player.stats.get("level", 1))
	var total_items: int = 0
	for item_count in counts.values():
		total_items += int(item_count)
	var admin_text: String = "   |   ADMIN MODE" if _is_admin() else ""
	summary_label.text = "Player: %s   |   Level %d   |   Gold: %d   |   Items: %d%s" % [account_name, level, int(player.stats.get("gold", 0)), total_items, admin_text]

	for key in tab_buttons.keys():
		_button_style(tab_buttons[key], key == current_tab)

	inventory_tab.visible = current_tab == "inventory"
	equipment_tab.visible = current_tab == "equipment"
	craft_tab.visible = current_tab == "craft"
	build_tab.visible = current_tab == "build"

	_refresh_inventory(counts)
	_refresh_equipment(counts)
	_refresh_crafting(counts)
	_refresh_building(counts)


func _refresh_inventory(counts: Dictionary) -> void:
	for child in inventory_list.get_children():
		child.queue_free()

	var intro: Label = Label.new()
	intro.text = "Everything your character is carrying right now, grouped for faster use."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(0.73, 0.78, 0.86))
	inventory_list.add_child(intro)

	if counts.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Your pack is empty. Defeat enemies and collect drops to fill it."
		empty_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
		inventory_list.add_child(empty_label)
		return

	var keys: Array = counts.keys()
	keys.sort()
	var items: Array[String] = []
	var weapons: Array[String] = []
	var miscellaneous: Array[String] = []
	for key in keys:
		var item_name: String = str(key)
		match _inventory_category(item_name):
			"weapons":
				weapons.append(item_name)
			"miscellaneous":
				miscellaneous.append(item_name)
			_:
				items.append(item_name)

	_add_inventory_section("Items", items, counts, "Consumables, crafting ingredients, and building materials.")
	_add_inventory_section("Weapons", weapons, counts, "Equippable weapons for your character.")
	_add_inventory_section("Miscellaneous", miscellaneous, counts, "Armor, trinkets, charms, and odd finds.")


func _add_inventory_section(title: String, item_names: Array[String], counts: Dictionary, empty_text: String) -> void:
	var header: Label = Label.new()
	header.text = "%s (%d)" % [title, _count_items_in_section(item_names, counts)]
	header.add_theme_font_size_override("font_size", 19)
	header.add_theme_color_override("font_color", Color(0.94, 0.92, 0.77))
	inventory_list.add_child(header)

	if item_names.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = empty_text
		empty_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
		inventory_list.add_child(empty_label)
		return

	for item_name in item_names:
		_add_inventory_row(item_name, int(counts.get(item_name, 0)))


func _add_inventory_row(item_name: String, item_count: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inventory_list.add_child(row)

	var row_panel: Panel = Panel.new()
	row_panel.custom_minimum_size = Vector2(790, 56)
	row_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.16, 1.0), Color(0.21, 0.25, 0.33), 10))
	row.add_child(row_panel)

	var row_inner: HBoxContainer = HBoxContainer.new()
	row_inner.position = Vector2(12, 10)
	row_inner.size = Vector2(764, 36)
	row_inner.add_theme_constant_override("separation", 10)
	row_panel.add_child(row_inner)

	var name_label: Label = Label.new()
	name_label.text = item_name
	name_label.custom_minimum_size = Vector2(220, 0)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	row_inner.add_child(name_label)

	var count_label: Label = Label.new()
	count_label.text = "x%d" % item_count
	count_label.custom_minimum_size = Vector2(70, 0)
	count_label.add_theme_color_override("font_color", Color(0.75, 0.84, 0.96))
	row_inner.add_child(count_label)

	var desc_label: Label = Label.new()
	desc_label.text = _item_description(item_name)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.79, 0.85))
	row_inner.add_child(desc_label)

	if _is_usable_item(item_name):
		var use_button: Button = Button.new()
		use_button.text = "Use"
		_small_action_style(use_button)
		use_button.pressed.connect(_use_item.bind(item_name))
		row_inner.add_child(use_button)
	elif Balance.is_gear(item_name):
		var equip_button: Button = Button.new()
		equip_button.text = "Equip"
		_small_action_style(equip_button)
		equip_button.disabled = not _can_equip_gear(item_name)
		equip_button.pressed.connect(_equip_item.bind(item_name))
		row_inner.add_child(equip_button)


func _refresh_equipment(counts: Dictionary) -> void:
	for child in equipment_list.get_children():
		child.queue_free()

	var header: Label = Label.new()
	header.text = "Equipment"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.94, 0.92, 0.77))
	equipment_list.add_child(header)

	var attack_value: int = int(player.call("total_attack")) if player.has_method("total_attack") else int(player.stats.get("attack", 0))
	var defense_value: int = int(player.call("total_defense")) if player.has_method("total_defense") else 0
	var summary: Label = Label.new()
	summary.text = "Total attack: %d   Defense: %d" % [attack_value, defense_value]
	summary.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0))
	equipment_list.add_child(summary)

	var current_equipment: Dictionary = {}
	if player.get("equipment") is Dictionary:
		current_equipment = player.get("equipment") as Dictionary

	for slot in Balance.equipment_slots():
		var equipped_item: String = str(current_equipment.get(slot, ""))
		var row_panel: Panel = Panel.new()
		row_panel.custom_minimum_size = Vector2(790, 78)
		row_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.16, 1.0), Color(0.21, 0.25, 0.33), 10))
		equipment_list.add_child(row_panel)

		var row: HBoxContainer = HBoxContainer.new()
		row.position = Vector2(12, 10)
		row.size = Vector2(764, 56)
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)

		var slot_label: Label = Label.new()
		slot_label.text = _slot_display(slot)
		slot_label.custom_minimum_size = Vector2(120, 0)
		slot_label.add_theme_font_size_override("font_size", 18)
		slot_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
		row.add_child(slot_label)

		var item_label: Label = Label.new()
		item_label.text = equipped_item if equipped_item != "" else "Empty"
		item_label.custom_minimum_size = Vector2(180, 0)
		item_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		row.add_child(item_label)

		var desc_label: Label = Label.new()
		desc_label.text = Balance.gear_description(equipped_item) if equipped_item != "" else "Equip gear from your inventory."
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.84))
		row.add_child(desc_label)

		var unequip_button: Button = Button.new()
		unequip_button.text = "Unequip"
		_small_action_style(unequip_button)
		unequip_button.disabled = equipped_item == ""
		unequip_button.pressed.connect(_unequip_slot.bind(slot))
		row.add_child(unequip_button)

	var gear_names: Array = []
	for item_name in counts.keys():
		if Balance.is_gear(str(item_name)):
			gear_names.append(str(item_name))
	gear_names.sort()
	if gear_names.is_empty():
		var empty: Label = Label.new()
		empty.text = "No spare gear in your inventory."
		empty.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
		equipment_list.add_child(empty)
		return

	var spare_header: Label = Label.new()
	spare_header.text = "Gear In Pack"
	spare_header.add_theme_font_size_override("font_size", 17)
	spare_header.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96))
	equipment_list.add_child(spare_header)

	for item_name in gear_names:
		var equip_button: Button = Button.new()
		equip_button.text = "%s  x%d    %s" % [item_name, int(counts[item_name]), Balance.gear_description(item_name)]
		equip_button.custom_minimum_size = Vector2(790, 38)
		_button_style(equip_button, false)
		equip_button.disabled = not _can_equip_gear(item_name)
		equip_button.pressed.connect(_equip_item.bind(item_name))
		equipment_list.add_child(equip_button)


func _refresh_crafting(counts: Dictionary) -> void:
	for child in crafting_list.get_children():
		child.queue_free()

	var header: Label = Label.new()
	header.text = "Potion Crafting"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.94, 0.92, 0.77))
	crafting_list.add_child(header)

	var intro: Label = Label.new()
	intro.text = "Mix gathered herbs and magical materials into useful brews."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(0.73, 0.78, 0.86))
	crafting_list.add_child(intro)

	for item_name in POTION_RECIPES.keys():
		var data: Dictionary = POTION_RECIPES[item_name] as Dictionary
		var recipe: Dictionary = data.get("recipe", {}) as Dictionary
		var row_panel: Panel = Panel.new()
		row_panel.custom_minimum_size = Vector2(790, 82)
		row_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.16, 1.0), Color(0.21, 0.25, 0.33), 10))
		crafting_list.add_child(row_panel)

		var row: VBoxContainer = VBoxContainer.new()
		row.position = Vector2(12, 10)
		row.size = Vector2(764, 60)
		row.add_theme_constant_override("separation", 6)
		row_panel.add_child(row)

		var top: HBoxContainer = HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		row.add_child(top)

		var name_label: Label = Label.new()
		name_label.text = str(item_name)
		name_label.custom_minimum_size = Vector2(220, 0)
		name_label.add_theme_font_size_override("font_size", 18)
		top.add_child(name_label)

		var recipe_label: Label = Label.new()
		recipe_label.text = _recipe_text(recipe)
		recipe_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_label.add_theme_color_override("font_color", Color(0.75, 0.79, 0.85))
		top.add_child(recipe_label)

		var craft_button: Button = Button.new()
		craft_button.text = "Craft"
		_small_action_style(craft_button)
		craft_button.disabled = (not _is_admin()) and not _has_recipe(counts, recipe)
		craft_button.pressed.connect(_craft_item.bind(str(item_name)))
		top.add_child(craft_button)

		var desc_label: Label = Label.new()
		desc_label.text = _craft_description(str(item_name), data)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.69, 0.75, 0.82))
		row.add_child(desc_label)


func _refresh_building(counts: Dictionary) -> void:
	for child in building_list.get_children():
		child.queue_free()

	var header: Label = Label.new()
	header.text = "Build Viking Structures"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.94, 0.92, 0.77))
	building_list.add_child(header)

	var intro: Label = Label.new()
	intro.text = "Spend materials to place useful structures near your character. Stand near a building and press E to use it."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(0.73, 0.78, 0.86))
	building_list.add_child(intro)

	if building_manager == null or not building_manager.has_method("get_structure_types"):
		var missing: Label = Label.new()
		missing.text = "Building manager not loaded."
		building_list.add_child(missing)
		return

	var types: Array = building_manager.call("get_structure_types") as Array
	for structure_type in types:
		var data: Dictionary = building_manager.call("get_structure_data", str(structure_type)) as Dictionary
		var recipe: Dictionary = data.get("recipe", {}) as Dictionary

		var row_panel: Panel = Panel.new()
		row_panel.custom_minimum_size = Vector2(790, 82)
		row_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.16, 1.0), Color(0.21, 0.25, 0.33), 10))
		building_list.add_child(row_panel)

		var row: VBoxContainer = VBoxContainer.new()
		row.position = Vector2(12, 10)
		row.size = Vector2(764, 60)
		row.add_theme_constant_override("separation", 6)
		row_panel.add_child(row)

		var top: HBoxContainer = HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		row.add_child(top)

		var name_label: Label = Label.new()
		name_label.text = str(data.get("name", structure_type))
		name_label.custom_minimum_size = Vector2(220, 0)
		name_label.add_theme_font_size_override("font_size", 18)
		top.add_child(name_label)

		var recipe_label: Label = Label.new()
		recipe_label.text = _recipe_text(recipe)
		recipe_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_label.add_theme_color_override("font_color", Color(0.75, 0.79, 0.85))
		top.add_child(recipe_label)

		var build_button: Button = Button.new()
		build_button.text = "Build"
		_small_action_style(build_button)
		build_button.disabled = (not _is_admin()) and not _has_recipe(counts, recipe)
		build_button.pressed.connect(_build_structure.bind(str(structure_type)))
		top.add_child(build_button)

		var desc_label: Label = Label.new()
		desc_label.text = str(data.get("description", ""))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.69, 0.75, 0.82))
		row.add_child(desc_label)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove nearest building"
	_small_action_style(remove_button)
	remove_button.pressed.connect(func() -> void:
		if building_manager != null and building_manager.has_method("remove_nearest_structure"):
			building_manager.call("remove_nearest_structure")
		_refresh()
	)
	building_list.add_child(remove_button)

	var use_button: Button = Button.new()
	use_button.text = "Use nearest building"
	_small_action_style(use_button)
	use_button.pressed.connect(func() -> void:
		if building_manager != null and building_manager.has_method("use_nearest_structure"):
			building_manager.call("use_nearest_structure")
		_refresh()
	)
	building_list.add_child(use_button)


func _craft_item(item_name: String) -> void:
	if player == null:
		return
	if not POTION_RECIPES.has(item_name):
		return
	var data: Dictionary = POTION_RECIPES[item_name] as Dictionary
	var recipe: Dictionary = data.get("recipe", {}) as Dictionary
	if _is_admin():
		if player.has_method("add_item"):
			player.call("add_item", item_name)
		_set_status("Admin crafted %s without ingredients." % item_name)
	elif player.has_method("remove_items") and bool(player.call("remove_items", recipe)):
		if player.has_method("add_item"):
			player.call("add_item", item_name)
		_set_status("Crafted %s." % item_name)
	else:
		_set_status("Not enough ingredients for %s." % item_name)
	_refresh()


func _build_structure(structure_type: String) -> void:
	if building_manager != null and building_manager.has_method("build_structure"):
		building_manager.call("build_structure", structure_type)
	_refresh()


func _use_item(item_name: String) -> void:
	if player != null and player.has_method("use_item"):
		if bool(player.call("use_item", item_name)):
			_set_status("Used %s." % item_name)
		else:
			_set_status("%s cannot be used right now." % item_name)
	_refresh()


func _equip_item(item_name: String) -> void:
	if player != null and player.has_method("equip_item"):
		if bool(player.call("equip_item", item_name)):
			_set_status("Equipped %s." % item_name)
			current_tab = "equipment"
		else:
			_set_status(_equip_block_message(item_name))
	_refresh()


func _unequip_slot(slot: String) -> void:
	if player != null and player.has_method("unequip_slot"):
		if bool(player.call("unequip_slot", slot)):
			_set_status("Unequipped %s." % _slot_display(slot))
		else:
			_set_status("Nothing equipped in %s." % _slot_display(slot))
	_refresh()


func _on_inventory_changed(_items: Array) -> void:
	_refresh()


func _on_equipment_changed(_equipment: Dictionary) -> void:
	_refresh()


func _has_recipe(counts: Dictionary, recipe: Dictionary) -> bool:
	for item_name in recipe.keys():
		if int(counts.get(item_name, 0)) < int(recipe[item_name]):
			return false
	return true


func _recipe_text(recipe: Dictionary) -> String:
	var keys: Array = recipe.keys()
	keys.sort()
	var parts: Array[String] = []
	for item_name in keys:
		parts.append("%s x%s" % [str(item_name), int(recipe[item_name])])
	return ", ".join(parts)


func _inventory_category(item_name: String) -> String:
	if Balance.is_gear(item_name):
		if Balance.gear_slot(item_name) == "weapon":
			return "weapons"
		return "miscellaneous"
	return "items"


func _count_items_in_section(item_names: Array[String], counts: Dictionary) -> int:
	var total: int = 0
	for item_name in item_names:
		total += int(counts.get(item_name, 0))
	return total


func _is_usable_item(item_name: String) -> bool:
	return item_name == "Health Potion" or item_name == "Greater Health Potion" or item_name == "Mead" or item_name == "Rune Tonic"


func _item_description(item_name: String) -> String:
	if Balance.is_gear(item_name):
		return Balance.gear_description(item_name)
	match item_name:
		"Herb": return "A common healing plant used in potions."
		"Mushroom": return "A forest ingredient for brews and tonics."
		"Crystal Vial": return "A vessel used to bottle crafted potions."
		"Rune Dust": return "Arcane powder gathered from magical foes."
		"Health Potion": return Balance.potion_description(item_name)
		"Greater Health Potion": return Balance.potion_description(item_name)
		"Mead": return Balance.consumable_description(item_name)
		"Rune Tonic": return Balance.consumable_description(item_name)
		"Stone": return "Solid building material for sturdy structures."
		"Wood": return "Useful for watchtowers, docks, and longhouses."
		"Fur": return "Warm crafting material from wild creatures."
		"Iron Ore": return "Smelt later for advanced gear and buildings."
		"Small Gem": return "A rare ingredient used in stronger crafting."
		_: return "A useful resource from your travels."


func _craft_description(item_name: String, data: Dictionary) -> String:
	if _is_usable_item(item_name):
		var description: String = Balance.consumable_description(item_name)
		if description != "":
			return description
	return str(data.get("description", ""))


func _set_status(message: String) -> void:
	if hud != null and hud.has_method("set_status"):
		hud.call("set_status", message)


func _slot_display(slot: String) -> String:
	match slot:
		"weapon": return "Weapon"
		"armor": return "Armor"
		"trinket": return "Trinket"
		_: return slot.capitalize()


func _can_equip_gear(item_name: String) -> bool:
	if player == null:
		return false
	return Balance.can_equip_gear(item_name, str(player.get("character_id")), int(player.stats.get("level", 1)))


func _equip_block_message(item_name: String) -> String:
	if not Balance.is_gear(item_name):
		return "%s is not gear." % item_name
	var required_level: int = Balance.gear_level(item_name)
	if int(player.stats.get("level", 1)) < required_level:
		return "%s requires level %d." % [item_name, required_level]
	var required_class: String = Balance.gear_class(item_name)
	if required_class != "any" and required_class != str(player.get("character_id")):
		return "%s is for %s." % [item_name, _class_display(required_class)]
	return "Could not equip %s." % item_name


func _class_display(character_id: String) -> String:
	match character_id:
		"shield_maiden": return "Shield Maiden"
		"druid": return "Druid"
		"mage": return "Mage"
		_: return "Viking"
