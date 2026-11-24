extends MinigameBase

## PelletLaunch â€” Pellet Leap Frenzy
## Players launch out of the aquarium into the air to catch floating pellets!
## - 4 Players: 2v2 Teams working in two separate aquariums (Team 1 vs Team 2).
## - 2-3 Players: Solo free-for-all in a single wide aquarium.

const PelletScript = preload("res://scenes/minigames/mg_pellet_launch/LaunchPellet.gd")
const LaunchFishScript = preload("res://scenes/minigames/mg_pellet_launch/PelletLaunchFish.gd")

const WATER_SURFACE_Y: float = 630.0
const TANK_BOTTOM_Y: float = 1020.0

var is_team_mode: bool = false
var team_scores: Array[int] = [0, 0]
var player_scores: Dictionary = {} # pid -> score

var _fish_instances: Array[PelletLaunchFish] = []
var _pellets: Array[LaunchPellet] = []

# Spawn rates
var _pellet_spawn_timer: float = 0.0
const PELLET_SPAWN_INTERVAL: float = 0.8

# HUD score nodes
var _team1_score_label: Label
var _team2_score_label: Label
var _individual_score_labels: Dictionary = {} # pid -> Label

func _ready() -> void:
	minigame_title = "Pellet Leap Frenzy"
	end_round_on_last_survivor = false
	round_time = 35.0

	var p_count = GameManager.players.size()
	is_team_mode = (p_count == 4)

	if is_team_mode:
		minigame_instructions = "2v2 TANK LEAP! Hold Space/Enter to CHARGE from the depths!\nDive nose-down on re-entry or suffer a 2s belly flop stun!"
		minigame_objective = "Charge deep launches to snatch high pellets! Avoid belly flops!"
	else:
		minigame_instructions = "SOLO LEAP! Hold Space/Enter to CHARGE from the depths!\nDive nose-down on re-entry or suffer a 2s belly flop stun!"
		minigame_objective = "Charge deep launches to snatch pellets! Avoid belly flops!"

	minigame_controls_p1 = "WASD to swim/dive, Hold Space to Charge Launch"
	minigame_controls_p2 = "Arrows to swim/dive, Hold Enter to Charge Launch"

	super._ready()
	_build_tanks_environment()
	_build_score_hud()
	_spawn_initial_pellets()

func setup_players() -> void:
	# Clear any base spawn markers and populate surviving players so round timer counts down!
	surviving_player_ids.clear()
	eliminated_order.clear()
	_fish_instances.clear()

	var p_count = GameManager.players.size()
	is_team_mode = (p_count == 4)

	for i in range(p_count):
		var pd = GameManager.players[i]
		pd.reset_for_round()
		surviving_player_ids.append(pd.player_id)
		player_scores[pd.player_id] = 0

		var fish = CharacterBody2D.new()
		fish.set_script(LaunchFishScript)
		fish.player_id = pd.player_id
		fish.is_bot = pd.is_bot
		fish.player_name = pd.player_name
		fish.player_color = pd.get_color()
		fish.water_surface_y = WATER_SURFACE_Y
		fish.tank_floor_y = TANK_BOTTOM_Y

		if is_team_mode:
			# Team 1: Players 0 & 1 (Tank 1: X in [110, 890])
			# Team 2: Players 2 & 3 (Tank 2: X in [1030, 1810])
			if i < 2:
				fish.team_id = 0
				fish.tank_min_x = 110.0
				fish.tank_max_x = 890.0
				fish.position = Vector2(320.0 + i * 360.0, 820.0)
			else:
				fish.team_id = 1
				fish.tank_min_x = 1030.0
				fish.tank_max_x = 1810.0
				fish.position = Vector2(1240.0 + (i - 2) * 360.0, 820.0)
		else:
			# 2-3 Players Solo Mode (Single Wide Tank: X in [120, 1800])
			fish.team_id = i
			fish.tank_min_x = 120.0
			fish.tank_max_x = 1800.0
			var col_step = (1800.0 - 120.0) / (p_count + 1)
			fish.position = Vector2(120.0 + col_step * (i + 1), 820.0)

		fish.breached_surface.connect(_on_fish_breached)
		fish.splashed_down.connect(_on_fish_splashed)

		add_child(fish)
		_fish_instances.append(fish)

	# Initially freeze fish physics during intro and countdown
	_set_all_fish_physics(false)

func _set_all_fish_physics(enabled: bool) -> void:
	for fish in _fish_instances:
		if is_instance_valid(fish):
			fish.set_physics_process(enabled)

