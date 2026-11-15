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
var _col_shape: CollisionShape2D
var _rect: ColorRect
var _trim_rect: ColorRect

func _ready() -> void:
	_closed_pos = position
	_build_visuals()

func _build_visuals() -> void:
	_col_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = gate_size
	_col_shape.shape = shape
	add_child(_col_shape)

	_rect = ColorRect.new()
	_rect.size = gate_size
	_rect.position = -gate_size * 0.5
	_rect.color = gate_color
	add_child(_rect)

	# Decorative coral pattern / edge trim
	_trim_rect = ColorRect.new()
	_trim_rect.size = Vector2(4, gate_size.y)
	_trim_rect.position = Vector2(-2, -gate_size.y * 0.5)
	_trim_rect.color = Color(0.8, 1.0, 0.95, 0.6)
	add_child(_trim_rect)

func open_gate() -> void:
	if is_open:
		return
	is_open = true
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", _closed_pos + open_offset, slide_duration)
	tw.parallel().tween_property(_rect, "modulate:a", 0.45, slide_duration)
	state_changed.emit(true)

func close_gate() -> void:
	if not is_open:
		return
	is_open = false
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", _closed_pos, slide_duration)
	tw.parallel().tween_property(_rect, "modulate:a", 1.0, slide_duration)
	state_changed.emit(false)

func toggle_gate() -> void:
	if is_open:
		close_gate()
	else:
		open_gate()
