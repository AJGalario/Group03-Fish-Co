class_name CoopEnemy
extends Area2D

## CoopEnemy — Reusable animated hazard for co-op levels (Octopus, Squid, etc.)
## Patrols a configurable path with pixel art walk animations and bumps/stuns fish on contact.

@export var enemy_name: String = "Octopus"
@export_enum("horizontal", "vertical") var patrol_axis: String = "horizontal"
@export var patrol_distance: float = 220.0
@export var move_speed: float = 90.0

@export var walk_texture: Texture2D
@export var attack_texture: Texture2D
@export var frame_count: int = 6
@export var animation_fps: float = 7.0

var _start_pos: Vector2
var _direction: float = 1.0
var _is_attacking: bool = false
var _attack_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _col_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Monitors Layer 2 (Fish)
	monitoring = true
	monitorable = false

	_start_pos = position

	if _sprite and walk_texture:
		_sprite.texture = walk_texture
		_sprite.hframes = frame_count
		_sprite.vframes = 1
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_process_patrol(delta)
	_process_animation(delta)

func _process_patrol(delta: float) -> void:
	if patrol_distance <= 0.0:
		return

	var move_delta: float = move_speed * _direction * delta

	if patrol_axis == "horizontal":
		position.x += move_delta
		var min_x := _start_pos.x - (patrol_distance * 0.5)
		var max_x := _start_pos.x + (patrol_distance * 0.5)

		if position.x >= max_x:
			position.x = max_x
			_direction = -1.0
		elif position.x <= min_x:
			position.x = min_x
			_direction = 1.0

		if _sprite:
			_sprite.flip_h = (_direction > 0.0)
	else:
		position.y += move_delta
		var min_y := _start_pos.y - (patrol_distance * 0.5)
		var max_y := _start_pos.y + (patrol_distance * 0.5)

		if position.y >= max_y:
			position.y = max_y
			_direction = -1.0
		elif position.y <= min_y:
			position.y = min_y
			_direction = 1.0

func _process_animation(delta: float) -> void:
	if not _sprite:
		return

	if _is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_is_attacking = false
			if walk_texture:
				_sprite.texture = walk_texture
				_sprite.hframes = frame_count

	var frame_idx: int = int(Time.get_ticks_msec() / (1000.0 / animation_fps)) % frame_count
	_sprite.frame = frame_idx

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("fish"):
		# Trigger attack animation
		if attack_texture and not _is_attacking:
			_is_attacking = true
			_attack_timer = 0.5
			_sprite.texture = attack_texture
			_sprite.hframes = frame_count

		# Knockback and stun the fish
		var knock_dir := (body.global_position - global_position).normalized()
		if knock_dir.length_squared() < 0.01:
			knock_dir = Vector2.UP
		if body.has_method("stun"):
			body.stun(1.1, knock_dir * 380.0)
