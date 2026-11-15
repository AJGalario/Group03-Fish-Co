class_name CoralGate
extends StaticBody2D

signal state_changed(is_open: bool)

@export var gate_id: String = "gate_1"
@export var open_offset: Vector2 = Vector2(0, -180)
@export var slide_duration: float = 0.55
@export var gate_color: Color = Color(0.18, 0.55, 0.52)
@export var gate_size: Vector2 = Vector2(28, 200)

var is_open: bool = false
var _closed_pos: Vector2

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
@onready var _rect: ColorRect = $GateRect
@onready var _trim_rect: ColorRect = $TrimRect

func _ready() -> void:
	_closed_pos = position
	# Apply exported colors/sizes to editor nodes
	if _rect:
		_rect.color = gate_color
		_rect.size = gate_size
		_rect.position = -gate_size * 0.5
	if _trim_rect:
		_trim_rect.size = Vector2(4, gate_size.y)
		_trim_rect.position = Vector2(-2, -gate_size.y * 0.5)
	if _col_shape and _col_shape.shape is RectangleShape2D:
		(_col_shape.shape as RectangleShape2D).size = gate_size

func open_gate() -> void:
	if is_open:
		return
	is_open = true
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", _closed_pos + open_offset, slide_duration)
	if _rect:
		tw.parallel().tween_property(_rect, "modulate:a", 0.45, slide_duration)
	state_changed.emit(true)

func close_gate() -> void:
	if not is_open:
		return
	is_open = false
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", _closed_pos, slide_duration)
	if _rect:
		tw.parallel().tween_property(_rect, "modulate:a", 1.0, slide_duration)
	state_changed.emit(false)

func toggle_gate() -> void:
	if is_open:
		close_gate()
	else:
		open_gate()
