class_name PelletLaunchFish
extends CharacterBody2D

signal breached_surface(fish: PelletLaunchFish, at_pos: Vector2)
signal splashed_down(fish: PelletLaunchFish, at_pos: Vector2, is_belly_flop: bool)

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
const BASE_LAUNCH_IMPULSE: float = -760.0
const AIR_GRAVITY: float = 1150.0
const AIR_STEER_SPEED: float = 290.0

# Charge & Depth mechanics
var charge_level: float = 0.0          # 0.0 to 1.0
var deepest_depth_charge: float = 0.0  # 0.0 to 1.0 (depth ratio reached while charging)
var is_charging: bool = false
var is_propelling: bool = false
var propel_power: float = 0.0

# Stun & Dive mechanics
var is_airborne: bool = false
var is_diving_stance: bool = false
var stun_timer: float = 0.0
const STUN_DURATION: float = 2.0

var input_prefix: String = "p1_"

# Visual nodes
var _sprite: Sprite2D
var _name_label: Label
var _charge_bar_bg: ColorRect
var _charge_bar_fill: ColorRect
var _dive_indicator: Label
var _stun_badge: Label
var _dizzy_stars: Node2D
var _bubble_trail_timer: float = 0.0

# Bot AI state
var bot_target_x: float = 0.0
var bot_target_pellet: Node2D = null
var bot_action_timer: float = 0.0
var bot_dive_intent: bool = true

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

	# Charge bar container
	_charge_bar_bg = ColorRect.new()
	_charge_bar_bg.size = Vector2(52, 8)
	_charge_bar_bg.position = Vector2(-26, -38)
	_charge_bar_bg.color = Color(0.08, 0.12, 0.18, 0.85)
	_charge_bar_bg.visible = false
	add_child(_charge_bar_bg)

	_charge_bar_fill = ColorRect.new()
	_charge_bar_fill.size = Vector2(0, 6)
	_charge_bar_fill.position = Vector2(1, 1)
	_charge_bar_fill.color = Color(0.3, 0.9, 1.0)
	_charge_bar_bg.add_child(_charge_bar_fill)

	# Dive indicator in air
	_dive_indicator = Label.new()
	_dive_indicator.text = ""
	_dive_indicator.position = Vector2(-90, -78)
	_dive_indicator.custom_minimum_size = Vector2(180, 24)
	_dive_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dive_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dive_indicator.add_theme_font_size_override("font_size", 13)
	_dive_indicator.visible = false
	add_child(_dive_indicator)

	# Stun badge on belly flop
	_stun_badge = Label.new()
	_stun_badge.text = ""
	_stun_badge.position = Vector2(-80, -78)
	_stun_badge.custom_minimum_size = Vector2(160, 24)
	_stun_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stun_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stun_badge.add_theme_font_size_override("font_size", 14)
	_stun_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	_stun_badge.visible = false
	add_child(_stun_badge)

	# Orbiting dizzy stars for stun effect
	_dizzy_stars = Node2D.new()
	_dizzy_stars.position = Vector2(0, -32)
	_dizzy_stars.visible = false
	add_child(_dizzy_stars)

	for s in range(3):
		var star = Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 16)
		star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		var angle = s * (TAU / 3.0)
		star.position = Vector2(cos(angle) * 20.0 - 6, sin(angle) * 10.0 - 10)
		_dizzy_stars.add_child(star)

func _physics_process(delta: float) -> void:
	var was_airborne = is_airborne

	# Handle active stun from belly flop
	if stun_timer > 0.0:
		_process_stun_state(delta)
	else:
		if is_bot:
			_process_bot_ai(delta)
		else:
			_process_human_input(delta)

	# Transition checks between underwater and airborne
	if not was_airborne and position.y < water_surface_y:
		# Breached surface into the air
		is_airborne = true
		_on_surface_breached()
	elif was_airborne and position.y >= water_surface_y:
		# Re-entering the water from the air
		is_airborne = false
		_on_water_reentry()

	# Tank horizontal bounds clamping
	position.x = clampf(position.x, tank_min_x, tank_max_x)

	# Vertical bounds clamping
	if not is_airborne:
		position.y = clampf(position.y, water_surface_y, tank_floor_y)
	else:
		position.y = maxf(position.y, 80.0) # Sky ceiling

	move_and_slide()
	_animate_visuals(delta)

