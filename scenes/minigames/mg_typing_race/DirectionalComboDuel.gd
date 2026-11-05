extends MinigameBase

# Minigame 1: Directional Combo Duel (boxing edition)
# Two bodybuilder fish punch each other when combos are completed.
# Health bars replace scores - first to 0 health loses.
# 30-second round timer as fallback.

const SEQUENCE_LENGTH: int = 4
const STARTING_HEALTH: int = 30
const DAMAGE_PER_COMBO: int = 2
const ERROR_PENALTY: int = 1
const ERROR_FLASH_TIME: float = 0.25

# Legends per player: P1 keys, P2 arrow glyphs
const P1_LEGENDS := {"Up": "W", "Left": "A", "Down": "S", "Right": "D"}
const P2_LEGENDS := {"Up": "↑", "Left": "←", "Down": "↓", "Right": "→"}

var p1_pattern: Array[String] = []
var p2_pattern: Array[String] = []
var p1_input_buffer: Array[String] = []
var p2_input_buffer: Array[String] = []
var p1_health: int = STARTING_HEALTH
var p2_health: int = STARTING_HEALTH
var error_flash_timer: float = 0.0
var error_flash_player: int = -1

# --- UI STATE ---
var duel_panels: Array = []          # index 0 = P1, 1 = P2
var duel_health_bars: Array = []     # per player: ProgressBar
var duel_health_value_labels: Array = []     # per player: Label showing numeric value
var duel_keycaps: Array = []         # per player: Array of Keycap (legacy, for legend display)
var duel_sequence_labels: Array = []

func _ready() -> void:
	minigame_title = "Directional Combo Duel"
	minigame_instructions = "LAND COMBO PUNCHES! EACH COMBO DEALS DAMAGE. FIRST TO 0 HEALTH LOSES!"
	minigame_controls_p1 = "W, A, S, D to enter sequences"
	minigame_controls_p2 = "Arrow Keys to enter sequences"
	round_time = 30.0
	end_round_on_last_survivor = false
	super._ready()

	setup_players()  # <-- ADD THIS
	_build_duel_interface()
	generate_new_sequence(0)
	generate_new_sequence(1)
	_update_boxing_ui()
	generate_new_sequence(0)
	generate_new_sequence(1)
	_update_boxing_ui()

