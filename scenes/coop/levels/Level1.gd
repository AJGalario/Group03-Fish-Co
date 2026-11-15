extends CoopBase

## Level 1: First Splash — Cooperative Tutorial
## Plate1 → Gate1, Plate2 → Gate2 — learn the basics!

@onready var plate_1: PressurePlate = $Plate1
@onready var plate_2: PressurePlate = $Plate2
@onready var gate_1: CoralGate = $Gate1
@onready var gate_2: CoralGate = $Gate2

func _ready() -> void:
	super._ready()
	if plate_1 and gate_1:
		plate_1.activated.connect(gate_1.open_gate)
		plate_1.deactivated.connect(gate_1.close_gate)
	if plate_2 and gate_2:
		plate_2.activated.connect(gate_2.open_gate)
		plate_2.deactivated.connect(gate_2.close_gate)