func _build_tanks_environment() -> void:
	# Air / Sky backdrop above water line
	var air_bg = ColorRect.new()
	air_bg.position = Vector2(0, 0)
	air_bg.size = Vector2(1920, WATER_SURFACE_Y)
	air_bg.color = Color(0.04, 0.1, 0.22, 1.0)
	air_bg.z_index = -10
	add_child(air_bg)

	# Stars / gentle light rays in the air
	for s in range(16):
		var star = ColorRect.new()
		star.size = Vector2(3, 3)
		star.position = Vector2(randf_range(60, 1860), randf_range(50, WATER_SURFACE_Y - 40))
		star.color = Color(0.8, 0.95, 1.0, randf_range(0.3, 0.8))
		star.z_index = -9
		add_child(star)

	if is_team_mode:
		_build_tank_visual(Vector2(90, WATER_SURFACE_Y), Vector2(820, TANK_BOTTOM_Y - WATER_SURFACE_Y), "TEAM 1 TANK", Color(0.2, 0.85, 1.0))
		_build_tank_visual(Vector2(1010, WATER_SURFACE_Y), Vector2(820, TANK_BOTTOM_Y - WATER_SURFACE_Y), "TEAM 2 TANK", Color(0.85, 0.45, 1.0))

		# Central glass divider
		var divider = ColorRect.new()
		divider.position = Vector2(950, 100)
		divider.size = Vector2(20, 940)
		divider.color = Color(0.3, 0.7, 0.9, 0.35)
		divider.z_index = -2
		add_child(divider)

		var vs_badge = Label.new()
		vs_badge.text = "VS"
		vs_badge.position = Vector2(935, WATER_SURFACE_Y - 80)
		vs_badge.add_theme_font_size_override("font_size", 34)
		vs_badge.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		add_child(vs_badge)
	else:
		_build_tank_visual(Vector2(100, WATER_SURFACE_Y), Vector2(1720, TANK_BOTTOM_Y - WATER_SURFACE_Y), "THE AQUARIUM", Color(0.3, 0.85, 1.0))

func _build_tank_visual(tank_pos: Vector2, tank_size: Vector2, tank_name: String, border_color: Color) -> void:
	# Water body
	var water_rect = ColorRect.new()
	water_rect.position = tank_pos
	water_rect.size = tank_size
	water_rect.color = Color(0.06, 0.22, 0.42, 0.85)
	water_rect.z_index = -8
	add_child(water_rect)

	# Sand floor
	var sand_rect = ColorRect.new()
	sand_rect.position = Vector2(tank_pos.x, tank_pos.y + tank_size.y - 45.0)
	sand_rect.size = Vector2(tank_size.x, 45.0)
	sand_rect.color = Color(0.72, 0.62, 0.4, 0.95)
	sand_rect.z_index = -7
	add_child(sand_rect)

	# Glass outline border
	var glass = ReferenceRect.new()
	glass.position = tank_pos
	glass.size = tank_size
	glass.border_color = border_color
	glass.border_width = 3.0
	glass.editor_only = false
	glass.z_index = -3
	add_child(glass)

	# Glowing water surface ripple line
	var surface_line = ColorRect.new()
	surface_line.position = Vector2(tank_pos.x, tank_pos.y - 2.0)
	surface_line.size = Vector2(tank_size.x, 6.0)
	surface_line.color = Color(0.4, 0.9, 1.0, 0.8)
	surface_line.z_index = -4
	add_child(surface_line)

	# Tank label below water surface
	var lbl = Label.new()
	lbl.text = tank_name
	lbl.position = Vector2(tank_pos.x + 20, tank_pos.y + 16)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", border_color.lerp(Color.WHITE, 0.4))
	lbl.z_index = -5
	add_child(lbl)

func _build_score_hud() -> void:
	var top_bar = get_node_or_null("HUD/Margin/TopBar")
	if not top_bar:
		return

	if is_team_mode:
		var score_box = HBoxContainer.new()
		score_box.add_theme_constant_override("separation", 35)
		top_bar.add_child(score_box)

		_team1_score_label = Label.new()
		_team1_score_label.text = "TEAM 1 (P1+P2): 0 PTS"
		_team1_score_label.add_theme_font_size_override("font_size", 28)
		_team1_score_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
		score_box.add_child(_team1_score_label)

		var sep = Label.new()
		sep.text = "â”‚"
		sep.add_theme_font_size_override("font_size", 26)
		sep.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 0.6))
		score_box.add_child(sep)

		_team2_score_label = Label.new()
		_team2_score_label.text = "TEAM 2 (P3+P4): 0 PTS"
		_team2_score_label.add_theme_font_size_override("font_size", 28)
		_team2_score_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.95))
		score_box.add_child(_team2_score_label)
	else:
		var score_box = HBoxContainer.new()
		score_box.add_theme_constant_override("separation", 25)
		top_bar.add_child(score_box)

		for pd in GameManager.players:
			var chip = Label.new()
			chip.text = "%s: 0 PTS" % pd.player_name
			chip.add_theme_font_size_override("font_size", 24)
			chip.add_theme_color_override("font_color", pd.get_color().lerp(Color.WHITE, 0.3))
			score_box.add_child(chip)
			_individual_score_labels[pd.player_id] = chip

