extends MinigameBase

# Minigame 1: Directional Combo Duel (boxing edition)
# Bodybuilder fish punch each other when combos are completed.
# Health bars replace scores - first to 0 health loses.
# Control legends dynamically adjust to each player's claimed control scheme (WASD, Arrows, Gamepad, IJKL, Numpad).

const SEQUENCE_LENGTH: int = 4
const STARTING_HEALTH: int = 30
const DAMAGE_PER_COMBO: int = 2
const ERROR_PENALTY: int = 1
const ERROR_FLASH_TIME: float = 0.25

var patterns: Dictionary = {}         # pid -> Array[String]
var input_buffers: Dictionary = {}    # pid -> Array[String]
var player_health: Dictionary = {}    # pid -> int
var bot_timers: Dictionary = {}       # pid -> float

var error_flash_timer: float = 0.0
var error_flash_player: int = -1

# --- UI STATE ---
var duel_panels: Array = []
var duel_health_bars: Dictionary = {}        # pid -> ProgressBar
var duel_health_value_labels: Dictionary = {} # pid -> Label
var duel_keycaps: Dictionary = {}            # pid -> Array[Keycap]

func _ready() -> void:
	minigame_title = "Directional Combo Duel"
	minigame_instructions = "LAND COMBO PUNCHES! EACH COMBO DEALS DAMAGE. FIRST TO 0 HEALTH LOSES!"
	
	# Dynamically describe controls based on active player setups
	_update_controls_descriptions()
	
	round_time = 30.0
	end_round_on_last_survivor = false
	super._ready()

	for pd in GameManager.players:
		var pid = pd.player_id
		player_health[pid] = STARTING_HEALTH
		input_buffers[pid] = []
		bot_timers[pid] = 0.0
		generate_new_sequence(pid)

	_build_duel_interface()
	_update_boxing_ui()

func _update_controls_descriptions() -> void:
	var hints: Array[String] = []
	for pd in GameManager.players:
		var scheme = InputManager.get_control_scheme(pd.player_id) if InputManager else "WASD"
		var scheme_desc = "WASD"
		match scheme:
			"WASD":    scheme_desc = "W, A, S, D"
			"ARROWS":  scheme_desc = "Arrow Keys"
			"GAMEPAD": scheme_desc = "D-Pad"
			"IJKL":    scheme_desc = "I, J, K, L"
			"NUMPAD":  scheme_desc = "Numpad"
		hints.append("P%d: %s" % [pd.player_id + 1, scheme_desc])

	if hints.size() > 0:
		minigame_controls_p1 = hints[0]
	if hints.size() > 1:
		minigame_controls_p2 = hints[1]

