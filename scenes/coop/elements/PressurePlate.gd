class_name PressurePlate
extends Area2D

signal activated
signal deactivated

@export var plate_id: String = "plate_1"
@export var required_count: int = 1
@export var is_toggle: bool = false
@export var plate_color: Color = Color(0.2, 0.85, 0.95)
@export var require_all_active_players: bool = false

var is_pressed: bool = false
var _occupants: Array[Node2D] = []

@onready var _pedal_rect: ColorRect = $Pedal
@onready var _glow_line: ColorRect = $GlowLine
@onready var _indicator_label: Label = $CountLabel

func _ready() -> void:
	if require_all_active_players:
		required_count = maxi(1, GameManager.players.size())

	# Apply exported plate_color to the visuals
	if _pedal_rect:
		_pedal_rect.color = plate_color.lerp(Color.WHITE, 0.15)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual_state()

func _on_body_entered(body: Node2D) -> void:
	if not _occupants.has(body):
		_occupants.append(body)
	_check_state()

func _on_body_exited(body: Node2D) -> void:
	if _occupants.has(body):
		_occupants.erase(body)
	_check_state()

func _check_state() -> void:
	var valid_occupants: Array[Node2D] = []
	for b in _occupants:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			valid_occupants.append(b)
	_occupants = valid_occupants

	var current_count := _occupants.size()
	var should_be_active := current_count >= required_count

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
	if not _pedal_rect:
		return
	var tw := create_tween()
	var target_y := -3.0 if down else -10.0
	tw.tween_property(_pedal_rect, "position:y", target_y, 0.15)
	if _glow_line:
		tw.parallel().tween_property(_glow_line, "position:y", target_y, 0.15)

func _update_visual_state() -> void:
	var current_count := _occupants.size()
	if _indicator_label:
		if required_count > 1:
			_indicator_label.text = "[ %d / %d ]" % [mini(current_count, required_count), required_count]
			_indicator_label.visible = true
		else:
			_indicator_label.visible = false

	if _pedal_rect:
		_pedal_rect.color = Color(0.3, 1.0, 0.5) if is_pressed else plate_color.lerp(Color.WHITE, 0.15)
	if _glow_line:
		_glow_line.color = Color(1.0, 1.0, 1.0) if is_pressed else Color(0.7, 0.9, 1.0, 0.7)
