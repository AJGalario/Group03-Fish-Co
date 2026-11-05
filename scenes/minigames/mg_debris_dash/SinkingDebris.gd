class_name SinkingDebris
extends Area2D

@export var rot_speed: float = 1.5

# Drift movement: set drift_direction to a non-zero value to make this
# piece bob/drift vertically while the world scrolls it horizontally.
@export var drift_direction: float = 0.0
@export var drift_speed: float = 0.0
@export var drift_range: float = 0.0

var _drift_origin_y: float = 0.0
var _drift_phase: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_drift_origin_y = position.y
	_drift_phase = randf() * TAU

func _physics_process(delta: float) -> void:
	rotation += rot_speed * delta
	if drift_direction != 0.0 and drift_speed > 0.0:
		_drift_phase += drift_speed * delta / maxf(1.0, drift_range) * TAU
		position.y = _drift_origin_y + drift_direction * drift_range * sin(_drift_phase)

func _on_body_entered(body: Node2D) -> void:
	if body is FishPlayer:
		body.die("Crushed by sinking submarine debris!")