func setup_players() -> void:
	super.setup_players()
	var count = GameManager.players.size()
	
	# Compute X positions based on player count
	var x_positions: Array[float] = []
	match count:
		1: x_positions = [960.0]
		2: x_positions = [860.0, 1060.0]
		3: x_positions = [600.0, 960.0, 1320.0]
		_: x_positions = [400.0, 770.0, 1150.0, 1520.0]

	var idx = 0
	for child in get_children():
		if child is FishPlayer:
			child.set_physics_process(false)
			var pos_x = x_positions[idx % x_positions.size()]
			child.global_position = Vector2(pos_x, 560.0)
			
			# Face toward center
			if pos_x < 960.0:
				child.set_body_scale(2.5)
			else:
				child.set_body_scale(-2.5)

			# Gentle idle bobbing motion
			var bob: Tween = create_tween().set_loops()
			bob.tween_property(child, "position:y", child.global_position.y - 24.0, 1.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bob.tween_property(child, "position:y", child.global_position.y, 1.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			idx += 1

# --- INTERFACE CONSTRUCTION ---

func _build_duel_interface() -> void:
	if hud == null:
		return

	var count = GameManager.players.size()
	var panel_w: float = 380.0 if count <= 2 else (320.0 if count == 3 else 280.0)
	var total_w: float = 1920.0
	var spacing: float = (total_w - (count * panel_w)) / (count + 1)

	for i in range(count):
		var pd = GameManager.players[i]
		var pid = pd.player_id
		var p_color = pd.get_color()
		var p_x: float = spacing + i * (panel_w + spacing)

		var panel: PlayerPanel = PlayerPanel.new("PLAYER %d" % (pid + 1), p_color)
		panel.position = Vector2(p_x, 100.0)
		panel.custom_minimum_size = Vector2(panel_w, 0)
		hud.add_child(panel)

		# Subtitle showing claimed scheme
		var scheme = InputManager.get_control_scheme(pid) if InputManager else "WASD"
		var scheme_lbl = Label.new()
		scheme_lbl.text = "[%s]" % scheme
		scheme_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scheme_lbl.add_theme_font_size_override("font_size", 14)
		scheme_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.75))
		panel.content.add_child(scheme_lbl)

		# Health bar display
		var health_bar: ProgressBar = ProgressBar.new()
		health_bar.custom_minimum_size = Vector2(panel_w - 40.0, 36.0)
		health_bar.min_value = 0
		health_bar.max_value = STARTING_HEALTH
		health_bar.value = player_health.get(pid, STARTING_HEALTH)
		health_bar.show_percentage = false
		panel.content.add_child(health_bar)
		duel_health_bars[pid] = health_bar

		# Numeric health label
		var health_val_lbl: Label = Label.new()
		health_val_lbl.text = "%d HP" % player_health.get(pid, STARTING_HEALTH)
		health_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		health_val_lbl.add_theme_font_size_override("font_size", 16)
		health_val_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		panel.content.add_child(health_val_lbl)
		duel_health_value_labels[pid] = health_val_lbl

		# Keycap sequence row
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.content.add_child(row)

		var cap_size = 56.0 if count <= 2 else (48.0 if count == 3 else 44.0)
		var caps: Array = []
		for s in range(SEQUENCE_LENGTH):
			var cap: Keycap = Keycap.new("►", cap_size)
			row.add_child(cap)
			caps.append(cap)
		duel_keycaps[pid] = caps

		duel_panels.append(panel)

func _legend_for(player_id: int, direction: String) -> String:
	if InputManager:
		var table: Dictionary = InputManager.get_direction_legends(player_id)
		return table.get(direction, direction)
	return direction

# --- GAMEPLAY ---

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return

	# Keep fish stationery from gravity
	for child in get_children():
		if child is FishPlayer:
			child.set_physics_process(false)

	# Poll input or AI for each active player
	for pd in GameManager.players:
		var pid = pd.player_id
		if player_health.get(pid, 0) <= 0:
			continue

		if pd.is_bot:
			_process_bot_turn(pid, delta)
		else:
			_poll_player_input(pid)

	if error_flash_timer > 0.0:
		error_flash_timer = maxf(0.0, error_flash_timer - delta)
		if error_flash_timer == 0.0:
			error_flash_player = -1
			_update_boxing_ui()

func _poll_player_input(player_id: int) -> void:
	var prefix: String = "p%d_" % (player_id + 1)
	var dirs: Array[String] = ["up", "left", "down", "right"]
	for dir_name in dirs:
		if Input.is_action_just_pressed(prefix + dir_name):
			_on_direction_input(player_id, dir_name.capitalize())

func _process_bot_turn(player_id: int, delta: float) -> void:
	bot_timers[player_id] = bot_timers.get(player_id, 0.0) + delta
	var pd = GameManager.get_player_data(player_id)
	var interval = 0.55
	if pd:
		match pd.bot_difficulty:
			PlayerData.BotDifficulty.HARD: interval = 0.38
			PlayerData.BotDifficulty.EASY: interval = 0.75
			_: interval = 0.55

	if bot_timers[player_id] >= interval:
		bot_timers[player_id] = 0.0
		var pattern = patterns.get(player_id, [])
		var buffer = input_buffers.get(player_id, [])
		if buffer.size() < pattern.size():
			_on_direction_input(player_id, pattern[buffer.size()])

func _on_direction_input(player_id: int, dir_name: String) -> void:
	var buffer: Array = input_buffers.get(player_id, [])
	var pattern: Array = patterns.get(player_id, [])

	if buffer.size() >= pattern.size():
		return

	if dir_name == pattern[buffer.size()]:
		buffer.append(dir_name)
		if buffer.size() >= pattern.size():
			_on_sequence_complete(player_id)
		_update_boxing_ui()
	else:
		# Wrong key penalty
		buffer.clear()
		player_health[player_id] = maxi(0, player_health.get(player_id, STARTING_HEALTH) - ERROR_PENALTY)
		error_flash_player = player_id
		error_flash_timer = ERROR_FLASH_TIME
		_update_boxing_ui()
		_check_elimination(player_id)

