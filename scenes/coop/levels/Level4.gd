extends CoopBase

## Level 4: Synchronized Swarm
## SyncPlate1 AND SyncPlate2 must be held simultaneously to open MidGate.
## Then team-push Pearl → ClamSocket → FinalGate opens → all escape.

@onready var sync_plate_1: PressurePlate = $SyncPlate1
@onready var sync_plate_2: PressurePlate = $SyncPlate2
@onready var mid_gate: CoralGate = $MidGate
@onready var push_pearl: PushPearl = $PushPearl
@onready var clam_socket: ClamSocket = $ClamSocket
@onready var final_gate: CoralGate = $FinalGate

func _ready() -> void:
	super._ready()
	if push_pearl:
		push_pearl.min_pushers = mini(2, GameManager.players.size())
	if sync_plate_1:
		sync_plate_1.activated.connect(_check_sync)
		sync_plate_1.deactivated.connect(_check_sync)
	if sync_plate_2:
		sync_plate_2.activated.connect(_check_sync)
		sync_plate_2.deactivated.connect(_check_sync)
	if clam_socket and final_gate:
		clam_socket.socket_activated.connect(func(_id): final_gate.open_gate())

func _check_sync() -> void:
	if not mid_gate or mid_gate.is_open:
		return
	if sync_plate_1 and sync_plate_2 and sync_plate_1.is_pressed and sync_plate_2.is_pressed:
		mid_gate.open_gate()
