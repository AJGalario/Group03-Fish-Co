class_name PushPearl
extends CharacterBody2D

signal entered_socket(socket_id: String)

@export var pearl_radius: float = 34.0
@export var min_pushers: int = 1
@export var base_mass: float = 120.0

var is_locked: bool = false
var _pushers: Array[Node2D] = []

@onready var _sprite_rect: ColorRect = $PearlRect
@onready var _glow_rect: ColorRect = $GlowRect
@onready var _push_area: Area2D = $PushArea

func _ready() -> void:
	if _push_area:
		_push_area.body_entered.connect(_on_pusher_entered)
		_push_area.body_exited.connect(_on_pusher_exited)

func _physics_process(delta: float) -> void:
	if is_locked:
		return

	var total_push := Vector2.ZERO
	var active_push_count := 0

	for pusher in _pushers:
		if is_instance_valid(pusher):
			var to_pearl := global_position - pusher.global_position
			var dist := to_pearl.length()
			if dist > 0.0:
				var push_dir := to_pearl.normalized()
				if pusher is CharacterBody2D and pusher.velocity.dot(push_dir) > 0.1:
					total_push += push_dir * pusher.velocity.length()
					active_push_count += 1

	if active_push_count >= min_pushers and total_push.length_squared() > 10.0:
		var speed_boost := 1.0 + (active_push_count - 1) * 0.75
		velocity = lerp(velocity, total_push.normalized() * (220.0 * speed_boost), 0.18)
	else:
		velocity = lerp(velocity, Vector2.ZERO, 0.1)

	move_and_slide()

	if _sprite_rect and velocity.length_squared() > 20.0:
		_sprite_rect.rotation += velocity.x * delta * 0.04

func lock_into_socket(socket_pos: Vector2, socket_id: String) -> void:
	if is_locked:
		return
	is_locked = true
	velocity = Vector2.ZERO
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", socket_pos, 0.35)
	if _glow_rect:
		tw.tween_property(_glow_rect, "color", Color(1.0, 0.85, 0.2, 0.8), 0.3)
	entered_socket.emit(socket_id)

func _on_pusher_entered(body: Node2D) -> void:
	if body != self and (body.is_in_group("fish") or body is CharacterBody2D):
		if not _pushers.has(body):
			_pushers.append(body)

func _on_pusher_exited(body: Node2D) -> void:
	if _pushers.has(body):
		_pushers.erase(body)
