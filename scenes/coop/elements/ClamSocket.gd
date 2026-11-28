class_name ClamSocket
extends Area2D

signal socket_activated(socket_id: String)

@export var socket_id: String = "socket_1"
@export var socket_color: Color = Color(0.2, 0.7, 0.8)

var is_activated: bool = false

@onready var _indicator: ColorRect = $IndicatorRect

func _ready() -> void:
	collision_layer = 3
	collision_mask = 3
	body_entered.connect(_on_body_entered)
	# Apply socket color to ring visual
	var ring := get_node_or_null("RingRect")
	if ring is ColorRect:
		ring.color = Color(socket_color.r, socket_color.g, socket_color.b, 0.35)

func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return
	if body is PushPearl:
		is_activated = true
		body.lock_into_socket(global_position, socket_id)
		if _indicator:
			_indicator.color = Color(0.3, 1.0, 0.5, 0.9)
		socket_activated.emit(socket_id)
