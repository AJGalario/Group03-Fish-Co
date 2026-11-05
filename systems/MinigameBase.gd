class_name MinigameBase
extends Node2D

@export var minigame_title: String = "Minigame"
@export var minigame_instructions: String = "Survive!"
@export var round_time: float = 30.0

@export var minigame_objective: String = "Survive!"
@export var minigame_description: String = ""
@export var minigame_controls_p1: String = "Use WASD"
@export var minigame_controls_p2: String = "Use Arrow Keys"

var time_remaining: float = 30.0
var is_active: bool = false
var surviving_player_ids: Array = []
var eliminated_order: Array = []

# When true (default), the round ends as soon as one player remains.
# Survival minigames (DebrisDash, Flappy Fish) set this to false so the
# surviving player keeps playing until the timer expires.
@export var end_round_on_last_survivor: bool = true

# Minigame introduction & ready-up system states
# 0 = INTRO: Show introduction and instructions
# 1 = READY: Independently register player readiness, wait for both
# 2 = COUNTDOWN: 3-second countdown (gameplay DISABLED)
# 3 = PLAYING: Full gameplay active
var intro_state: int = 0 # 0=INTRO, 1=READY, 2=COUNTDOWN, 3=PLAYING

var player_ready_1: bool = false
var player_ready_2: bool = false
var player_cancelled_1: bool = false
var player_cancelled_2: bool = false
# Per-player debounces: one player's key press must never swallow the other's
var ready_debounce_1: float = 0.0
var ready_debounce_2: float = 0.0
# Brief window in the READY state that lets a player cancel before countdown
var ready_confirm_timer: float = 0.0
var countdown_timer: float = 0.0

const READY_CONFIRM_TIME: float = 1.0

const READY_DEBOUNCE_TIME: float = 0.25

@onready var hud: CanvasLayer = $HUD
@onready var timer_label: Label = $HUD/Margin/TopBar/TimerLabel
@onready var instructions_label: Label = $HUD/CenterInfo/InstructionsLabel

# Redesigned intro overlay (built in _build_intro_overlay)
var intro_overlay: Control = null
var intro_ready_chip_1: PanelContainer = null
var intro_ready_chip_2: PanelContainer = null
var intro_status_label: Label = null

func _ready() -> void:
	# The minigame's own round_time is authoritative. The match config value
	# is only applied when the user explicitly customized it in settings
	# (tracked by round_time_customized). Previously EVERY minigame was
	# silently forced to the config's 30s default, which broke DebrisDash's
	# 45s design and made all difficulty curves impossible to complete.
	if GameManager.match_config and GameManager.match_config.round_time_customized:
		round_time = clampf(GameManager.match_config.round_time, 30.0, 60.0)
	time_remaining = round_time

	# Apply chosen custom background theme
	_apply_background_theme()

	EventBus.player_died.connect(_on_player_died)

	# Always-two-players guarantee: a minigame entered directly (e.g. F6 from
	# the editor) still gets the default two fish instead of an empty tank.
	if GameManager.players.size() < 2:
		GameManager.setup_local_players(2)

	setup_players()

	# Start in INTRODUCTION state instead of going straight to countdown
	_reset_ready_flags()
	intro_state = 0
	_build_intro_overlay()
	_update_intro_ui()
	_update_round_label()

func _apply_background_theme() -> void:
	# Unified visual direction: every minigame shares the main-menu ocean
	# backdrop, tinted by the selected match theme for variety.
	var art: TextureRect = TextureRect.new()
	art.texture = load("res://assets/generated/menu_ocean_bg.png")
	art.size = Vector2(1920, 1080)
	art.position = Vector2.ZERO
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.z_index = -20
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	# Theme tint over the art (translucent, keeps the ocean look)
	var bg = get_node_or_null("WaterBackground")
	if bg and bg is ColorRect:
		var tint: Color = GameManager.match_config.get_bg_color() if GameManager.match_config else Color(0.05, 0.2, 0.34)
		tint.a = 0.25
		bg.color = tint

	# Gentle rising bubbles behind the gameplay
	var ambience: Node2D = Node2D.new()
	ambience.z_index = -10
	add_child(ambience)
	UIHelpers.spawn_bubbles(ambience, load("res://assets/generated/ui_bubble.png"), 7, Vector2(1920, 1080))

