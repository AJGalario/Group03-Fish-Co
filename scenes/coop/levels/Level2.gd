extends CoopBase

## Level 2: The Heavy Pearl
## PlateRamp → GateRamp opens; then team-push Pearl → ClamSocket → GateExit opens.

@onready var plate_ramp: PressurePlate = $PlateRamp
@onready var gate_ramp: CoralGate = $GateRamp
@onready var push_pearl: PushPearl = $PushPearl
@onready var clam_socket: ClamSocket = $ClamSocket
@onready var gate_exit: CoralGate = $GateExit

func _ready() -> void:
	super._ready()
	if push_pearl:
		push_pearl.min_pushers = mini(2, GameManager.players.size())
	if plate_ramp and gate_ramp:
		plate_ramp.activated.connect(gate_ramp.open_gate)
		plate_ramp.deactivated.connect(gate_ramp.close_gate)
	if clam_socket and gate_exit:
		clam_socket.socket_activated.connect(func(_id): gate_exit.open_gate())
