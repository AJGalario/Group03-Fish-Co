class_name ExitZone
extends Area2D

signal all_escaped

@export var required_players: int = -1  # -1 = auto from GameManager

var _occupants: Array[Node2D] = []
var _is_triggered: bool = false

@onready var _label: Label = $CountLabel
@onready var _glow_ring: ColorRect = $GlowRing

func _ready() -> void:
	if required_players <= 0:
		required_players = maxi(1, GameManager.players.size())

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()

	# Gentle pulse
	if _glow_ring:
		var tw := create_tween().set_loops()
		tw.tween_property(_glow_ring, "scale", Vector2(1.15, 1.15), 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_glow_ring, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("fish") or body is CharacterBody2D:
		if not _occupants.has(body):
			_occupants.append(body)
		_check_exit()

func _on_body_exited(body: Node2D) -> void:
	if _occupants.has(body):
		_occupants.erase(body)
	_check_exit()

func _check_exit() -> void:
	if _is_triggered:
		return

	var valid: Array[Node2D] = []
	for b in _occupants:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			valid.append(b)
	_occupants = valid
	_update_label()

	if _occupants.size() >= required_players:
		_is_triggered = true
		if _label:
			_label.text = "✔ ALL FISH READY!"
			_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		all_escaped.emit()

func _update_label() -> void:
	if _label and not _is_triggered:
		_label.text = "GATHER TO EXIT (%d / %d)" % [_occupants.size(), required_players]
