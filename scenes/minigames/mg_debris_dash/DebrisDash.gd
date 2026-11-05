extends MinigameBase

# Minigame 3: Debris Dash
# Survive the underwater debris field for the full round. The timer is the
# primary end condition - the round only ends early if every fish dies.
# Final ranking: survivors by distance survived, then eliminated fish in
# reverse elimination order.

const DebrisScene = preload("res://scenes/minigames/mg_debris_dash/SinkingDebris.tscn")

# --- CONFIGURABLE ROUND LENGTH ---
@export var round_duration: float = 60.0

# --- PROGRESSIVE DIFFICULTY CURVES (applied every frame while playing) ---
const SPEED_START: float = 200.0      # early-game world scroll (px/s)
const SPEED_END: float = 420.0        # late-game world scroll (px/s)
const INTERVAL_START: float = 1.10    # early-game seconds between spawns
const INTERVAL_END: float = 0.45      # late-game seconds between spawns
# Pattern complexity unlocks as the round progresses (fractions of round):
const PATTERN_MID_UNLOCK: float = 0.30   # diagonal formations join the pool
const PATTERN_LATE_UNLOCK: float = 0.60  # drifting hazards join the pool
const DOUBLE_SPAWN_CHANCE_LATE: float = 0.35

var debris_timer: float = 0.0
var pattern_timer: float = 0.0
var current_pattern: int = 0
var scroll_distance: float = 0.0
var player_distance: Dictionary = {}   # player_id -> distance survived (px)
var speed_multiplier: float = 1.0      # current difficulty multiplier (for display/debug)

@onready var world_container: Node2D = $WorldContainer

func _ready() -> void:
	minigame_title = "Debris Dash"
	minigame_instructions = "SURVIVE THE DEBRIS FIELD! DODGE EVERYTHING - LONGEST SURVIVAL WINS!"
	minigame_controls_p1 = "WASD to swim"
	minigame_controls_p2 = "Arrow Keys to swim"
	round_time = round_duration
	# Survival round: a lone survivor keeps swimming until the timer ends
	end_round_on_last_survivor = false
	super._ready()

func setup_players() -> void:
	super.setup_players()
	for child in get_children():
		if child is FishPlayer:
			child.zero_gravity = true
			child.base_speed = 460.0
			player_distance[child.player_id] = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return

	# --- PROGRESSIVE DIFFICULTY ---
	# progress 0.0 -> 1.0 across the whole round; drives speed, spawn rate
	# and which obstacle formations may appear.
	var progress: float = clampf(1.0 - time_remaining / round_time, 0.0, 1.0)
	var adjusted_speed: float = lerpf(SPEED_START, SPEED_END, progress)
	var adjusted_interval: float = lerpf(INTERVAL_START, INTERVAL_END, progress)
	speed_multiplier = adjusted_speed / SPEED_START

	# Scroll the world - debris rides in on the current
	world_container.position.x -= adjusted_speed * delta
	scroll_distance += adjusted_speed * delta

	# Surviving fish accumulate distance survived (the ranking metric)
	for child in get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path.ends_with("FishPlayer.gd") and not child.is_dead:
			player_distance[child.player_id] = scroll_distance

	# Spawn on the adjusted interval
	debris_timer += delta
	if debris_timer >= adjusted_interval:
		debris_timer = 0.0
		_spawn_debris_wave(progress)

	# --- FORMATION ROTATION: cycles faster as difficulty rises ---
	pattern_timer += delta
	if pattern_timer >= lerpf(3.0, 1.6, progress):
		pattern_timer = 0.0
		current_pattern = _pick_pattern(progress)

	# Fish swept past the left boundary wrap around to the right (screen wrap)
	# so they never get "lost" off-screen. Distance still accumulates while visible.
	for child in get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path.ends_with("FishPlayer.gd") and not child.is_dead:
			if child.global_position.x < -200.0:
				# Wrap to the right edge of the visible world
				child.global_position = Vector2(2100.0, child.global_position.y)

# Pattern pool widens as difficulty rises; always random for variety.
func _pick_pattern(progress: float) -> int:
	var pool: Array = [0, 1]
	if progress >= PATTERN_MID_UNLOCK:
		pool.append(2)
	if progress >= PATTERN_LATE_UNLOCK:
		pool.append(3)
	return pool[randi() % pool.size()]

func _spawn_debris_wave(progress: float) -> void:
	_spawn_debris_scene()
	# Late game: sometimes a second hazard in the same wave for pressure
	if progress >= PATTERN_LATE_UNLOCK and randf() < DOUBLE_SPAWN_CHANCE_LATE:
		_spawn_debris_scene()

func _spawn_debris_scene() -> void:
	var spawn_x: float = 2100.0 - world_container.position.x

	match current_pattern:
		0:
			# Early: single debris at a random height
			var debris: SinkingDebris = DebrisScene.instantiate() as SinkingDebris
			debris.position = Vector2(spawn_x, randf_range(160.0, 920.0))
			world_container.add_child(debris)
		1:
			# Horizontal row of three - dodge above or below
			var row_y: float = randf_range(300.0, 700.0)
			for i in range(3):
				var d: SinkingDebris = DebrisScene.instantiate() as SinkingDebris
				d.position = Vector2(spawn_x + i * 130.0, row_y)
				world_container.add_child(d)
		2:
			# Diagonal staircase - weave through
			var start_y: float = randf_range(200.0, 800.0)
			var step: float = 90.0 if randf() < 0.5 else -90.0
			for i in range(3):
				var d: SinkingDebris = DebrisScene.instantiate() as SinkingDebris
				d.position = Vector2(spawn_x + i * 140.0, clampf(start_y + step * i, 100.0, 980.0))
				world_container.add_child(d)
		3:
			# Drifting hazard - bobs up and down while crossing the screen
			var d: SinkingDebris = DebrisScene.instantiate() as SinkingDebris
			d.position = Vector2(spawn_x, randf_range(300.0, 780.0))
			d.drift_direction = -1.0 if randf() < 0.5 else 1.0
			d.drift_speed = randf_range(60.0, 140.0)
			d.drift_range = randf_range(120.0, 240.0)
			world_container.add_child(d)

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	# Rank survivors by distance survived (leader of the current),
	# then eliminated fish in reverse elimination order.
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

	# Tie: both players survived the full round with the same distance
	# (they accumulate distance identically while both alive).
	var is_tie: bool = eliminated_order.is_empty() and survivors.size() == 2 		and is_equal_approx(player_distance.get(0, 0.0), player_distance.get(1, 0.0))

	GameManager.call_deferred("complete_minigame", final_rank, is_tie)
