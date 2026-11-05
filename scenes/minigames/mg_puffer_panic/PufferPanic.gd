extends MinigameBase

# Minigame 5: Puffer Panic
# Eat pellets to inflate; the biggest pufferfish when time expires wins.
# Hazards: sharp coral deflates you, drifting debris knocks you back,
# water currents push you off course. Deflation grants brief immunity.

const FoodScene = preload("res://scenes/minigames/mg_puffer_panic/PufferFood.tscn")

# --- INFLATION ---
const START_INFLATION: float = 10.0
const MAX_INFLATION: float = 100.0
const FOOD_INFLATION: float = 8.0
const CORAL_DEFLATION: float = 15.0
const IMMUNITY_TIME: float = 1.2
const SPEED_PENALTY_MAX: float = 0.45  # up to 45% slower when fully inflated

var inflation: Dictionary = {}        # player_id -> float
var immunity_timer: Dictionary = {}   # player_id -> float remaining
var food_count: int = 0
const TARGET_FOOD_ON_SCREEN: int = 6

var hazard_corals: Array = []
var hazard_debris: Array = []
var hazard_currents: Array = []

@onready var hazard_container: Node2D = $HazardContainer
@onready var food_container: Node2D = $FoodContainer

func _ready() -> void:
	minigame_title = "Puffer Panic"
	minigame_instructions = "EAT PELLETS TO INFLATE! AVOID CORAL AND DEBRIS - BIGGEST FISH WINS!"
	minigame_controls_p1 = "WASD to swim"
	minigame_controls_p2 = "Arrow Keys to swim"
	round_time = 40.0
	end_round_on_last_survivor = false
	super._ready()

	for pd in GameManager.players:
		inflation[pd.player_id] = START_INFLATION
		immunity_timer[pd.player_id] = 0.0

	_build_hazards()
	_update_size_ui()

func setup_players() -> void:
	super.setup_players()
	for child in get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path.ends_with("FishPlayer.gd"):
			child.zero_gravity = true
			child.base_speed = 460.0
			child.slap_enabled = false

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return

	# Immunity timers tick down; tint wears off
	for pid in immunity_timer:
		if immunity_timer[pid] > 0.0:
			immunity_timer[pid] = maxf(0.0, immunity_timer[pid] - delta)
			if immunity_timer[pid] == 0.0:
				_set_fish_tint(pid, Color.WHITE)

	# Keep the arena stocked with food
	if food_count < TARGET_FOOD_ON_SCREEN:
		_spawn_food()

func _set_fish_tint(pid: int, color: Color) -> void:
	for child in get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path.ends_with("FishPlayer.gd") and child.player_id == pid:
			child.modulate = color

# --- FOOD ---

func _spawn_food() -> void:
	var food: Area2D = FoodScene.instantiate()
	food.position = Vector2(randf_range(150.0, 1770.0), randf_range(150.0, 900.0))
	food.body_entered.connect(_on_food_eaten.bind(food))
	food.tree_exited.connect(_on_food_removed)
	food_container.add_child(food)
	food_count += 1

func _on_food_removed() -> void:
	food_count -= 1

func _on_food_eaten(body: Node2D, food: Area2D) -> void:
	var s: Script = body.get_script()
	if s == null or not s.resource_path.ends_with("FishPlayer.gd"):
		return
	if not inflation.has(body.player_id):
		return
	# Everyone can always eat - eating is the recovery path after deflation
	inflation[body.player_id] = minf(MAX_INFLATION, inflation[body.player_id] + FOOD_INFLATION)
	_apply_size(body.player_id)
	_update_size_ui()
	food.queue_free()

func _apply_size(pid: int) -> void:
	for child in get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path.ends_with("FishPlayer.gd") and child.player_id == pid:
			var t: float = inflation[pid] / MAX_INFLATION
			var target_scale: float = 1.0 + t * 2.0  # 1x -> 3x
			child.set_body_scale(target_scale)
			# Bigger fish are slower to maneuver
			child.base_speed = 460.0 * (1.0 - SPEED_PENALTY_MAX * t)

# --- HAZARD CONSTRUCTION (built in code - no extra scenes needed) ---

