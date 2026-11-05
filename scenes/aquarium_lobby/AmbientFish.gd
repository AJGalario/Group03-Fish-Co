class_name AmbientFish
extends CharacterBody2D

# A decorative fish swimming in the lobby tank.

var vel_x: float = 120.0
var vel_y: float = 40.0
var sprite: Sprite2D
var swim_min_x: float = 120.0
var swim_max_x: float = 1800.0

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://entities/fish/Fish_Sprite_Sheet_16.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = 16
	sprite.vframes = 24
	sprite.frame = randi() % 4 * 16
	sprite.scale = Vector2(3.0, 3.0)
	add_child(sprite)

func setup_player_skin(player_idx: int, tint: Color) -> void:
	# Each player fish uses its own sprite-sheet row and identity color
	if sprite == null:
		return
	sprite.frame = (player_idx % 4) * 16
	sprite.modulate = tint.lightened(0.15)

func _physics_process(delta: float) -> void:
	position.x += vel_x * delta
	position.y += sin(Time.get_ticks_msec() * 0.003) * 60.0 * delta

	if sprite:
		var base: int = int(sprite.frame / 16.0) * 16
		sprite.frame = base + (int(Time.get_ticks_msec() / 160.0) % 4)

	# Face the swim direction: art natively faces LEFT, so moving right
	# needs a mirror flip.
	sprite.scale.x = (-3.0 if vel_x > 0.0 else 3.0)

	if position.x > swim_max_x or position.x < swim_min_x:
		vel_x = -vel_x
