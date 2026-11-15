class_name PressurePlate
extends Area2D

signal activated
signal deactivated

@export var plate_id: String = "plate_1"
@export var required_count: int = 1 # 1 = single fish, or higher for team plates
@export var is_toggle: bool = false
@export var plate_color: Color = Color(0.2, 0.85, 0.95)
@export var require_all_active_players: bool = false

var is_pressed: bool = false
var _occupants: Array[Node2D] = []

var _base_rect: ColorRect
var _pedal_rect: ColorRect
var _indicator_label: Label
var _glow_line: ColorRect

func _ready() -> void:
	if require_all_active_players:
		required_count = maxi(1, GameManager.players.size())

	_build_visuals()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual_state()

func _build_visuals() -> void:
	# Physics collision shape
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 24)
	col.shape = shape
	add_child(col)

	# Floor mounting base
	_base_rect = ColorRect.new()
	_base_rect.size = Vector2(110, 14)
	_base_rect.position = Vector2(-55, 6)
	_base_rect.color = Color(0.08, 0.18, 0.26, 0.95)
	add_child(_base_rect)

	# Stepping pedal
	_pedal_rect = ColorRect.new()
	_pedal_rect.size = Vector2(96, 18)
	_pedal_rect.position = Vector2(-48, -10)
	_pedal_rect.color = plate_color.lerp(Color.WHITE, 0.15)
	add_child(_pedal_rect)

	# Glowing edge indicator
	_glow_line = ColorRect.new()
	_glow_line.size = Vector2(96, 4)
	_glow_line.position = Vector2(-48, -10)
	_glow_line.color = Color(1, 1, 1, 0.9)
	add_child(_glow_line)

	# Above-pedal occupancy counter
	_indicator_label = Label.new()
	_indicator_label.position = Vector2(-60, -42)
	_indicator_label.custom_minimum_size = Vector2(120, 24)
	_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicator_label.add_theme_font_size_override("font_size", 14)
	_indicator_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_indicator_label)

func _on_body_entered(body: Node2D) -> void:
	if not _occupants.has(body):
		_occupants.append(body)
	_check_state()

func _on_body_exited(body: Node2D) -> void:
	if _occupants.has(body):
		_occupants.erase(body)
	_check_state()

func _check_state() -> void:
	# Filter out deleted bodies
	var valid_occupants: Array[Node2D] = []
	for b in _occupants:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			valid_occupants.append(b)
	_occupants = valid_occupants

	var current_count = _occupants.size()
	var should_be_active = current_count >= required_count

	if should_be_active and not is_pressed:
		is_pressed = true
		_animate_press(true)
		activated.emit()
	elif not should_be_active and is_pressed and not is_toggle:
		is_pressed = false
		_animate_press(false)
		deactivated.emit()

	_update_visual_state()

func _animate_press(down: bool) -> void:
	var tw = create_tween()
	var target_y = -3.0 if down else -10.0
	tw.tween_property(_pedal_rect, "position:y", target_y, 0.15)
	tw.parallel().tween_property(_glow_line, "position:y", target_y, 0.15)

func _update_visual_state() -> void:
	var current_count = _occupants.size()
	if _indicator_label:
		if required_count > 1:
			_indicator_label.text = "[ %d / %d ]" % [mini(current_count, required_count), required_count]
			_indicator_label.visible = true
		else:
			_indicator_label.visible = false

	if is_pressed:
		_pedal_rect.color = Color(0.3, 1.0, 0.5)
		_glow_line.color = Color(1.0, 1.0, 1.0)
	else:
		_pedal_rect.color = plate_color.lerp(Color.WHITE, 0.15)
		_glow_line.color = Color(0.7, 0.9, 1.0, 0.7)