func setup_players() -> void:
	super.setup_players()
	# Bodybuilder fish closeups: positioned centrally as facing pair, scaled up for visibility.
	for child in get_children():
		if child is FishPlayer:
			child.set_physics_process(false)
			if child.player_id == 0:
				child.global_position = Vector2(900.0, 540.0)  # P1 left side
			else:
				child.global_position = Vector2(1020.0, 540.0)  # P2 right side
			# Scale up for "closeup" readability at 1080p
			child.set_body_scale(3.0)
			# Gentle idle bob for life
			var bob: Tween = create_tween()
			bob.set_loops()
			bob.tween_property(child, "position:y", child.global_position.y - 30.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bob.tween_property(child, "position:y", child.global_position.y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- INTERFACE CONSTRUCTION ---

func _build_duel_interface() -> void:
	if hud == null:
		return
	var specs: Array = [
		{"player": 0, "color": UIHelpers.P1_COLOR, "x": 100.0},
		{"player": 1, "color": UIHelpers.P2_COLOR, "x": 1100.0},
	]
	for spec in specs:
		var pid: int = spec["player"]
		var panel: PlayerPanel = PlayerPanel.new("PLAYER %d" % (pid + 1), spec["color"])
		panel.position = Vector2(spec["x"], 110.0)
		panel.custom_minimum_size = Vector2(400, 0)
		hud.add_child(panel)

		# Health bar display - green for boxing theme
		var health_bar: ProgressBar = ProgressBar.new()
		health_bar.size = Vector2(300, 40)
		health_bar.min_value = 0
		health_bar.max_value = STARTING_HEALTH
		health_bar.value = STARTING_HEALTH
		health_bar.add_theme_color_override("font_color", Color("00ff00"))
		# Godot ProgressBar bar color override - use modulate tint instead
		health_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)  # white base, tint green via shader not supported; keep font green
		panel.content.add_child(health_bar)
		duel_health_bars.append(health_bar)

		# Numeric health value label (e.g., "30")
		var health_val_lbl: Label = Label.new()
		health_val_lbl.text = str(STARTING_HEALTH)
		health_val_lbl.add_theme_color_override("font_color", Color("00ff00"))
		health_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Estimate label width: "30" at 24px font ~ 24px wide, center at x=150
		health_val_lbl.position = Vector2(138, 8)
		panel.content.add_child(health_val_lbl)
		duel_health_value_labels.append(health_val_lbl)

		# Keycap sequence row - larger, more visible for boxing duel, centered
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.content.add_child(row)
		var caps: Array = []
		# Set row's position to be centered - Godot BoxContainer auto-placement
		# will center children, but we need the row itself positioned
		row.position = Vector2(0, 40)  # position below health bar, centered
		for i in range(SEQUENCE_LENGTH):
			var cap: Keycap = Keycap.new("►", 72)  # bigger, arrow-style keycaps
			row.add_child(cap)
			caps.append(cap)
		duel_keycaps.append(caps)

		# Sequence progress text removed per design - clean UI

		duel_panels.append(panel)

func _legend_for(player_id: int, direction: String) -> String:
	var table: Dictionary = P1_LEGENDS if player_id == 0 else P2_LEGENDS
	return table.get(direction, "?")

# --- GAMEPLAY ---

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return

	# This minigame has no floor: the base state machine re-enables fish
	# physics after the countdown, and gravity would drop them off-screen.
	# The fish are station displays here - keep them parked and let the
	# idle bob tween provide the motion.
	for child in get_children():
		if child is FishPlayer:
			child.set_physics_process(false)

	_poll_player_input(0)
	_poll_player_input(1)

	if error_flash_timer > 0.0:
		error_flash_timer = maxf(0.0, error_flash_timer - delta)
		if error_flash_timer == 0.0:
			error_flash_player = -1
			_update_boxing_ui()

func _poll_player_input(player_id: int) -> void:
	var prefix: String = "p1_" if player_id == 0 else "p2_"
	var dirs: Array[String] = ["up", "left", "down", "right"]
	for dir_name in dirs:
		if Input.is_action_just_pressed(prefix + dir_name):
			_on_direction_input(player_id, dir_name.capitalize())

func _on_direction_input(player_id: int, dir_name: String) -> void:
	var buffer: Array[String] = p1_input_buffer if player_id == 0 else p2_input_buffer
	var pattern: Array[String] = p1_pattern if player_id == 0 else p2_pattern

	if buffer.size() >= pattern.size():
		return
	if dir_name == pattern[buffer.size()]:
		buffer.append(dir_name)
		if buffer.size() >= pattern.size():
			_on_sequence_complete(player_id)
		_update_boxing_ui()
	else:
		# Wrong key: penalty - lose 1 health (never below 0) and reset attempt
		if player_id == 0:
			p1_input_buffer.clear()
			p1_health = maxi(0, p1_health - ERROR_PENALTY)
		else:
			p2_input_buffer.clear()
			p2_health = maxi(0, p2_health - ERROR_PENALTY)
		error_flash_player = player_id
		error_flash_timer = ERROR_FLASH_TIME
		_update_boxing_ui()

func _on_sequence_complete(player_id: int) -> void:
	# Land a punch on the opponent when combo is completed
	if player_id == 0:
		p2_health = maxi(0, p2_health - DAMAGE_PER_COMBO)
	else:
		p1_health = maxi(0, p1_health - DAMAGE_PER_COMBO)
	# Visual punch effect could be added here (animation, particle)
	_update_boxing_ui()

	# Clear buffers and generate new sequence
	if player_id == 0:
		p1_input_buffer.clear()
		generate_new_sequence(0)
	else:
		p2_input_buffer.clear()
		generate_new_sequence(1)

func generate_new_sequence(player_id: int) -> void:
	var dirs: Array[String] = ["Up", "Left", "Down", "Right"]
	var pattern: Array[String] = []
	for i in range(SEQUENCE_LENGTH):
		pattern.append(dirs[randi() % dirs.size()])
	if player_id == 0:
		p1_pattern = pattern
	else:
		p2_pattern = pattern

# --- UI UPDATES ---

func _update_boxing_ui() -> void:
	_update_player_keycaps(0, p1_pattern, p1_input_buffer)
	_update_player_keycaps(1, p2_pattern, p2_input_buffer)
	if duel_health_bars.size() >= 2:
		duel_health_bars[0].value = p1_health
		duel_health_bars[1].value = p2_health

func _update_player_keycaps(player_id: int, pattern: Array[String], buffer: Array[String]) -> void:
	if player_id >= duel_keycaps.size():
		return
	var caps: Array = duel_keycaps[player_id]
	var flashing: bool = error_flash_timer > 0.0 and error_flash_player == player_id
	for i in range(caps.size()):
		var cap: Keycap = caps[i]
		if i < pattern.size():
			cap.set_legend(_legend_for(player_id, pattern[i]))
		if flashing and i == buffer.size():
			cap.set_state("error")
		elif i < buffer.size():
			cap.set_state("completed")
		elif i == buffer.size():
			cap.set_state("highlighted")
		else:
			cap.set_state("normal")

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	# Winner: first player to reduce opponent to 0 health wins.
	# If timer expires without either at 0, highest health wins.
	var final_rank: Array
	var is_tie: bool = p1_health == p2_health
	if p1_health <= 0:
		final_rank = [0, 1]  # P1 knocked out, P2 wins
	elif p2_health <= 0:
		final_rank = [1, 0]  # P2 knocked out, P1 wins
	elif p1_health > p2_health:
		final_rank = [0, 1]
	else:
		final_rank = [1, 0]

	GameManager.call_deferred("complete_minigame", final_rank, is_tie)