func _on_surface_breached() -> void:
	# Calculate total launch impulse determined by depth and propulsion charge
	var current_depth = clampf((position.y - water_surface_y) / (tank_floor_y - water_surface_y), 0.0, 1.0)
	var effective_depth = maxf(deepest_depth_charge, current_depth)
	var effective_charge = maxf(charge_level, propel_power)

	# Power multiplier scales with both depth and charge
	# Uncharged tap near surface = ~0.8x (-608 impulse)
	# Full charge + floor depth = ~1.85x (-1406 impulse)
	var depth_bonus = effective_depth * 0.55
	var charge_bonus = effective_charge * 0.50
	var launch_mult = 0.8 + depth_bonus + charge_bonus

	velocity.y = BASE_LAUNCH_IMPULSE * launch_mult

	# Reset underwater charge state
	charge_level = 0.0
	deepest_depth_charge = 0.0
	is_charging = false
	is_propelling = false
	propel_power = 0.0
	if _charge_bar_bg:
		_charge_bar_bg.visible = false

	breached_surface.emit(self, position)

func _on_water_reentry() -> void:
	# Evaluate whether re-entry was a head-on dive or a belly flop
	# Head-on dive requires pointing downward into the water
	var is_head_on = is_diving_stance or (
		(_sprite.scale.x > 0 and _sprite.rotation >= 0.65) or
		(_sprite.scale.x < 0 and _sprite.rotation <= -0.65)
	)

	is_diving_stance = false
	if _dive_indicator:
		_dive_indicator.visible = false

	if is_head_on:
		# Clean dive! Slice through water with no stun
		splashed_down.emit(self, position, false)
		_show_floating_text("✨ CLEAN DIVE! ✨", Color(0.3, 1.0, 0.8))
		velocity.y = clampf(velocity.y * 0.42, 100.0, 300.0)
		velocity.x *= 0.75
	else:
		# BELLY FLOP! Stunned for 2 seconds
		splashed_down.emit(self, position, true)
		_show_floating_text("💥 BELLY FLOP! 💥", Color(1.0, 0.35, 0.25))
		stun_timer = STUN_DURATION
		velocity.y = -130.0 # Small comedic bounce off the surface
		velocity.x = 0.0
		charge_level = 0.0
		is_charging = false
		is_propelling = false

func _process_stun_state(delta: float) -> void:
	stun_timer = maxf(0.0, stun_timer - delta)
	# Helpless bobbing and sinking
	velocity.x = lerpf(velocity.x, 0.0, 0.2)
	velocity.y = lerpf(velocity.y, 45.0, 0.1)

	# Update stun badge and dizzy stars
	if _stun_badge:
		_stun_badge.visible = true
		_stun_badge.text = "💥 STUNNED (%.1fs)" % stun_timer
	if _dizzy_stars:
		_dizzy_stars.visible = true
		_dizzy_stars.rotation += delta * 6.5

	# Comedic wobble and flashing
	_sprite.rotation = sin(Time.get_ticks_msec() / 70.0) * 0.35
	var flash_val = (sin(Time.get_ticks_msec() / 90.0) * 0.5) + 0.5
	_sprite.modulate = Color(1.0, 0.65, 0.65).lerp(player_color.lerp(Color.WHITE, 0.3), flash_val)

	if stun_timer <= 0.0:
		# Clear stun
		if _stun_badge:
			_stun_badge.visible = false
		if _dizzy_stars:
			_dizzy_stars.visible = false
		_sprite.modulate = player_color.lerp(Color.WHITE, 0.3)
		_sprite.rotation = 0.0
		_show_floating_text("RECOVERED!", Color(0.4, 0.9, 1.0))