func _build_hazards() -> void:
	# 3 sharp coral spikes around the arena
	var coral_positions: Array = [Vector2(960, 180), Vector2(300, 950), Vector2(1620, 950)]
	for pos in coral_positions:
		var coral: Area2D = _make_hazard_body(Vector2(70, 46), Color(0.9, 0.3, 0.25))
		coral.position = pos
		coral.body_entered.connect(_on_coral_hit)
		hazard_container.add_child(coral)
		hazard_corals.append(coral)

	# 2 drifting debris chunks that float across the arena
	for i in range(2):
		var debris: Area2D = _make_hazard_body(Vector2(60, 60), Color(0.45, 0.4, 0.35))
		debris.position = Vector2(randf_range(400.0, 1500.0), randf_range(250.0, 800.0))
		debris.set_meta("drift", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(60.0, 120.0))
		hazard_container.add_child(debris)
		hazard_debris.append(debris)

	# 2 water current zones that push fish sideways
	for i in range(2):
		var current: Area2D = _make_hazard_body(Vector2(260, 420), Color(0.3, 0.6, 0.9, 0.18), true)
		current.position = Vector2(500.0 + i * 900.0, 540.0)
		var push_x: float = 1.0 if i == 0 else -1.0
		current.set_meta("push_dir", Vector2(push_x, 0.0))
		current.set_meta("push_strength", 140.0)
		hazard_container.add_child(current)
		hazard_currents.append(current)

func _make_hazard_body(shape_size: Vector2, color: Color, sensor_only: bool = false) -> Area2D:
	var area: Area2D = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = shape_size
	shape.shape = rect
	area.add_child(shape)
	var visual: ColorRect = ColorRect.new()
	visual.position = -shape_size / 2.0
	visual.size = shape_size
	visual.color = color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(visual)
	if sensor_only:
		area.monitoring = true
	return area

func _on_coral_hit(body: Node2D) -> void:
	var s: Script = body.get_script()
	if s == null or not s.resource_path.ends_with("FishPlayer.gd"):
		return
	var pid: int = body.player_id
	if not inflation.has(pid) or immunity_timer[pid] > 0.0:
		return

	# Deflate with knockback, animation and brief immunity
	immunity_timer[pid] = IMMUNITY_TIME
	inflation[pid] = maxf(START_INFLATION, inflation[pid] - CORAL_DEFLATION)
	_apply_size(pid)
	_update_size_ui()

	# Knockback away from the nearest coral
	var away: Vector2 = (body.global_position - _nearest_coral_position(body.global_position)).normalized()
	if away == Vector2.ZERO:
		away = Vector2(0, -1)
	body.position += away * 90.0

	# Deflation animation: quick squash + red flash
	_set_fish_tint(pid, Color(1.0, 0.4, 0.4))
	var tween: Tween = create_tween()
	tween.tween_property(body, "scale", Vector2(0.7, 0.7), 0.1)
	tween.tween_property(body, "scale", Vector2.ONE, 0.25)

func _nearest_coral_position(from: Vector2) -> Vector2:
	var nearest: Vector2 = Vector2(960, 540)
	var best: float = INF
	for coral in hazard_corals:
		var d: float = coral.global_position.distance_squared_to(from)
		if d < best:
			best = d
			nearest = coral.global_position
	return nearest

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Drift the debris chunks and bounce them off arena bounds
	for debris in hazard_debris:
		var drift: Vector2 = debris.get_meta("drift", Vector2.ZERO)
		debris.position += drift * delta
		if debris.position.x < 120.0 or debris.position.x > 1800.0:
			drift.x = -drift.x
			debris.set_meta("drift", drift)
		if debris.position.y < 120.0 or debris.position.y > 960.0:
			drift.y = -drift.y
			debris.set_meta("drift", drift)

	# Water currents continuously push fish inside their zone
	for current in hazard_currents:
		for body in current.get_overlapping_bodies():
			var s: Script = body.get_script()
			if s != null and s.resource_path.ends_with("FishPlayer.gd"):
				var push_dir: Vector2 = current.get_meta("push_dir", Vector2.ZERO)
				var push_strength: float = current.get_meta("push_strength", 0.0)
				body.position += push_dir * push_strength * delta

	# Keep both fish inside the arena
	for child in get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path.ends_with("FishPlayer.gd"):
			child.position.x = clampf(child.position.x, 120.0, 1800.0)
			child.position.y = clampf(child.position.y, 120.0, 960.0)

# --- SCORING ---

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	var pids: Array = inflation.keys()
	pids.sort_custom(func(a: int, b: int) -> bool:
		return inflation[a] > inflation[b])
	var ranked: Array = []
	for pid in pids:
		ranked.append(pid)

	var is_tie: bool = pids.size() == 2 and is_equal_approx(inflation[pids[0]], inflation[pids[1]])
	GameManager.call_deferred("complete_minigame", ranked, is_tie)

func _update_size_ui() -> void:
	var bar1: ProgressBar = get_node_or_null("HUD/Margin/TopBar/InflationBar1")
	var bar2: ProgressBar = get_node_or_null("HUD/Margin/TopBar/InflationBar2")
	if bar1:
		bar1.value = inflation.get(0, 0.0)
	if bar2:
		bar2.value = inflation.get(1, 0.0)