func _spawn_initial_pellets() -> void:
	if is_team_mode:
		for i in range(4):
			_spawn_pellet(0) # Tank 1
			_spawn_pellet(1) # Tank 2
	else:
		for i in range(7):
			_spawn_pellet(0)

func _spawn_pellet(tank_idx: int) -> void:
	var pellet = Area2D.new()
	pellet.set_script(PelletScript)
	pellet.tank_index = tank_idx
	pellet.is_golden = (randf() < 0.22) # 22% chance of golden +3 pellet
	pellet.point_value = 3 if pellet.is_golden else 1

	if is_team_mode:
		if tank_idx == 0:
			pellet.tank_min_x = 140.0
			pellet.tank_max_x = 860.0
		else:
			pellet.tank_min_x = 1060.0
			pellet.tank_max_x = 1780.0
	else:
		pellet.tank_min_x = 160.0
		pellet.tank_max_x = 1760.0

	var spawn_x = randf_range(pellet.tank_min_x, pellet.tank_max_x)
	var spawn_y = randf_range(160.0, WATER_SURFACE_Y - 90.0)
	pellet.position = Vector2(spawn_x, spawn_y)
	pellet.base_y = spawn_y

	pellet.collected.connect(_on_pellet_collected)

	add_child(pellet)
	_pellets.append(pellet)

func _process(delta: float) -> void:
	super._process(delta)

	if not is_active:
		return

	# Maintain active pellet population
	_pellet_spawn_timer += delta
	if _pellet_spawn_timer >= PELLET_SPAWN_INTERVAL:
		_pellet_spawn_timer = 0.0
		_clean_pellet_list()

		if is_team_mode:
			var t1_count = _count_pellets_in_tank(0)
			var t2_count = _count_pellets_in_tank(1)
			if t1_count < 4:
				_spawn_pellet(0)
			if t2_count < 4:
				_spawn_pellet(1)
		else:
			if _pellets.size() < 7:
				_spawn_pellet(0)

	# Update bot targets
	_update_bot_targets()

func _clean_pellet_list() -> void:
	var valid: Array[LaunchPellet] = []
	for p in _pellets:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			valid.append(p)
	_pellets = valid

func _count_pellets_in_tank(tank_idx: int) -> int:
	var c = 0
	for p in _pellets:
		if is_instance_valid(p) and p.tank_index == tank_idx:
			c += 1
	return c

