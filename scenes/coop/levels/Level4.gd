extends CoopBase

## Level 4: Synchronized Swarm
## SyncPlate1 AND SyncPlate2 must be held simultaneously to open MidGate.
## Then team-push Pearl → ClamSocket → ClamSocket UNLOCKS BOTH DOORS!
## Now all fish can escape through MidGate and FinalGate.

@onready var sync_plate_1: PressurePlate = $SyncPlate1
@onready var sync_plate_2: PressurePlate = $SyncPlate2
@onready var mid_gate: CoralGate = $MidGate
@onready var push_pearl: PushPearl = $PushPearl
@onready var clam_socket: ClamSocket = $ClamSocket
@onready var final_gate: CoralGate = $FinalGate

var _socket_unlocked: bool = false

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
	if clam_socket:
		clam_socket.socket_activated.connect(_on_socket_activated)

	# Ensure gates start closed
	if mid_gate:
		mid_gate.close_gate()
	if final_gate:
		final_gate.close_gate()

func _on_socket_activated(_id: String) -> void:
	# Clam socket unlocks BOTH doors permanently!
	_socket_unlocked = true
	if mid_gate:
		mid_gate.open_gate()
	if final_gate:
		final_gate.open_gate()

func _check_sync() -> void:
	if _socket_unlocked:
		return
	if not mid_gate:
		return
	if sync_plate_1 and sync_plate_2 and sync_plate_1.is_pressed and sync_plate_2.is_pressed:
		mid_gate.open_gate()
	else:
		mid_gate.close_gate()
