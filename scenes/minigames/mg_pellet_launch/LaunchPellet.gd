class_name LaunchPellet
extends Area2D

signal collected(pellet: LaunchPellet, by_player: Node2D)

@export var point_value: int = 1
@export var is_golden: bool = false
@export var tank_index: int = 0

var base_y: float = 0.0
var bob_offset: float = 0.0
var bob_speed: float = 3.0
var bob_amplitude: float = 12.0
var drift_speed: float = 20.0
var tank_min_x: float = 100.0
var tank_max_x: float = 1820.0

var _is_collected: bool = false
var _visual: ColorRect
var _glow: ColorRect

func _ready() -> void:
	bob_offset = randf() * TAU
	drift_speed = randf_range(-25.0, 25.0)
	if abs(drift_speed) < 8.0:
		drift_speed = 15.0

	_build_visuals()
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0 if not is_golden else 26.0
	col.shape = shape
	add_child(col)

	var outer_size: float = 24.0 if not is_golden else 34.0
	_visual = ColorRect.new()
	_visual.size = Vector2(outer_size, outer_size)
	_visual.position = Vector2(-outer_size * 0.5, -outer_size * 0.5)
	_visual.color = Color(1.0, 0.82, 0.2) if not is_golden else Color(1.0, 0.45, 0.15)
	add_child(_visual)

	var inner_size: float = 10.0 if not is_golden else 16.0
	_glow = ColorRect.new()
	_glow.size = Vector2(inner_size, inner_size)
	_glow.position = Vector2(-inner_size * 0.5, -inner_size * 0.5)
	_glow.color = Color(1.0, 1.0, 0.85) if not is_golden else Color(1.0, 0.95, 0.5)
	add_child(_glow)

func _process(delta: float) -> void:
	if _is_collected:
		return

	# Gentle bobbing sine wave
	var t = Time.get_ticks_msec() / 1000.0
	position.y = base_y + sin(t * bob_speed + bob_offset) * bob_amplitude

	# Gentle horizontal drift
	position.x += drift_speed * delta
	if position.x < tank_min_x:
		position.x = tank_min_x
		drift_speed = abs(drift_speed)
	elif position.x > tank_max_x:
		position.x = tank_max_x
		drift_speed = -abs(drift_speed)

	# Golden sparkle pulsing
	if is_golden and _visual:
		var pulse = 1.0 + sin(t * 8.0) * 0.15
		scale = Vector2(pulse, pulse)

func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if not (body is CharacterBody2D or body.is_in_group("fish")):
		return

	_is_collected = true
	collected.emit(self, body)
	_play_collect_animation()

func _play_collect_animation() -> void:
	# Spawn floating score popup
	var popup = Label.new()
	popup.text = "+%d" % point_value
	popup.position = global_position + Vector2(-15, -25)
	popup.add_theme_font_size_override("font_size", 26 if not is_golden else 34)
	popup.add_theme_color_override("font_color", Color(1, 0.95, 0.3) if not is_golden else Color(1, 0.5, 0.2))
	get_parent().add_child(popup)

	var p_tw = popup.create_tween()
	p_tw.tween_property(popup, "position:y", popup.position.y - 45.0, 0.6)
	p_tw.parallel().tween_property(popup, "modulate:a", 0.0, 0.6)
	p_tw.tween_callback(popup.queue_free)

	# Shrink & burst pellet
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