func setup_players() -> void:
	surviving_player_ids.clear()
	eliminated_order.clear()

	var spawn_points = $SpawnPoints.get_children()
	var fish_scene = preload("res://entities/fish/FishPlayer.tscn")

	for i in range(GameManager.players.size()):
		var pd = GameManager.players[i]
		pd.reset_for_round()
		surviving_player_ids.append(pd.player_id)

		var fish = fish_scene.instantiate()
		fish.player_id = pd.player_id
		fish.peer_id = pd.peer_id
		var pt = spawn_points[i % spawn_points.size()] as Marker2D
		fish.global_position = pt.global_position
		add_child(fish)

	# Pause fish physics initially during intro/ready so players can configure controls
	_set_all_fish_physics(false)

func _set_all_fish_physics(enabled: bool) -> void:
	for child in get_children():
		if child is FishPlayer:
			child.set_physics_process(enabled)

func start_countdown() -> void:
	# This is called at the end of STATE 1 transition
	is_active = false
	if instructions_label:
		instructions_label.visible = true

	# 3-Second Visual Countdown
	countdown_timer = 3.0
	for count in [3, 2, 1]:
		if instructions_label:
			instructions_label.text = "%s\n\nStarting in %d..." % [minigame_instructions, count]
		await get_tree().create_timer(1.0).timeout

	if instructions_label:
		instructions_label.text = "SWIM! 🚀"

	# Enable fish physics and activate gameplay
	_set_all_fish_physics(true)
	is_active = true

	await get_tree().create_timer(0.6).timeout
	if instructions_label:
		instructions_label.visible = false

# Returns a friendly, human-readable key name for an input action,
# e.g. "p1_action" -> "Space", "p2_action" -> "Enter".
# Falls back to the raw action name if no key is bound.
func get_key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return action

# Called ONCE when the minigame loads - never per-frame.
func _reset_ready_flags() -> void:
	player_ready_1 = false
	player_ready_2 = false
	player_cancelled_1 = false
	player_cancelled_2 = false
	ready_debounce_1 = 0.0
	ready_debounce_2 = 0.0
	ready_confirm_timer = 0.0

func _process(delta: float) -> void:
	# Minigame introduction & ready-up state machine

	# Tick the per-player ready-up debounce timers
	if ready_debounce_1 > 0.0:
		ready_debounce_1 = maxf(0.0, ready_debounce_1 - delta)
	if ready_debounce_2 > 0.0:
		ready_debounce_2 = maxf(0.0, ready_debounce_2 - delta)

	# === STATE 0: INTRODUCTION ===
	if intro_state == 0:
		# Show introduction screen with title, objectives, controls
		_update_intro_ui()

		# Each player registers readiness independently, with an independent
		# debounce so P1's press can never swallow P2's press.
		# Readiness PERSISTS between frames - it is only cleared when the
		# minigame loads (_reset_ready_flags), never inside _update_intro_ui.
		if Input.is_action_just_pressed("p1_action") and ready_debounce_1 <= 0.0:
			player_ready_1 = true
			ready_debounce_1 = READY_DEBOUNCE_TIME
			_update_intro_ui()
		if Input.is_action_just_pressed("p2_action") and ready_debounce_2 <= 0.0:
			player_ready_2 = true
			ready_debounce_2 = READY_DEBOUNCE_TIME
			_update_intro_ui()

		# Transition to READY state when BOTH players are ready
		# (They don't need to press simultaneously - each at their own pace)
		if player_ready_1 and player_ready_2:
			intro_state = 1
			ready_confirm_timer = READY_CONFIRM_TIME
			_update_intro_ui()

	# === STATE 1: READY ===
	elif intro_state == 1:
		# Show readiness status - both players must confirm
		_update_intro_ui()

		# Brief confirmation window: a player may still cancel here.
		# Any toggle restarts the window so nobody is rushed.
		ready_confirm_timer -= delta

		# Allow either player to cancel (toggle off) or re-confirm readiness,
		# each with their own debounce.
		if Input.is_action_just_pressed("p1_action") and ready_debounce_1 <= 0.0:
			player_ready_1 = not player_ready_1
			player_cancelled_1 = not player_ready_1
			ready_debounce_1 = READY_DEBOUNCE_TIME
			ready_confirm_timer = READY_CONFIRM_TIME
			_update_intro_ui()
		if Input.is_action_just_pressed("p2_action") and ready_debounce_2 <= 0.0:
			player_ready_2 = not player_ready_2
			player_cancelled_2 = not player_ready_2
			ready_debounce_2 = READY_DEBOUNCE_TIME
			ready_confirm_timer = READY_CONFIRM_TIME
			_update_intro_ui()

		# Transition to COUNTDOWN only when:
		# - Both players are ready
		# - The confirmation window has elapsed (time to back out)
		# - Neither has cancelled their readiness
		if player_ready_1 and player_ready_2 and not player_cancelled_1 and not player_cancelled_2 \
				and ready_confirm_timer <= 0.0:
			intro_state = 2
			countdown_timer = 3.0
			_update_intro_ui()

	# === STATE 2: COUNTDOWN ===
	# Gameplay is NOT active during countdown
	# Fish movement disabled, timers frozen, only countdown runs
	elif intro_state == 2:
		# UI: Show countdown timer
		if instructions_label:
			instructions_label.visible = true
			countdown_timer -= delta
			# Clamp timer to prevent going negative before we check
			countdown_timer = max(0.0, countdown_timer)
			instructions_label.text = "READY...\n\n%d" % (int(countdown_timer) + 1)
			instructions_label.add_theme_font_size_override("font_size", 96)

		# CRITICAL: Fish physics and gameplay remain DISABLED during countdown
		# is_active stays false - minigame obstacles/logic should NOT run
		# is_active is only set to true when transitioning to STATE 3

		# Transition to PLAYING when countdown finishes
		if countdown_timer <= 0.0:
			# Countdown complete - transition to PLAYING
			intro_state = 3
			if intro_overlay:
				intro_overlay.visible = false
			if instructions_label:
				instructions_label.visible = false
			# Enable fish physics and activate gameplay
			_set_all_fish_physics(true)
			is_active = true

	# === STATE 3: PLAYING ===
	elif intro_state == 3:
		# Normal gameplay - timers active, fish physics enabled
		if not is_active:
			is_active = true

		if not surviving_player_ids.is_empty():
			time_remaining -= delta
			if timer_label:
				timer_label.text = "%02d" % max(0, int(time_remaining))

			if time_remaining <= 0.0:
				finish_minigame()

