class_name CoopFish
extends CharacterBody2D

## CoopFish — Clean, responsive fish player controller for Co-Op levels.
## Free 8-directional swimming with no lobby claiming prompts.

@export var player_id: int = 0
@export var is_bot: bool = false
@export var player_name: String = "Fish"
@export var player_color: Color = Color.WHITE

var tank_left: float = 100.0
var tank_right: float = 1820.0
var tank_top: float = 110.0
var tank_bottom: float = 1005.0

const SWIM_SPEED: float = 380.0
const ACCEL: float = 18.0

var _input_prefix: String = "p1_"
var _sprite: Sprite2D
var _name_label: Label

const SKIN_ROW_OFFSETS: Array[int] = [0, 16, 32, 48]

func _ready() -> void:
	add_to_group("fish")
	collision_layer = 3  # Layers 1 & 2
	collision_mask = 7   # Layers 1, 2, 3

	_input_prefix = "p%d_" % (player_id + 1)
	_build_visuals()

func _build_visuals() -> void:
	# Physics collision circle
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 24.0
	col.shape = shape
	add_child(col)

	# Fish Sprite
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://entities/fish/Fish_Sprite_Sheet_16.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = 16
	_sprite.vframes = 24
	_sprite.frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
	_sprite.scale = Vector2(2.8, 2.8)
	_sprite.modulate = player_color.lerp(Color.WHITE, 0.35)
	add_child(_sprite)

	# Clean floating name label (no "MOVE TO CLAIM!" or giant box)
	_name_label = Label.new()
	_name_label.text = player_name
	_name_label.position = Vector2(-60, -52)
	_name_label.custom_minimum_size = Vector2(120, 20)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", player_color.lerp(Color.WHITE, 0.65))
	add_child(_name_label)

func _physics_process(delta: float) -> void:
	if is_bot:
		_process_bot(delta)
	else:
		_process_human(delta)

	# Keep inside tank bounds
	position.x = clampf(position.x, tank_left, tank_right)
	position.y = clampf(position.y, tank_top, tank_bottom)

	move_and_slide()
	_animate_swim()

func _process_human(delta: float) -> void:
	var move_x := Input.get_axis(_input_prefix + "left", _input_prefix + "right")
	var move_y := Input.get_axis(_input_prefix + "up", _input_prefix + "down")
	var input_dir := Vector2(move_x, move_y)

	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()

	var target_vel = input_dir * SWIM_SPEED
	velocity = velocity.lerp(target_vel, ACCEL * delta)

func _process_bot(delta: float) -> void:
	# Gentle idle bobbing for bots if present
	var t = Time.get_ticks_msec() / 1000.0 + player_id * 1.5
	var target_vel = Vector2(sin(t * 1.2) * 120.0, cos(t * 0.9) * 80.0)
	velocity = velocity.lerp(target_vel, ACCEL * delta)

func _animate_swim() -> void:
	if not _sprite:
		return

	# Flip sprite according to horizontal movement
	if velocity.x > 15.0:
		_sprite.scale.x = 2.8
	elif velocity.x < -15.0:
		_sprite.scale.x = -2.8

	var base_frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
	if velocity.length_squared() > 400.0:
		_sprite.frame = base_frame + (int(Time.get_ticks_msec() / 130.0) % 4)
	else:
		_sprite.frame = base_frame