func _process_human_input(delta: float) -> void:
	var move_x = Input.get_axis(input_prefix + "left", input_prefix + "right")
	var move_y = Input.get_axis(input_prefix + "up", input_prefix + "down")
	var jump_held = Input.is_action_pressed(input_prefix + "jump") or Input.is_action_pressed(input_prefix + "action")
	var jump_just_released = Input.is_action_just_released(input_prefix + "jump") or Input.is_action_just_released(input_prefix + "action")

	if is_airborne:
		# In air: affected by gravity and horizontal air steering
		velocity.y += AIR_GRAVITY * delta
		velocity.x = lerpf(velocity.x, move_x * AIR_STEER_SPEED, 0.14)

		# Dive controls: Player must steer/aim DOWN to dive head-on
		if velocity.y > 40.0:
			if move_y > 0.2:
				is_diving_stance = true
				if _dive_indicator:
					_dive_indicator.visible = true
					_dive_indicator.text = "⬇ NOSE-DOWN DIVE! ⬇"
					_dive_indicator.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
			else:
				is_diving_stance = false
				if _dive_indicator:
					_dive_indicator.visible = true
					_dive_indicator.text = "⚠️ PRESS [DOWN] TO DIVE!"
					_dive_indicator.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			is_diving_stance = false
			if _dive_indicator:
				_dive_indicator.visible = false
	else:
		# Underwater: Swimming, Charging, and Propelling
		var current_depth = clampf((position.y - water_surface_y) / (tank_floor_y - water_surface_y), 0.0, 1.0)

		# Handle Charging
		if jump_held:
			is_charging = true
			charge_level = minf(charge_level + delta * 1.5, 1.0)
			# Deepest depth reached while charging powers the launch!
			deepest_depth_charge = maxf(deepest_depth_charge, current_depth)
		elif jump_just_released and is_charging:
			# Released charge underwater -> Trigger upward propulsion burst!
			is_charging = false
			if charge_level > 0.15:
				is_propelling = true
				propel_power = charge_level
				var depth_propel_boost = 1.0 + deepest_depth_charge * 0.6
				velocity.y = -SWIM_SPEED_Y * lerpf(1.3, 2.2, charge_level) * depth_propel_boost
				_show_floating_text("PROPEL! 🚀", Color(1.0, 0.9, 0.3))

		# Standard swimming velocities
		var target_vx = move_x * SWIM_SPEED_X
		velocity.x = lerpf(velocity.x, target_vx, 0.22)

		if not is_propelling:
			var target_vy = move_y * SWIM_SPEED_Y
			if jump_held or move_y < -0.2:
				# Upward swimming effort
				target_vy = -SWIM_SPEED_Y * 1.35
			velocity.y = lerpf(velocity.y, target_vy, 0.25)
		else:
			# Decelerate propulsion gradually if still submerged
			velocity.y = lerpf(velocity.y, move_y * SWIM_SPEED_Y, delta * 3.5)
			if velocity.y > -80.0:
				is_propelling = false

		# Update Charge Bar UI
		_update_charge_ui(current_depth)

		# Trigger surface breach launch when fish reaches water surface
		if (jump_held or move_y < -0.1 or is_propelling or velocity.y < -150.0) and position.y <= water_surface_y + 35.0:
			position.y = water_surface_y - 2.0
			is_airborne = true
			_on_surface_breached()

func _update_charge_ui(current_depth: float) -> void:
	if not _charge_bar_bg:
		return

	if is_charging and charge_level > 0.05:
		_charge_bar_bg.visible = true
		var fill_w = charge_level * 50.0
		_charge_bar_fill.size = Vector2(fill_w, 6)

		# Tint from cyan to fiery orange/gold as charge + depth maximize
		var combined_power = (charge_level * 0.5) + (current_depth * 0.5)
		var fill_color = Color(0.3, 0.9, 1.0).lerp(Color(1.0, 0.45, 0.1), combined_power)
		if charge_level >= 0.95 and current_depth >= 0.7:
			fill_color = Color(1.0, 0.95, 0.3) # Golden MAX
		_charge_bar_fill.color = fill_color
	else:
		_charge_bar_bg.visible = false

