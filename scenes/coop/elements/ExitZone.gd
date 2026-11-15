class_name ExitZone
extends Area2D

signal all_escaped

@export var required_players: int = -1 # -1 = automatically matches GameManager.players.size()

var _occupants: Array[Node2D] = []
var _is_triggered: bool = false
var _label: Label
var _glow_ring: ColorRect

func _ready() -> void:
	if required_players <= 0:
		required_players = maxi(1, GameManager.players.size())

	_build_visuals()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()

func _build_visuals() -> void:
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 80.0
	col.shape = shape
	add_child(col)

	# Outer glowing ring
	_glow_ring = ColorRect.new()
	_glow_ring.size = Vector2(130, 130)
	_glow_ring.position = Vector2(-65, -65)
	_glow_ring.color = Color(1.0, 0.85, 0.25, 0.3)
	add_child(_glow_ring)

	# Conch shell / exit vortex core
	var core = ColorRect.new()
	core.size = Vector2(90, 90)
	core.position = Vector2(-45, -45)
	core.color = Color(1.0, 0.9, 0.4, 0.85)
	add_child(core)

	var icon_lbl = Label.new()
	icon_lbl.text = "ðŸ EXIT"
	icon_lbl.position = Vector2(-50, -18)
	icon_lbl.custom_minimum_size = Vector2(100, 36)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.add_theme_color_override("font_color", Color(0.1, 0.18, 0.3))
	add_child(icon_lbl)

	# Label above exit
	_label = Label.new()
	_label.position = Vector2(-120, -100)
	_label.custom_minimum_size = Vector2(240, 28)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	add_child(_label)

	# Gentle pulsing animation
	var tw = create_tween().set_loops()
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

	# Clean up deleted references
	var valid: Array[Node2D] = []
	for b in _occupants:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			valid.append(b)
	_occupants = valid

	_update_label()

	if _occupants.size() >= required_players:
		_is_triggered = true
		_label.text = "âœ“ ALL FISH READY!"
		_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		all_escaped.emit()

func _update_label() -> void:
	if _label and not _is_triggered:
		_label.text = "GATHER TO EXIT (%d / %d)" % [_occupants.size(), required_players]