func _update_bot_targets() -> void:
	for fish in _fish_instances:
		if not fish.is_bot:
			continue

		var best_pellet: LaunchPellet = null
		var min_dist_sq: float = 9999999.0

		for p in _pellets:
			if not is_instance_valid(p) or p.is_queued_for_deletion():
				continue
			if is_team_mode and p.tank_index != fish.team_id:
				continue

			var d_sq = fish.global_position.distance_squared_to(p.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best_pellet = p

		fish.bot_target_pellet = best_pellet

func _on_pellet_collected(pellet: LaunchPellet, by_body: Node2D) -> void:
	var fish = by_body as PelletLaunchFish
	if not fish:
		return

	var pts = pellet.point_value
	player_scores[fish.player_id] = player_scores.get(fish.player_id, 0) + pts

	if is_team_mode:
		var team = fish.team_id
		team_scores[team] += pts
		_refresh_hud_scores()
	else:
		_refresh_hud_scores()

func _refresh_hud_scores() -> void:
	if is_team_mode:
		if _team1_score_label:
			_team1_score_label.text = "TEAM 1 (P1+P2): %d PTS" % team_scores[0]
		if _team2_score_label:
			_team2_score_label.text = "TEAM 2 (P3+P4): %d PTS" % team_scores[1]
	else:
		for pid in _individual_score_labels:
			var lbl = _individual_score_labels[pid]
			var pd = GameManager.get_player_data(pid)
			var p_name = pd.player_name if pd else ("P%d" % (pid + 1))
			lbl.text = "%s: %d PTS" % [p_name, player_scores.get(pid, 0)]

func _on_fish_breached(_fish: PelletLaunchFish, at_pos: Vector2) -> void:
	# Water splash effect on launch
	_spawn_splash_visual(Vector2(at_pos.x, WATER_SURFACE_Y), Color(0.4, 0.9, 1.0, 0.8))

func _on_fish_splashed(_fish: PelletLaunchFish, at_pos: Vector2, is_belly_flop: bool = false) -> void:
	if is_belly_flop:
		_spawn_belly_flop_splash(Vector2(at_pos.x, WATER_SURFACE_Y))
	else:
		_spawn_clean_dive_splash(Vector2(at_pos.x, WATER_SURFACE_Y))

func _spawn_clean_dive_splash(pos: Vector2) -> void:
	# Narrow vertical clean dive droplets
	for i in range(8):
		var splash = ColorRect.new()
		splash.size = Vector2(randf_range(5, 8), randf_range(8, 14))
		splash.position = pos + Vector2(randf_range(-10, 10), randf_range(-4, 2))
		splash.color = Color(0.65, 0.95, 1.0, 0.9)
		add_child(splash)

		var tw = splash.create_tween()
		tw.set_parallel(true)
		tw.tween_property(splash, "position:y", splash.position.y - randf_range(25, 45), 0.3)
		tw.tween_property(splash, "position:x", splash.position.x + randf_range(-12, 12), 0.3)
		tw.tween_property(splash, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(splash.queue_free)

func _spawn_belly_flop_splash(pos: Vector2) -> void:
	# Huge forceful horizontal water slap
	for i in range(16):
		var splash = ColorRect.new()
		splash.size = Vector2(randf_range(10, 20), randf_range(6, 12))
		var dir_side = -1.0 if randf() < 0.5 else 1.0
		splash.position = pos + Vector2(randf_range(-25, 25), randf_range(-6, 4))
		splash.color = Color(1.0, 0.6, 0.4, 0.95) if i % 2 == 0 else Color(1.0, 0.95, 0.8, 0.95)
		add_child(splash)

		var tw = splash.create_tween()
		tw.set_parallel(true)
		tw.tween_property(splash, "position:x", splash.position.x + dir_side * randf_range(30, 95), 0.35)
		tw.tween_property(splash, "position:y", splash.position.y - randf_range(10, 30), 0.35)
		tw.tween_property(splash, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(splash.queue_free)

	# Water shockwave bar
	var wave = ColorRect.new()
	wave.size = Vector2(12, 6)
	wave.position = Vector2(pos.x - 6, WATER_SURFACE_Y - 3)
	wave.color = Color(1.0, 0.85, 0.5, 0.85)
	add_child(wave)
	var wave_tw = wave.create_tween()
	wave_tw.set_parallel(true)
	wave_tw.tween_property(wave, "size", Vector2(110, 10), 0.3)
	wave_tw.tween_property(wave, "position", Vector2(pos.x - 55, WATER_SURFACE_Y - 5), 0.3)
	wave_tw.tween_property(wave, "modulate:a", 0.0, 0.32)
	wave_tw.chain().tween_callback(wave.queue_free)

func _spawn_splash_visual(pos: Vector2, color: Color) -> void:
	for i in range(5):
		var splash = ColorRect.new()
		splash.size = Vector2(randf_range(6, 12), randf_range(6, 12))
		splash.position = pos + Vector2(randf_range(-18, 18), randf_range(-6, 4))
		splash.color = color
		add_child(splash)

		var tw = splash.create_tween()
		tw.set_parallel(true)
		tw.tween_property(splash, "position:y", splash.position.y - randf_range(18, 35), 0.3)
		tw.tween_property(splash, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(splash.queue_free)

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	var ranked_pids: Array = []

	if is_team_mode:
		# 4-player team outcome: whichever team ate the most pellets wins!
		if team_scores[0] > team_scores[1]:
			# Team 1 wins
			ranked_pids = [0, 1, 2, 3]
		elif team_scores[1] > team_scores[0]:
			# Team 2 wins
			ranked_pids = [2, 3, 0, 1]
		else:
			# Team tie: give equal rank
			ranked_pids = [0, 1, 2, 3]
	else:
		# 2-3 players solo ranking by highest pellets eaten
		var sorted_pids = player_scores.keys()
		sorted_pids.sort_custom(func(a, b): return player_scores[a] > player_scores[b])
		ranked_pids = sorted_pids

	GameManager.call_deferred("complete_minigame", ranked_pids)
