class_name PelletLaunchFish
extends CharacterBody2D

signal breached_surface(fish: PelletLaunchFish, at_pos: Vector2)
signal splashed_down(fish: PelletLaunchFish, at_pos: Vector2)

@export var player_id: int = 0
@export var is_bot: bool = false
@export var player_name: String = "Fish"
@export var player_color: Color = Color.WHITE
@export var team_id: int = 0

var tank_min_x: float = 100.0
var tank_max_x: float = 900.0
var water_surface_y: float = 620.0
var tank_floor_y: float = 1000.0

# Movement physics
const SWIM_SPEED_X: float = 380.0
const SWIM_SPEED_Y: float = 320.0
const LAUNCH_IMPULSE: float = -950.0
const AIR_GRAVITY: float = 1150.0
const AIR_STEER_SPEED: float = 280.0

var is_airborne: bool = false
var input_prefix: String = "p1_"

# Visual nodes
var _sprite: Sprite2D
var _name_label: Label
var _bubble_trail_timer: float = 0.0

# Bot AI state
var bot_target_x: float = 0.0
var bot_target_pellet: Node2D = null
var bot_action_timer: float = 0.0

const SKIN_ROW_OFFSETS: Array[int] = [0, 16, 32, 48]

func _ready() -> void:
	add_to_group("fish")
	input_prefix = "p%d_" % (player_id + 1)
	_build_visuals()

func _build_visuals() -> void:
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 26.0
	col.shape = shape
	add_child(col)

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://entities/fish/Fish_Sprite_Sheet_16.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = 16
	_sprite.vframes = 24
	_sprite.frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
	_sprite.scale = Vector2(3.0, 3.0)
	_sprite.modulate = player_color.lerp(Color.WHITE, 0.3)
	add_child(_sprite)

	_name_label = Label.new()
	_name_label.text = player_name
	_name_label.position = Vector2(-60, -56)
	_name_label.custom_minimum_size = Vector2(120, 24)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", player_color.lerp(Color.WHITE, 0.6))
	add_child(_name_label)

func _physics_process(delta: float) -> void:
	var was_airborne = is_airborne

	if is_bot:
		_process_bot_ai(delta)
	else:
		_process_human_input(delta)

	# Transition checks between underwater and airborne
	if not was_airborne and position.y < water_surface_y:
		is_airborne = true
		breached_surface.emit(self, position)
	elif was_airborne and position.y >= water_surface_y:
		is_airborne = false
		splashed_down.emit(self, position)
		# Water resistance on re-entry
		velocity.y *= 0.28
		velocity.x *= 0.65

	# Clamping inside tank boundaries
	position.x = clampf(position.x, tank_min_x, tank_max_x)
	if not is_airborne:
		position.y = clampf(position.y, water_surface_y, tank_floor_y)
	else:
		position.y = maxf(position.y, 80.0) # Ceil

	move_and_slide()
	_animate_visuals(delta)

func _process_human_input(delta: float) -> void:
	var move_x = Input.get_axis(input_prefix + "left", input_prefix + "right")
	var move_y = Input.get_axis(input_prefix + "up", input_prefix + "down")
	var jump_pressed = Input.is_action_pressed(input_prefix + "jump") or Input.is_action_pressed(input_prefix + "action")

	if is_airborne:
		# In air: affected by gravity and gentle air steering
		velocity.y += AIR_GRAVITY * delta
		velocity.x = lerpf(velocity.x, move_x * AIR_STEER_SPEED, 0.12)
	else:
		# Underwater: swimming physics
		var target_vx = move_x * SWIM_SPEED_X
		velocity.x = lerpf(velocity.x, target_vx, 0.22)

		var target_vy = move_y * SWIM_SPEED_Y
		if jump_pressed or move_y < -0.2:
			# Upward swimming boost
			target_vy = -SWIM_SPEED_Y * 1.35

		velocity.y = lerpf(velocity.y, target_vy, 0.25)

		# Check for launch trigger as the fish reaches the water surface
		if (jump_pressed or move_y < -0.1) and position.y <= water_surface_y + 35.0:
			velocity.y = LAUNCH_IMPULSE
			is_airborne = true
			breached_surface.emit(self, position)

func _process_bot_ai(delta: float) -> void:
	bot_action_timer -= delta

	if is_airborne:
		velocity.y += AIR_GRAVITY * delta
		if bot_target_pellet and is_instance_valid(bot_target_pellet):
			var steer_dir = signf(bot_target_pellet.global_position.x - position.x)
			velocity.x = lerpf(velocity.x, steer_dir * AIR_STEER_SPEED, 0.15)
		else:
			velocity.x = lerpf(velocity.x, 0.0, 0.08)
	else:
		# Underwater: align horizontally with closest pellet and launch
		if bot_action_timer <= 0.0:
			bot_action_timer = randf_range(0.2, 0.5)

		if bot_target_pellet and is_instance_valid(bot_target_pellet):
			var target_x = bot_target_pellet.global_position.x
			var dx = target_x - position.x

			if abs(dx) > 40.0:
				velocity.x = lerpf(velocity.x, signf(dx) * SWIM_SPEED_X, 0.2)
				# Dive down slightly to prepare for launch
				velocity.y = lerpf(velocity.y, 140.0, 0.15)
			else:
				# Aligned! Power launch toward the surface
				velocity.x = lerpf(velocity.x, dx * 3.0, 0.2)
				velocity.y = -SWIM_SPEED_Y * 1.4

				if position.y <= water_surface_y + 40.0:
					velocity.y = LAUNCH_IMPULSE * randf_range(0.9, 1.05)
					is_airborne = true
					breached_surface.emit(self, position)
		else:
			# Idle wandering underwater
			velocity.x = lerpf(velocity.x, sin(Time.get_ticks_msec() / 600.0) * 160.0, 0.1)
			velocity.y = lerpf(velocity.y, sin(Time.get_ticks_msec() / 800.0) * 80.0, 0.1)

func _animate_visuals(delta: float) -> void:
	if not _sprite:
		return

	# Face direction of horizontal motion
	if abs(velocity.x) > 15.0:
		_sprite.scale.x = 3.0 if velocity.x > 0.0 else -3.0

	# Pitch tilt in air
	if is_airborne:
		var target_angle = clampf(velocity.angle() if _sprite.scale.x > 0 else velocity.angle() + PI, -0.6, 0.6)
		_sprite.rotation = lerp_angle(_sprite.rotation, target_angle, delta * 10.0)
		_sprite.frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()] + 2
	else:
		_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, delta * 12.0)
		var base_frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
		if velocity.length_squared() > 400.0:
			_sprite.frame = base_frame + (int(Time.get_ticks_msec() / 130.0) % 4)
		else:
			_sprite.frame = base_frame
