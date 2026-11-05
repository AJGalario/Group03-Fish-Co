extends MinigameBase

# Minigame 4: Fish Feed Frenzy
# Collect falling fish feed to score. Feed also fills a slap meter:
# a full meter unlocks a slap that stuns the opponent for 1.5s.

const PelletScene = preload("res://scenes/minigames/mg_pellet_catch/FishPellet.tscn")

# --- SLAP METER ---
const SLAP_THRESHOLD: float = 10.0
const SLAP_COOLDOWN: float = 2.0
const STUN_DURATION: float = 1.5

var player_slap_meter: Dictionary = {}
var player_slap_cooldown: Dictionary = {}
var player_catches: Dictionary = {}

# --- SPAWNING ---
const BASE_SPAWN_RATE: float = 0.35
const MIN_SPAWN_RATE: float = 0.15
var pellet_spawn_timer: float = 0.0
var pattern_timer: float = 0.0
var current_pattern: int = 0

@onready var catch_score_label: Label = $HUD/Margin/TopBar/CatchScoreLabel
@onready var slap_meter_1: ProgressBar = $HUD/Margin/TopBar/SlapMeter1
@onready var slap_meter_2: ProgressBar = $HUD/Margin/TopBar/SlapMeter2

func _ready() -> void:
	minigame_title = "Fish Feed Frenzy"
	minigame_instructions = "EAT THE FALLING FEED! FILL THE SLAP METER TO STUN YOUR RIVAL!"
	minigame_controls_p1 = "WASD to swim, F to slap"
	minigame_controls_p2 = "Arrow Keys to swim, / to slap"
	round_time = 35.0
	super._ready()

	# The metered slap below fully owns the slap mechanic: the fish's
	# built-in cooldown slap must not fire on its own.
	for child in get_children():
		if child is FishPlayer:
			child.slap_enabled = false

	for pd in GameManager.players:
		player_slap_meter[pd.player_id] = 0.0
		player_slap_cooldown[pd.player_id] = 0.0
		player_catches[pd.player_id] = 0
	_update_catch_ui()
	_update_slap_ui()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return

	# --- SPAWN RATE increases over the round (0.35s -> 0.15s) ---
	var progress: float = clampf((round_time - time_remaining) / round_time, 0.0, 1.0)
	var spawn_rate: float = BASE_SPAWN_RATE - (BASE_SPAWN_RATE - MIN_SPAWN_RATE) * progress

	# --- PATTERNS rotate every 8 seconds: normal / cluster / tight pair ---
	pattern_timer += delta
	if pattern_timer >= 8.0:
		pattern_timer = 0.0
		current_pattern = (current_pattern + 1) % 3

	pellet_spawn_timer += delta
	if pellet_spawn_timer >= spawn_rate:
		pellet_spawn_timer = 0.0
		_spawn_pellet()

	# Cooldowns tick down
	for pid in player_slap_cooldown:
		if player_slap_cooldown[pid] > 0.0:
			player_slap_cooldown[pid] = maxf(0.0, player_slap_cooldown[pid] - delta)

	# Dedicated slap inputs - independent of movement, jump and ready-up
	if Input.is_action_just_pressed("p1_slap"):
		_try_slap(0)
	if Input.is_action_just_pressed("p2_slap"):
		_try_slap(1)

func _spawn_pellet() -> void:
	match current_pattern:
		0:
			_spawn_one(randf_range(200.0, 1720.0), 100.0)
		1:
			# Cluster of three, close together
			var cx: float = randf_range(350.0, 1570.0)
			for i in range(3):
				_spawn_one(cx + (i - 1) * 80.0, 100.0 + i * 30.0)
		2:
			# Tight pair with a small gap
			var center: float = randf_range(400.0, 1520.0)
			_spawn_one(center - 75.0, 100.0)
			_spawn_one(center + 75.0, 100.0)

func _spawn_one(x: float, y: float) -> void:
	var pellet: FishPellet = PelletScene.instantiate() as FishPellet
	pellet.position = Vector2(x, y)
	pellet.pellet_eaten.connect(_on_pellet_eaten)
	add_child(pellet)

func _on_pellet_eaten(player_id: int, _pellet: FishPellet) -> void:
	if not player_catches.has(player_id):
		return
	player_catches[player_id] += 1
	# The slap meter fills from food but stays separate from the score
	player_slap_meter[player_id] = minf(SLAP_THRESHOLD, player_slap_meter[player_id] + 1.0)
	_update_catch_ui()
	_update_slap_ui()

func _try_slap(player_id: int) -> void:
	if not is_active or not player_slap_meter.has(player_id):
		return
	if player_slap_cooldown[player_id] > 0.0:
		return
	if player_slap_meter[player_id] < SLAP_THRESHOLD:
		return

	# Consume the meter and start the cooldown
	player_slap_meter[player_id] = 0.0
	player_slap_cooldown[player_id] = SLAP_COOLDOWN
	_update_slap_ui()

	# Stun the opponent
	var opponent_id: int = 1 - player_id
	for child in get_children():
		if child is FishPlayer and child.player_id == opponent_id and not child.is_dead:
			child.apply_stun(STUN_DURATION)

func _update_catch_ui() -> void:
	if catch_score_label == null:
		return
	var parts: Array[String] = []
	for pd in GameManager.players:
		parts.append("P%d: %d" % [pd.player_id + 1, player_catches.get(pd.player_id, 0)])
	catch_score_label.text = "Feed: " + " | ".join(parts)

func _update_slap_ui() -> void:
	if slap_meter_1:
		slap_meter_1.value = player_slap_meter.get(0, 0.0) / SLAP_THRESHOLD * 100.0
	if slap_meter_2:
		slap_meter_2.value = player_slap_meter.get(1, 0.0) / SLAP_THRESHOLD * 100.0

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	var sorted_pids: Array = player_catches.keys()
	sorted_pids.sort_custom(func(a: int, b: int) -> bool:
		return player_catches[a] > player_catches[b])

	var is_tie: bool = sorted_pids.size() == 2 and player_catches[sorted_pids[0]] == player_catches[sorted_pids[1]]
	GameManager.call_deferred("complete_minigame", sorted_pids, is_tie)