func _on_player_died(player_id: int) -> void:
	if player_id in surviving_player_ids:
		surviving_player_ids.erase(player_id)
		eliminated_order.append(player_id)

	# If no players are left alive at all, end the minigame immediately
	if surviving_player_ids.is_empty():
		finish_minigame()
	# Optionally end when only the last survivor remains (off for
	# timer-based survival minigames where the survivor keeps playing)
	elif surviving_player_ids.size() == 1 and end_round_on_last_survivor and GameManager.players.size() > 1:
		finish_minigame()

# --- Redesigned Introduction Overlay ---

# Extracts keycap legends from a human control string.
# "WASD to swim, SPACE to slap" -> ["W","A","S","D","SPACE","SLAP"]
static func parse_key_legends(control_text: String) -> Array:
	var legends: Array = []
	var tokens: PackedStringArray = control_text.replace(",", " ").split(" ", false)
	for token in tokens:
		var t: String = token.to_upper()
		match t:
			"WASD":
				legends.append_array(["W", "A", "S", "D"])
			"ARROW", "ARROWS":
				legends.append_array(["↑", "↓", "←", "→"])
			"TO", "AND", "OR", "KEYS", "KEY":
				pass
			_:
				# Keep single letters and known key words; skip duplicates
				if (t.length() == 1 or t in ["SPACE", "SLAP", "FLAP", "JUMP"]) and not legends.has(t):
					legends.append(t)
	return legends

func _build_intro_overlay() -> void:
	intro_overlay = Control.new()
	intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(intro_overlay)

	# Dim scrim behind the intro card
	var scrim: ColorRect = ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.01, 0.07, 0.12, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_overlay.add_child(scrim)

	# Central card
	var card: PanelContainer = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(980, 0)
	intro_overlay.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title: Label = UIHelpers.make_title_label(minigame_title, 52)
	vbox.add_child(title)

	var objective: Label = UIHelpers.make_sub_label(minigame_description if minigame_description != "" else minigame_instructions, 24, UIHelpers.MIST)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size = Vector2(880, 0)
	vbox.add_child(objective)

	# Two symmetric player sections with keycaps
	var players_row: HBoxContainer = HBoxContainer.new()
	players_row.add_theme_constant_override("separation", 40)
	players_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(players_row)

	players_row.add_child(_build_player_intro_section(0))
	players_row.add_child(_build_player_intro_section(1))

	# Ready chips + status line
	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 24)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(chips)
	intro_ready_chip_1 = _make_ready_chip(0)
	chips.add_child(intro_ready_chip_1)
	intro_ready_chip_2 = _make_ready_chip(1)
	chips.add_child(intro_ready_chip_2)

	intro_status_label = UIHelpers.make_sub_label("", 24, UIHelpers.CYAN)
	vbox.add_child(intro_status_label)

