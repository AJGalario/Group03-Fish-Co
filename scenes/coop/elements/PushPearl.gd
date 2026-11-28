class_name PushPearl
extends CharacterBody2D

signal entered_socket(socket_id: String)

@export var pearl_radius: float = 34.0
@export var min_pushers: int = 1
@export var base_mass: float = 120.0

const WATER_GRAVITY: float = 380.0
const MAX_SINK_SPEED: float = 300.0
const WATER_DRAG_X: float = 4.5

var is_locked: bool = false
var _pushers: Array[Node2D] = []

@onready var _sprite_rect: ColorRect = $PearlRect
@onready var _glow_rect: ColorRect = $GlowRect
@onready var _push_area: Area2D = $PushArea

var _pusher_label: Label

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	if _push_area:
		_push_area.collision_layer = 0
		_push_area.collision_mask = 2
		_push_area.body_entered.connect(_on_pusher_entered)
		_push_area.body_exited.connect(_on_pusher_exited)

	# Hide raw square rects at runtime so they never desync or split apart
	if _sprite_rect:
		_sprite_rect.visible = false
	if _glow_rect:
		_glow_rect.visible = false

	_build_pusher_label()
	queue_redraw()

func _draw() -> void:
	if is_locked:
		# Golden slotted pearl
		draw_circle(Vector2.ZERO, pearl_radius + 6.0, Color(1.0, 0.85, 0.25, 0.45))
		draw_circle(Vector2.ZERO, pearl_radius, Color(1.0, 0.92, 0.55, 0.98))
		draw_circle(Vector2(-pearl_radius * 0.28, -pearl_radius * 0.28), pearl_radius * 0.32, Color(1.0, 1.0, 0.9, 0.8))
	else:
		# Glowing luminous pearl
		draw_circle(Vector2.ZERO, pearl_radius + 6.0, Color(0.65, 0.92, 1.0, 0.38))
		draw_circle(Vector2.ZERO, pearl_radius, Color(0.94, 0.97, 1.0, 0.96))
		draw_circle(Vector2(-pearl_radius * 0.28, -pearl_radius * 0.28), pearl_radius * 0.32, Color(1.0, 1.0, 1.0, 0.82))

func _build_pusher_label() -> void:
	_pusher_label = Label.new()
	_pusher_label.position = Vector2(-70, -pearl_radius - 32)
	_pusher_label.custom_minimum_size = Vector2(140, 22)
	_pusher_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pusher_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pusher_label.add_theme_font_size_override("font_size", 13)
	_pusher_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	add_child(_pusher_label)
	_update_pusher_ui(0)

func _update_pusher_ui(active_count: int) -> void:
	if not _pusher_label:
		return
	if is_locked:
		_pusher_label.text = "✓ SLOTTED"
		_pusher_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		return

	if min_pushers > 1:
		_pusher_label.visible = true
		_pusher_label.text = "[ %d / %d 👥 ]" % [mini(active_count, min_pushers), min_pushers]
		if active_count >= min_pushers:
			_pusher_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
		else:
			_pusher_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	else:
		_pusher_label.visible = false

func _physics_process(delta: float) -> void:
	if is_locked:
		return

	# Underwater gravity (sinks down unless resting on floor or ledge)
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, MAX_SINK_SPEED, WATER_GRAVITY * delta)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	# Calculate active pushers
	var total_push_x := 0.0
	var active_push_count := 0

	for pusher in _pushers:
		if is_instance_valid(pusher) and pusher is CharacterBody2D:
			var to_pearl := global_position - pusher.global_position
			var dir_x := signf(to_pearl.x)
			if absf(to_pearl.x) > 4.0:
				var p_vel_x: float = pusher.velocity.x
				if p_vel_x * dir_x > 10.0:
					total_push_x += dir_x * maxf(absf(p_vel_x), 180.0)
					active_push_count += 1

	_update_pusher_ui(active_push_count)

	if active_push_count >= min_pushers and absf(total_push_x) > 10.0:
		var target_vx := (total_push_x / float(active_push_count)) * 0.95
		velocity.x = move_toward(velocity.x, target_vx, 450.0 * delta)
	else:
		# Too heavy to push alone or nobody pushing — slow to a stop
		velocity.x = move_toward(velocity.x, 0.0, WATER_DRAG_X * 60.0 * delta)

	move_and_slide()

func lock_into_socket(socket_pos: Vector2, socket_id: String) -> void:
	if is_locked:
		return
	is_locked = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", socket_pos, 0.35)
	tw.tween_callback(queue_redraw)
	_update_pusher_ui(0)
	entered_socket.emit(socket_id)

func _on_pusher_entered(body: Node2D) -> void:
	if body != self and body.is_in_group("fish"):
		if not _pushers.has(body):
			_pushers.append(body)

func _on_pusher_exited(body: Node2D) -> void:
	if _pushers.has(body):
		_pushers.erase(body)
