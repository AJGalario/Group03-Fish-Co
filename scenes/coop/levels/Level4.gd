extends CoopBase

## Level 4: Synchronized Swarm
## Master challenge combining synchronization, physics, and team coordination!
## 1. Simultaneous buttons: Both plates must be pressed at the exact same time.
## 2. Push the ancient heavy pearl into the clam geyser.
## 3. All fishes escape together through the grand exit!

@onready var sync_plate_1: PressurePlate = $SyncPlate1
@onready var sync_plate_2: PressurePlate = $SyncPlate2
@onready var mid_gate: CoralGate = $MidGate
@onready var push_pearl: PushPearl = $PushPearl
@onready var clam_socket: ClamSocket = $ClamSocket
@onready var final_gate: CoralGate = $FinalGate

func _ready() -> void:
	level_number = 4
	level_title = "Synchronized Swarm"
	level_instruction = "Synchronize buttons simultaneously and push the pearl to unlock the grand exit!"
	super._ready()

	if push_pearl:
		push_pearl.min_pushers = mini(2, GameManager.players.size())

	if sync_plate_1:
		sync_plate_1.activated.connect(_check_sync_plates)
		sync_plate_1.deactivated.connect(_check_sync_plates)
	if sync_plate_2:
		sync_plate_2.activated.connect(_check_sync_plates)
		sync_plate_2.deactivated.connect(_check_sync_plates)

	if clam_socket and final_gate:
		clam_socket.socket_activated.connect(func(_id): final_gate.open_gate())

func _check_sync_plates() -> void:
	if not mid_gate:
		return
	if sync_plate_1.is_pressed and sync_plate_2.is_pressed:
		mid_gate.open_gate()
	else:
		mid_gate.close_gate()