func _build_player_intro_section(player_id: int) -> PlayerPanel:
	var pd: PlayerData = GameManager.players[player_id] if player_id < GameManager.players.size() else null
	var player_color: Color = UIHelpers.P1_COLOR if player_id == 0 else UIHelpers.P2_COLOR
	var panel: PlayerPanel = PlayerPanel.new("PLAYER %d - %s" % [player_id + 1, pd.player_name if pd else "Fish"], player_color)

	var control_text: String = minigame_controls_p1 if player_id == 0 else minigame_controls_p2
	var legends: Array = parse_key_legends(control_text)
	if legends.is_empty():
		legends = ["?"]
	panel.content.add_child(UIHelpers.make_keycap_row(legends, 52))

	var ready_hint: Label = UIHelpers.make_sub_label(
		"Ready: %s" % get_key_label("p1_action" if player_id == 0 else "p2_action"),
		20, player_color)
	panel.content.add_child(ready_hint)
	return panel

func _make_ready_chip(player_id: int) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.custom_minimum_size = Vector2(230, 54)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = UIHelpers.NAVY_DEEP
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = UIHelpers.TEAL.darkened(0.3)
	chip.add_theme_stylebox_override("panel", sb)
	var l: Label = Label.new()
	l.text = "P%d NOT READY" % (player_id + 1)
	l.add_theme_font_size_override("font_size", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(l)
	chip.set_meta("player_id", player_id)
	chip.set_meta("label", l)
	return chip

func _update_ready_chip(chip: PanelContainer, is_ready: bool) -> void:
	var l: Label = chip.get_meta("label")
	var pid: int = chip.get_meta("player_id")
	var player_color: Color = UIHelpers.P1_COLOR if pid == 0 else UIHelpers.P2_COLOR
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = UIHelpers.GREEN.darkened(0.25) if is_ready else UIHelpers.NAVY_DEEP
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = player_color if is_ready else UIHelpers.TEAL.darkened(0.3)
	chip.add_theme_stylebox_override("panel", sb)
	l.text = "P%d READY!" % (pid + 1) if is_ready else "P%d NOT READY" % (pid + 1)
	l.add_theme_color_override("font_color", UIHelpers.CREAM)

func _update_intro_ui() -> void:
	# Update UI based on current intro state.
	# The styled overlay handles INTRO/READY; the plain instructions label
	# is kept for the big countdown number (state machine logic unchanged).

	if intro_state == 0 or intro_state == 1:
		if intro_overlay:
			intro_overlay.visible = true
		if intro_ready_chip_1:
			_update_ready_chip(intro_ready_chip_1, player_ready_1)
		if intro_ready_chip_2:
			_update_ready_chip(intro_ready_chip_2, player_ready_2)
		if intro_status_label:
			if player_ready_1 and player_ready_2:
				intro_status_label.text = "BOTH READY - STARTING COUNTDOWN!"
			elif player_ready_1:
				intro_status_label.text = "P1 is ready - waiting for P2..."
			elif player_ready_2:
				intro_status_label.text = "P2 is ready - waiting for P1..."
			else:
				intro_status_label.text = "Press your READY key to join the round!"
		if instructions_label:
			instructions_label.visible = false

	elif intro_state == 2:
		# COUNTDOWN: hide overlay, show big countdown on the styled label
		if intro_overlay:
			intro_overlay.visible = false
		if instructions_label:
			instructions_label.visible = true

	# STATE 3 handled by existing code below (hides the label)

# --- Round Completion ---

# Reports final placements to the session manager once per round.
# Rankings: winners (finish order) first, then survivors, then eliminated
# players in reverse elimination order (last eliminated ranks highest).
func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	var final_rank: Array = []
	for pid in surviving_player_ids:
		if not final_rank.has(pid):
			final_rank.append(pid)
	var reversed_eliminations: Array = eliminated_order.duplicate()
	reversed_eliminations.reverse()
	for pid in reversed_eliminations:
		if not final_rank.has(pid):
			final_rank.append(pid)

	# A two-player tie is when both players are still surviving and
	# no elimination happened - the subclass reports ties explicitly
	# via GameManager.complete_minigame(ranks, true) if it needs to.
	GameManager.call_deferred("complete_minigame", final_rank)

# --- Round Indicator Support ---

func _update_round_label() -> void:
	# Display "ROUND X OF Y" using GameManager session state.
	# The label lives in MinigameBase.tscn (HUD/Margin/TopBar/RoundLabel),
	# so every minigame inherits it without per-scene duplication.
	var round_label: Label = get_node_or_null("HUD/Margin/TopBar/RoundLabel")
	if round_label == null:
		return
	var total: int = GameManager.effective_rounds if GameManager.effective_rounds > 0 else GameManager.max_rounds
	var shown_round: int = maxi(1, GameManager.current_round)
	round_label.text = "ROUND %d OF %d" % [shown_round, total]
	round_label.visible = true
