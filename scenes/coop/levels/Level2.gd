extends CoopBase

## Level 2: The Heavy Pearl
## Inspired by cooperative push puzzles in Pico Park and Baby Kings!
## A massive oyster pearl is too heavy for a lone fish to roll.
## Fish must team up to push the pearl into the glowing clam socket!

@onready var plate_ramp: PressurePlate = $PlateRamp
@onready var gate_ramp: CoralGate = $GateRamp
@onready var push_pearl: PushPearl = $PushPearl
@onready var clam_socket: ClamSocket = $ClamSocket
@onready var gate_exit: CoralGate = $GateExit

func _ready() -> void:
	level_number = 2
	level_title = "The Heavy Pearl"
	level_instruction = "Team up to push the massive glowing pearl into the clam basin!"
	super._ready()

	# The pearl requires team coordination
	if push_pearl:
		push_pearl.min_pushers = mini(2, GameManager.players.size())

	if plate_ramp and gate_ramp:
		plate_ramp.activated.connect(gate_ramp.open_gate)
		plate_ramp.deactivated.connect(gate_ramp.close_gate)

	if clam_socket and gate_exit:
		clam_socket.socket_activated.connect(func(_id): gate_exit.open_gate())
