extends CoopBase

## Level 3: Twin Currents
## Inspired by DYO and split-cooperative mechanics!
## The tank is divided into two separate water chambers.
## Fishes in opposite chambers must coordinate switches across the barrier
## to unlock each other's path before reuniting at the exit!

@onready var plate_top: PressurePlate = $PlateTop
@onready var plate_bot: PressurePlate = $PlateBot
@onready var gate_top: CoralGate = $GateTop
@onready var gate_bot: CoralGate = $GateBot
@onready var team_plate: PressurePlate = $TeamPlate
@onready var final_gate: CoralGate = $FinalGate

func _ready() -> void:
	level_number = 3
	level_title = "Twin Currents"
	level_instruction = "Split into upper & lower tunnels! Coordinate switches across the divider!"
	super._ready()

	# Cross-chamber button linkage (Upper plate opens Lower gate; Lower plate opens Upper gate)
	if plate_top and gate_bot:
		plate_top.activated.connect(gate_bot.open_gate)
		plate_top.deactivated.connect(gate_bot.close_gate)

	if plate_bot and gate_top:
		plate_bot.activated.connect(gate_top.open_gate)
		plate_bot.deactivated.connect(gate_top.close_gate)

	# Multi-fish reunion plate
	if team_plate and final_gate:
		team_plate.required_count = maxi(2, GameManager.players.size())
		team_plate.activated.connect(final_gate.open_gate)
		team_plate.deactivated.connect(final_gate.close_gate)
