extends MinigameBase

# Minigame 2: Flappy Fish - Two-Player Edition
# Both players compete on one shared screen, each in an independent lane.
# Elimination scoring: first eliminated = lowest, last surviving = highest.

const PillarScene = preload("res://scenes/minigames/mg_flappy_fish/CoralPillarPair.tscn")

# --- PROGRESSIVE DIFFICULTY ---
const BASE_SPEED: float = 240.0
const MAX_SPEED: float = 360.0
const BASE_GAP: float = 240.0
const MIN_GAP: float = 180.0
const BASE_INTERVAL: float = 1.8
const MIN_INTERVAL: float = 1.2

var pillar_timer: float = 0.0

# --- LANES ---
var player1_lane_x: float = 960.0
var player2_lane_x: float = 960.0

# --- ELIMINATION / SCORING STATE ---
var player_eliminated: Dictionary = {}
var player_distance: Dictionary = {}

@onready var p1_pillars: Node2D = $PillarContainer
@onready var p2_pillars: Node2D = $Player2PillarContainer

func _ready() -> void:
	minigame_title = "Flappy Fish"
	minigame_instructions = "P1: JUMP KEY FLAPS UP - AVOID THE CORAL! LAST FISH SWIMMING WINS!"
	minigame_controls_p1 = "W to flap"
	minigame_controls_p2 = "Up Arrow to flap"
	round_time = 40.0
	super._ready()

	for pd in GameManager.players:
		player_eliminated[pd.player_id] = false
		player_distance[pd.player_id] = 0.0
	_update_survival_ui()

func setup_players() -> void:
	super.setup_players()
	var idx = 0
	for child in get_children():
		if child is FishPlayer:
			child.base_speed = 0.0
			child.can_air_jump = true
			# Calibrated gravity & impulse: responsive flapping with smooth terminal velocity
			child.custom_gravity = 650.0
			child.max_fall_speed = 420.0
			child.jump_impulse = -380.0
			child.velocity = Vector2.ZERO
			# Stagger each player's starting column slightly so fish never overlap
			child.global_position = Vector2(250.0 + idx * 55.0, 540.0)
			idx += 1

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return

	# --- PROGRESSIVE DIFFICULTY (shared by both lanes for fairness) ---
	var progress: float = clampf((round_time - time_remaining) / round_time, 0.0, 1.0)
	var current_speed: float = BASE_SPEED + (MAX_SPEED - BASE_SPEED) * progress
	var current_gap: float = BASE_GAP - (BASE_GAP - MIN_GAP) * progress
	var current_interval: float = BASE_INTERVAL - (BASE_INTERVAL - MIN_INTERVAL) * progress

	# --- SPAWNING: one synchronized pattern, applied to BOTH lanes ---
	pillar_timer += delta
	if pillar_timer >= current_interval:
		pillar_timer = 0.0
		var gap_center: float = randf_range(320.0, 760.0)
		_spawn_lane_pair(p1_pillars, -1.0, gap_center, current_gap, current_speed)

	# --- SURVIVAL DISTANCE (progress tiebreaker) ---
	for pd in GameManager.players:
		if not player_eliminated[pd.player_id]:
			player_distance[pd.player_id] += current_speed * delta

	# --- GROUND/SKYBOX COLLISION ---
	# Check each living fish against ceiling and floor hazards
	for child in get_children():
		if child is FishPlayer and not child.is_dead:
			# Ceiling hazard: top 20px of screen
			if child.global_position.y < 20.0:
				child.die("Flew too high into the ceiling!")
			# Floor hazard: bottom area
			if child.global_position.y > 1040.0:
				child.die("Sank too deep into the floor!")

# Spawns one pillar pair for a lane. The pair's collision is restricted to
# that lane so neither player's obstacles can eliminate the other.
func _spawn_lane_pair(container: Node2D, lane_x: float, gap_center: float, gap_size: float, speed: float) -> void:
	var pillar: CoralPillarPair = PillarScene.instantiate() as CoralPillarPair
	pillar.position = Vector2(2000.0, 0.0)
	pillar.speed = speed
	pillar.lane_center_x = lane_x
	container.add_child(pillar)
	pillar.randomize_gap(gap_center, gap_size)

# Surviving player keeps swimming after an elimination - the round only
# ends when the timer expires or both players are gone.
func _on_player_died(player_id: int) -> void:
	if player_id in surviving_player_ids:
		surviving_player_ids.erase(player_id)
		eliminated_order.append(player_id)
	if player_eliminated.has(player_id):
		player_eliminated[player_id] = true
	_update_survival_ui()
	if surviving_player_ids.is_empty():
		finish_minigame()

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	# Rank survivors by distance traveled, then eliminated in reverse order.
	var survivors: Array = surviving_player_ids.duplicate()
	survivors.sort_custom(func(a: int, b: int) -> bool:
		return player_distance.get(a, 0.0) > player_distance.get(b, 0.0))

	var final_rank: Array = []
	for pid in survivors:
		final_rank.append(pid)
	var reversed_eliminations: Array = eliminated_order.duplicate()
	reversed_eliminations.reverse()
	for pid in reversed_eliminations:
		final_rank.append(pid)

	# Tie: both players survived the whole round with identical distance,
	# or both were eliminated.
	var is_tie: bool = false
	if eliminated_order.is_empty() and survivors.size() == 2:
		is_tie = is_equal_approx(player_distance.get(0, 0.0), player_distance.get(1, 0.0))
	elif eliminated_order.size() == 2:
		is_tie = true

	GameManager.call_deferred("complete_minigame", final_rank, is_tie)

func _update_survival_ui() -> void:
	var label: Label = get_node_or_null("HUD/Margin/TopBar/survival_status_label")
	if label == null:
		return
	var parts: Array[String] = []
	for pd in GameManager.players:
		var status: String = "OUT" if player_eliminated.get(pd.player_id, false) else "IN"
		parts.append("P%d: %s" % [pd.player_id + 1, status])
	label.text = " | ".join(parts)