func _process_bot_ai(delta: float) -> void:
	bot_action_timer -= delta

	if is_airborne:
		velocity.y += AIR_GRAVITY * delta
		# Bot horizontal air steering towards nearest pellet
		if bot_target_pellet and is_instance_valid(bot_target_pellet):
			var steer_dir = signf(bot_target_pellet.global_position.x - position.x)
			velocity.x = lerpf(velocity.x, steer_dir * AIR_STEER_SPEED, 0.16)
		else:
			velocity.x = lerpf(velocity.x, 0.0, 0.08)

		# Bot dive stance decision when falling
		if velocity.y > 60.0:
			is_diving_stance = bot_dive_intent
			if _dive_indicator:
				_dive_indicator.visible = true
				if is_diving_stance:
					_dive_indicator.text = "⬇ NOSE-DOWN DIVE! ⬇"
					_dive_indicator.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
				else:
					_dive_indicator.text = "⚠️ BELLY FLOP INCOMING!"
					_dive_indicator.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		else:
			is_diving_stance = false
			if _dive_indicator:
				_dive_indicator.visible = false
	else:
		# Bot underwater behavior: dive deep to charge launch
		var current_depth = clampf((position.y - water_surface_y) / (tank_floor_y - water_surface_y), 0.0, 1.0)

		if bot_action_timer <= 0.0:
			bot_action_timer = randf_range(0.25, 0.55)
			# Pick dive intent for next airborne cycle (78% clean dive, 22% belly flop)
			bot_dive_intent = (randf() < 0.78)

		if bot_target_pellet and is_instance_valid(bot_target_pellet):
			var target_x = bot_target_pellet.global_position.x
			var dx = target_x - position.x

			# If pellet is high in the air, dive down to build depth charge!
			var pellet_is_high = bot_target_pellet.global_position.y < (water_surface_y - 120.0)

			if pellet_is_high and current_depth < 0.75 and abs(dx) > 30.0:
				# Dive deep and charge
				velocity.x = lerpf(velocity.x, signf(dx) * SWIM_SPEED_X * 0.75, 0.2)
				velocity.y = lerpf(velocity.y, 220.0, 0.2) # swim downward
				is_charging = true
				charge_level = minf(charge_level + delta * 1.4, 1.0)
				deepest_depth_charge = maxf(deepest_depth_charge, current_depth)
			else:
				# Aligned and deep enough -> rocket upwards!
				is_charging = false
				velocity.x = lerpf(velocity.x, dx * 3.2, 0.22)
				velocity.y = -SWIM_SPEED_Y * 1.55
				is_propelling = true
				propel_power = maxf(charge_level, 0.6)

				if position.y <= water_surface_y + 35.0:
					position.y = water_surface_y - 2.0
					is_airborne = true
					_on_surface_breached()
		else:
			# Idle wandering underwater
			velocity.x = lerpf(velocity.x, sin(Time.get_ticks_msec() / 600.0) * 160.0, 0.1)
			velocity.y = lerpf(velocity.y, sin(Time.get_ticks_msec() / 800.0) * 80.0, 0.1)

		_update_charge_ui(current_depth)

func _animate_visuals(delta: float) -> void:
	if not _sprite:
		return

	# Face direction of horizontal motion
	if abs(velocity.x) > 15.0:
		_sprite.scale.x = 3.0 if velocity.x > 0.0 else -3.0

	# Pitch tilt in air
	if is_airborne:
		var target_angle: float = 0.0
		if is_diving_stance:
			# Nose pointed straight down into the water!
			target_angle = 1.35 if _sprite.scale.x > 0 else -1.35
		elif velocity.y > 60.0:
			# Falling flat / belly-first
			target_angle = 0.15 if _sprite.scale.x > 0 else -0.15
		else:
			# Arcing upward
			var trajectory_angle = velocity.angle() if _sprite.scale.x > 0 else velocity.angle() + PI
			target_angle = clampf(trajectory_angle, -0.6, 0.6)

		_sprite.rotation = lerp_angle(_sprite.rotation, target_angle, delta * 12.0)
		_sprite.frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()] + 2
	elif stun_timer <= 0.0:
		# Underwater visual animation
		var base_frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
		if is_charging:
			# Charging squash and vibration
			var squish = 1.0 + sin(Time.get_ticks_msec() / 40.0) * (0.08 * charge_level)
			_sprite.scale.y = 3.0 * (1.0 / squish)
			_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, delta * 12.0)
			_sprite.frame = base_frame + 1
		else:
			_sprite.scale.y = 3.0
			_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, delta * 12.0)
			if velocity.length_squared() > 400.0:
				_sprite.frame = base_frame + (int(Time.get_ticks_msec() / 130.0) % 4)
			else:
				_sprite.frame = base_frame

func _show_floating_text(text: String, color: Color) -> void:
	var popup = Label.new()
	popup.text = text
	popup.position = global_position + Vector2(-60, -65)
	popup.custom_minimum_size = Vector2(120, 24)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_color_override("font_color", color)
	get_parent().add_child(popup)

	var tw = popup.create_tween()
	tw.set_parallel(true)
	tw.tween_property(popup, "position:y", popup.position.y - 35.0, 0.7)
	tw.tween_property(popup, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(popup.queue_free)
