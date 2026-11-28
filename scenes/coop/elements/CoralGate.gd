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
var _tween: Tween

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
@onready var _rect: ColorRect = $GateRect
@onready var _trim_rect: ColorRect = $TrimRect

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_closed_pos = position
	is_open = false

	# Apply exported colors/sizes cleanly without corrupting other gates
	if _rect:
		_rect.color = gate_color
		_rect.offset_left = -gate_size.x * 0.5
		_rect.offset_right = gate_size.x * 0.5
		_rect.offset_top = -gate_size.y * 0.5
		_rect.offset_bottom = gate_size.y * 0.5
	if _trim_rect:
		_trim_rect.offset_left = -2.0
		_trim_rect.offset_right = 2.0
		_trim_rect.offset_top = -gate_size.y * 0.5
		_trim_rect.offset_bottom = gate_size.y * 0.5
	if _col_shape and _col_shape.shape is RectangleShape2D:
		var r_shape := _col_shape.shape as RectangleShape2D
		if r_shape.size != gate_size:
			var unique_shape := r_shape.duplicate() as RectangleShape2D
			unique_shape.size = gate_size
			_col_shape.shape = unique_shape

func open_gate() -> void:
	if is_open:
		return
	is_open = true
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", _closed_pos + open_offset, slide_duration)
	if _rect:
		_tween.parallel().tween_property(_rect, "modulate:a", 0.45, slide_duration)
	state_changed.emit(true)

func close_gate() -> void:
	if not is_open:
		return
	is_open = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", _closed_pos, slide_duration)
	if _rect:
		_tween.parallel().tween_property(_rect, "modulate:a", 1.0, slide_duration)
	state_changed.emit(false)

func toggle_gate() -> void:
	if is_open:
		close_gate()
	else:
		open_gate()
