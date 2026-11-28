extends CoopBase

## Level 1: First Splash — Cooperative Tutorial
## Dynamically scales challenge based on active player count:
##   - 2 Players: 1 button per chamber (Plate 1 -> Gate 1, Plate 2 -> Gate 2) -> 2 buttons total
##   - 3 Players: 2 buttons in Chamber 1, 1 button in Chamber 2 -> 3 buttons total
##   - 4 Players: 2 buttons in Chamber 1, 2 buttons in Chamber 2 -> 4 buttons total!

@onready var plate_1: PressurePlate = $Plate1
@onready var plate_1_b: PressurePlate = get_node_or_null("Plate1_B")
@onready var plate_2: PressurePlate = $Plate2
@onready var plate_2_b: PressurePlate = get_node_or_null("Plate2_B")
@onready var gate_1: CoralGate = $Gate1
@onready var gate_2: CoralGate = $Gate2

func _ready() -> void:
	super._ready()
	var p_count := maxi(2, GameManager.players.size())

	# Configure active plates based on player count
	var need_plate1_b := (p_count >= 3)
	var need_plate2_b := (p_count >= 4)

	if plate_1_b:
		plate_1_b.visible = need_plate1_b
		plate_1_b.monitoring = need_plate1_b
		plate_1_b.monitorable = need_plate1_b
		plate_1_b.process_mode = Node.PROCESS_MODE_INHERIT if need_plate1_b else Node.PROCESS_MODE_DISABLED

	if plate_2_b:
		plate_2_b.visible = need_plate2_b
		plate_2_b.monitoring = need_plate2_b
		plate_2_b.monitorable = need_plate2_b
		plate_2_b.process_mode = Node.PROCESS_MODE_INHERIT if need_plate2_b else Node.PROCESS_MODE_DISABLED

	# Connect plate signals
	if plate_1:
		plate_1.activated.connect(_check_gate_1)
		plate_1.deactivated.connect(_check_gate_1)
	if plate_1_b and need_plate1_b:
		plate_1_b.activated.connect(_check_gate_1)
		plate_1_b.deactivated.connect(_check_gate_1)

	if plate_2:
		plate_2.activated.connect(_check_gate_2)
		plate_2.deactivated.connect(_check_gate_2)
	if plate_2_b and need_plate2_b:
		plate_2_b.activated.connect(_check_gate_2)
		plate_2_b.deactivated.connect(_check_gate_2)

	# Update level instructions to show player count task
	if p_count >= 4:
		level_instruction = "4 PLAYERS: Coordinate in pairs to press both buttons together to open each gate!"
	elif p_count == 3:
		level_instruction = "3 PLAYERS: Press both cyan buttons together for Gate 1, then the orange button for Gate 2!"
	else:
		level_instruction = "2 PLAYERS: Step on the coral plates to open the gates for your team!"

	var hud_ref = get_node_or_null("HUD/CoopHUD") as CoopHUD
	if hud_ref:
		hud_ref.setup_level_info(level_number, level_title, level_instruction)

func _check_gate_1() -> void:
	if not gate_1:
		return
	var p_count := maxi(2, GameManager.players.size())
	var chamber_1_ready := false
	if p_count <= 2:
		chamber_1_ready = plate_1 != null and plate_1.is_pressed
	else:
		chamber_1_ready = (plate_1 != null and plate_1.is_pressed) and (plate_1_b != null and plate_1_b.is_pressed)

	var chamber_2_ready := false
	if p_count < 4:
		chamber_2_ready = plate_2 != null and plate_2.is_pressed
	else:
		chamber_2_ready = (plate_2 != null and plate_2.is_pressed) and (plate_2_b != null and plate_2_b.is_pressed)

	if chamber_1_ready or chamber_2_ready:
		gate_1.open_gate()
	else:
		gate_1.close_gate()

func _check_gate_2() -> void:
	if not gate_2:
		return
	var p_count := maxi(2, GameManager.players.size())
	var chamber_2_ready := false
	if p_count < 4:
		chamber_2_ready = plate_2 != null and plate_2.is_pressed
	else:
		chamber_2_ready = (plate_2 != null and plate_2.is_pressed) and (plate_2_b != null and plate_2_b.is_pressed)

	if chamber_2_ready:
		gate_2.open_gate()
	else:
		gate_2.close_gate()

	_check_gate_1()
