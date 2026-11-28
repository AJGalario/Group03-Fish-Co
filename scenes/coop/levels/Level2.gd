extends CoopBase

## Level 2: The Heavy Pearl
## Dynamically scales challenge based on active player count:
##   - 2 Players: 1 pearl to push with min_pushers = 2 -> 1 socket to activate GateExit
##   - 3 Players: 1 pearl to push with min_pushers = 2
##   - 4 Players: 2 pearls to push (min_pushers = 2 each) -> 2 sockets to activate GateExit!

@onready var plate_ramp: PressurePlate = $PlateRamp
@onready var gate_ramp: CoralGate = $GateRamp
@onready var push_pearl: PushPearl = $PushPearl
@onready var push_pearl_2: PushPearl = get_node_or_null("PushPearl2")
@onready var clam_socket: ClamSocket = $ClamSocket
@onready var clam_socket_2: ClamSocket = get_node_or_null("ClamSocket2")
@onready var gate_exit: CoralGate = $GateExit

var _sockets_filled: Dictionary = {}

func _ready() -> void:
	super._ready()
	var p_count := maxi(2, GameManager.players.size())
	var need_second_pearl := (p_count >= 4)

	# Configure Pearl 1
	if push_pearl:
		push_pearl.min_pushers = 2

	# Configure Pearl 2 & Socket 2
	if push_pearl_2:
		push_pearl_2.min_pushers = 2
		push_pearl_2.visible = need_second_pearl
		push_pearl_2.process_mode = Node.PROCESS_MODE_INHERIT if need_second_pearl else Node.PROCESS_MODE_DISABLED

	if clam_socket_2:
		clam_socket_2.visible = need_second_pearl
		clam_socket_2.monitoring = need_second_pearl
		clam_socket_2.monitorable = need_second_pearl
		clam_socket_2.process_mode = Node.PROCESS_MODE_INHERIT if need_second_pearl else Node.PROCESS_MODE_DISABLED

	# Plate opens Ramp Gate and latches open once activated
	if plate_ramp and gate_ramp:
		if p_count >= 4:
			plate_ramp.required_count = 2
		else:
			plate_ramp.required_count = 1
		plate_ramp.activated.connect(func(): gate_ramp.open_gate())

	# Socket activations
	if clam_socket:
		clam_socket.socket_activated.connect(_on_socket_activated)
	if clam_socket_2 and need_second_pearl:
		clam_socket_2.socket_activated.connect(_on_socket_activated)

	# Update level instructions
	if p_count >= 4:
		level_instruction = "4 PLAYERS: Push TWO heavy pearls (2 fish per pearl) into BOTH clam basins!"
	else:
		level_instruction = "2 PLAYERS: Both fish must push the heavy glowing pearl together into the clam basin!"

	var hud_ref = get_node_or_null("HUD/CoopHUD") as CoopHUD
	if hud_ref:
		hud_ref.setup_level_info(level_number, level_title, level_instruction)

func _on_socket_activated(sock_id: String) -> void:
	_sockets_filled[sock_id] = true
	var p_count := maxi(2, GameManager.players.size())

	if p_count >= 4:
		# Need both sockets filled
		if _sockets_filled.size() >= 2 and gate_exit:
			gate_exit.open_gate()
	else:
		# 1 socket is enough
		if gate_exit:
			gate_exit.open_gate()
