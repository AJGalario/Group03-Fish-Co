class_name ClamSocket
extends Area2D

signal socket_activated(socket_id: String)

@export var socket_id: String = "socket_1"
@export var socket_color: Color = Color(0.2, 0.7, 0.8)

var is_activated: bool = false
var _indicator: ColorRect

func _ready() -> void:
	_build_visuals()
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 38.0
	col.shape = shape
	add_child(col)

	var ring = ColorRect.new()
	ring.size = Vector2(76, 76)
	ring.position = Vector2(-38, -38)
	ring.color = Color(socket_color.r, socket_color.g, socket_color.b, 0.35)
	add_child(ring)

	_indicator = ColorRect.new()
	_indicator.size = Vector2(50, 50)
	_indicator.position = Vector2(-25, -25)
	_indicator.color = Color(0.1, 0.2, 0.3, 0.8)
	add_child(_indicator)

	var lbl = Label.new()
	lbl.text = "SOCKET"
	lbl.position = Vector2(-35, -12)
	lbl.custom_minimum_size = Vector2(70, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	add_child(lbl)

func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return
	if body is PushPearl:
		is_activated = true
		body.lock_into_socket(global_position, socket_id)
		_indicator.color = Color(0.3, 1.0, 0.5, 0.9)
		socket_activated.emit(socket_id)
