extends CoopBase

## Level 3: Twin Currents
## Cross-chamber: PlateTop opens GateBot, PlateBot opens GateTop.
## TeamPlate (requires all players) triggers 3-second coordinated countdown to rush through FinalGate.

@export var countdown_duration: float = 3.0
@export var prompt_message: String = "SWIM TOGETHER!"

@onready var plate_top: PressurePlate = $PlateTop
@onready var plate_bot: PressurePlate = $PlateBot
@onready var gate_top: CoralGate = $GateTop
@onready var gate_bot: CoralGate = $GateBot
@onready var team_plate: PressurePlate = $TeamPlate
@onready var final_gate: CoralGate = $FinalGate
@onready var coordinate_label: Label = get_node_or_null("CoordinateLabel")

var _countdown_tween: Tween

func _ready() -> void:
	super._ready()

	# Start coordinate label hidden until triggered (visible in editor for designer placement)
	if coordinate_label:
		coordinate_label.modulate.a = 0.0
		coordinate_label.visible = false

	if plate_top and gate_bot:
		plate_top.activated.connect(gate_bot.open_gate)
		plate_top.deactivated.connect(gate_bot.close_gate)

	if plate_bot and gate_top:
		plate_bot.activated.connect(gate_top.open_gate)
		plate_bot.deactivated.connect(gate_top.close_gate)

	if team_plate and final_gate:
		team_plate.required_count = maxi(2, GameManager.players.size())
		team_plate.activated.connect(_on_team_plate_activated)

func _on_team_plate_activated() -> void:
	if not final_gate:
		return
	final_gate.open_gate()

	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()

	if coordinate_label:
		coordinate_label.visible = true
		coordinate_label.modulate.a = 0.0
		coordinate_label.text = "%s\n3" % prompt_message

	_countdown_tween = create_tween()
	# Fade in smoothly over 0.2s
	if coordinate_label:
		_countdown_tween.tween_property(coordinate_label, "modulate:a", 1.0, 0.2)

	# 3-second countdown: 3 -> 2 -> 1 -> Close
	_countdown_tween.tween_callback(func(): _update_label_text(3))
	_countdown_tween.tween_interval(1.0)
	_countdown_tween.tween_callback(func(): _update_label_text(2))
	_countdown_tween.tween_interval(1.0)
	_countdown_tween.tween_callback(func(): _update_label_text(1))
	_countdown_tween.tween_interval(1.0)
	_countdown_tween.tween_callback(func():
		_update_label_text(0)
		if final_gate and not (team_plate and team_plate.is_pressed):
			final_gate.close_gate()
	)
	# Fade out smoothly
	if coordinate_label:
		_countdown_tween.tween_property(coordinate_label, "modulate:a", 0.0, 0.4)
		_countdown_tween.tween_callback(func(): coordinate_label.visible = false)

func _update_label_text(seconds_left: int) -> void:
	if not coordinate_label:
		return
	if seconds_left > 0:
		coordinate_label.text = "%s\n%d" % [prompt_message, seconds_left]
	else:
		coordinate_label.text = "GATE CLOSING!"
