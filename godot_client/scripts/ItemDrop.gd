extends Area2D

const ITEM_SHEET_PATH: String = "res://art/items/items.png"
const ITEM_SIZE: int = 64
const ITEM_COLUMNS: int = 4

const ITEM_INDEX: Dictionary = {
	"Herb": 0,
	"Small Gem": 1,
	"Bone Charm": 2,
	"Iron Ore": 3,
	"Wood": 4,
	"Mushroom": 5,
	"Gold Coin": 6,
	"Rusty Axe": 7,
	"Stone": 8,
	"Fur": 9,
	"Rune Dust": 10,
	"Crystal Vial": 11,
	"Health Potion": 12,
	"Greater Health Potion": 13,
	"Mead": 14,
	"Rune Tonic": 15
}

var item_name: String = "Herb"
var target: Node2D
var sprite: Sprite2D
var name_label: Label


func _ready() -> void:
	add_to_group("items")
	_setup_visuals()


func init(spawn_item_name: String, player: Node2D) -> void:
	item_name = spawn_item_name
	target = player
	_setup_visuals()


func _process(_delta: float) -> void:
	if target == null:
		return

	if global_position.distance_to(target.global_position) <= 34.0:
		if target.has_method("add_item"):
			target.call("add_item", item_name)
		queue_free()


func _setup_visuals() -> void:
	_setup_collision()

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	sprite.texture = _get_item_texture(item_name)
	sprite.centered = true
	sprite.z_index = 9

	name_label = get_node_or_null("NameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		add_child(name_label)

	name_label.text = item_name
	name_label.position = Vector2(-30, -42)
	name_label.z_index = 13


func _setup_collision() -> void:
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape


func _get_item_texture(lookup_name: String) -> Texture2D:
	if not ResourceLoader.exists(ITEM_SHEET_PATH):
		return null

	var texture: Texture2D = load(ITEM_SHEET_PATH) as Texture2D
	if texture == null:
		return null

	var index: int = int(ITEM_INDEX.get(lookup_name, 0))
	var column: int = index % ITEM_COLUMNS
	var row: int = int(index / ITEM_COLUMNS)

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		float(column * ITEM_SIZE),
		float(row * ITEM_SIZE),
		float(ITEM_SIZE),
		float(ITEM_SIZE)
	)

	return atlas