func _on_sequence_complete(player_id: int) -> void:
	# Punch the opponent with the highest health among other players
	var target_pid: int = -1
	var max_target_hp: int = -1

	for pd in GameManager.players:
		var other_pid = pd.player_id
		if other_pid != player_id and player_health.get(other_pid, 0) > 0:
			if player_health[other_pid] > max_target_hp:
				max_target_hp = player_health[other_pid]
				target_pid = other_pid

	if target_pid >= 0:
		player_health[target_pid] = maxi(0, player_health[target_pid] - DAMAGE_PER_COMBO)
		_play_punch_visual(player_id, target_pid)
		_check_elimination(target_pid)

	# Reset sequence for this player
	input_buffers[player_id].clear()
	generate_new_sequence(player_id)
	_update_boxing_ui()

func _play_punch_visual(attacker_pid: int, target_pid: int) -> void:
	for child in get_children():
		if child is FishPlayer:
			if child.player_id == attacker_pid:
				var tw = create_tween()
				tw.tween_property(child, "scale", child.scale * 1.25, 0.1)
				tw.tween_property(child, "scale", child.scale, 0.1)
			elif child.player_id == target_pid:
				child.modulate = Color(1.5, 0.4, 0.4)
				var tw = create_tween()
				tw.tween_interval(0.18)
				tw.tween_property(child, "modulate", Color.WHITE, 0.15)

func _check_elimination(player_id: int) -> void:
	if player_health.get(player_id, 0) <= 0:
		if player_id in surviving_player_ids:
			surviving_player_ids.erase(player_id)
			eliminated_order.append(player_id)

		for child in get_children():
			if child is FishPlayer and child.player_id == player_id:
				child.modulate = Color(0.4, 0.4, 0.4, 0.6)

		# If 1 or 0 survivors remain, conclude duel
		if surviving_player_ids.size() <= 1 and GameManager.players.size() > 1:
			finish_minigame()

func generate_new_sequence(player_id: int) -> void:
	var dirs: Array[String] = ["Up", "Left", "Down", "Right"]
	var pattern: Array[String] = []
	for i in range(SEQUENCE_LENGTH):
		pattern.append(dirs[randi() % dirs.size()])
	patterns[player_id] = pattern

# --- UI UPDATES ---

func _update_boxing_ui() -> void:
	for pd in GameManager.players:
		var pid = pd.player_id
		var pat = patterns.get(pid, [])
		var buf = input_buffers.get(pid, [])
		_update_player_keycaps(pid, pat, buf)

		if duel_health_bars.has(pid):
			duel_health_bars[pid].value = player_health.get(pid, 0)
		if duel_health_value_labels.has(pid):
			var hp = player_health.get(pid, 0)
			duel_health_value_labels[pid].text = "%d HP" % hp
			if hp <= 10:
				duel_health_value_labels[pid].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				duel_health_value_labels[pid].add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))

func _update_player_keycaps(player_id: int, pattern: Array, buffer: Array) -> void:
	if not duel_keycaps.has(player_id):
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

	# Rank survivors by remaining health (descending), then eliminated players in reverse order
	var survivors: Array = surviving_player_ids.duplicate()
	survivors.sort_custom(func(a: int, b: int) -> bool:
		return player_health.get(a, 0) > player_health.get(b, 0)
	)

	var final_rank: Array = []
	for pid in survivors:
		final_rank.append(pid)

	var rev_elim = eliminated_order.duplicate()
	rev_elim.reverse()
	for pid in rev_elim:
		final_rank.append(pid)

	# Failsafe: ensure all players are included
	for pd in GameManager.players:
		if pd.player_id not in final_rank:
			final_rank.append(pd.player_id)

	var is_tie = false
	if survivors.size() >= 2:
		is_tie = (player_health.get(survivors[0], 0) == player_health.get(survivors[1], 0))

	GameManager.call_deferred("complete_minigame", final_rank, is_tie)
