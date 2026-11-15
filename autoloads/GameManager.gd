extends Node

enum GameCategory { COOP, VS }
enum GameState { MAIN_MENU, LOBBY_AQUARIUM, MINIGAME, ROUND_RESULTS, PODIUM }

var current_state: GameState = GameState.MAIN_MENU
var current_category: GameCategory = GameCategory.VS

# Match Configuration
var match_config: MatchConfig = MatchConfig.new()

# Array of PlayerData
var players: Array[PlayerData] = []
var current_round: int = 0

# Co-op progression — highest level number the players have unlocked (starts at 1)
var coop_highest_unlocked_level: int = 1

# --- SESSION CONFIGURATION ---
# Editor-configurable default number of minigames per VS session
@export var max_rounds: int = 5

# Optional override set via start_vs_session(rounds). -1 = use editor max_rounds.
var session_max_rounds_override: int = -1

# Effective round count for the current session (computed at session start)
var effective_rounds: int = 5

# Avoid immediately repeating the previous minigame when possible
var previous_minigame_scene: String = ""

# All possible VS Minigames
var all_vs_minigames: Array[String] = [
	"res://scenes/minigames/mg_typing_race/DirectionalCombo.tscn",
	"res://scenes/minigames/mg_flappy_fish/FlappyFish.tscn",
	"res://scenes/minigames/mg_debris_dash/DebrisDash.tscn",
	"res://scenes/minigames/mg_pellet_catch/PelletCatch.tscn",
	"res://scenes/minigames/mg_puffer_panic/PufferPanic.tscn",
	"res://scenes/minigames/mg_pellet_launch/PelletLaunch.tscn"
]

# Co-op uses CoopLevelSelect → Level scenes directly (not this queue)
var coop_minigames: Array[String] = []

# Randomized queue: no minigame repeats until the pool has been exhausted
var _shuffled_queue: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_local_players(human_count: int = 2) -> void:
	players.clear()
	var names = ["Bubbles", "Finley", "Nemo", "Grim"]

	# Human players
	for i in range(human_count):
		var p = PlayerData.new()
		p.player_id = i
		p.peer_id = 1
		p.player_name = names[i % names.size()]
		p.character_skin = i
		p.is_local_controlled = true
		p.is_bot = false
		players.append(p)

	# Populate Bots according to match configuration
	var total_slots = 4
	var bots_to_add = min(match_config.bot_count, total_slots - players.size())
	for b in range(bots_to_add):
		var bot_id = players.size()
		var bot = PlayerData.new()
		bot.player_id = bot_id
		bot.peer_id = 1
		bot.player_name = "Bot " + ["Angler", "Manta", "Sharky", "Barnaby"][b % 4]
		bot.character_skin = bot_id
		bot.is_local_controlled = false
		bot.is_bot = true
		bot.bot_difficulty = match_config.bot_difficulty
		players.append(bot)

# --- SESSION START ---

# Original entry point used by AquariumLobby buttons. Kept fully working.
func start_game_loop(category: GameCategory = GameCategory.VS) -> void:
	start_vs_session(-1, category)

# New session entry point with optional round-count override.
# rounds < 0  -> use the editor-configured max_rounds (default 5)
# rounds >= 0 -> override the configured round count for this session
func start_vs_session(rounds: int = -1, category: GameCategory = GameCategory.VS) -> void:
	current_category = category

	if rounds >= 0:
		session_max_rounds_override = rounds
	# else: keep whatever override was previously set (or -1 = editor default)

	effective_rounds = _get_effective_rounds()

	# Reset ALL session state so a new session never reuses stale data
	current_round = 0
	previous_minigame_scene = ""
	_shuffled_queue.clear()

	# Reset cumulative scores for a fresh session
	for p in players:
		p.total_score = 0

	_build_shuffled_queue()
	next_round()

func _get_effective_rounds() -> int:
	if session_max_rounds_override >= 0:
		return session_max_rounds_override
	return max_rounds

# --- MINIGAME SELECTION ---

# Shuffle the pool. The queue naturally prevents repeats until it is
# exhausted; when it runs out mid-session it is rebuilt and reshuffled.
func _build_shuffled_queue() -> void:
	var pool: Array = []
	if current_category == GameCategory.VS:
		if match_config.enabled_minigames.size() > 0:
			pool = match_config.enabled_minigames.duplicate()
		else:
			pool = all_vs_minigames.duplicate()
	else:
		pool = coop_minigames.duplicate()

	if pool.is_empty():
		push_error("GameManager: minigame pool is empty for category " + str(current_category))

	_shuffled_queue = []
	for scene_path in pool:
		_shuffled_queue.append(scene_path)
	_shuffled_queue.shuffle()

# --- ROUND PROGRESSION ---

# Order matters:
#   1. Completion check BEFORE anything else (never end the session early)
#   2. Pick a minigame
#   3. THEN increment the round counter
#   4. THEN load the scene
func next_round() -> void:
	# 1. Session complete? Show the podium. Exactly effective_rounds
	#    minigames will have been played at this point.
	if current_round >= effective_rounds:
		show_podium()
		return

	# 2. Keep the queue stocked
	if _shuffled_queue.is_empty():
		_build_shuffled_queue()

	if _shuffled_queue.is_empty():
		push_error("GameManager: no minigames available - cannot start round")
		show_podium()
		return

	# 3. Pick a minigame, avoiding an immediate repeat of the previous
	#    one when another choice exists.
	var chosen_scene: String = _shuffled_queue.pop_front()
	if chosen_scene == previous_minigame_scene and not _shuffled_queue.is_empty():
		var alternative: String = _shuffled_queue.pop_front()
		_shuffled_queue.append(chosen_scene)
		chosen_scene = alternative

	# 4. Increment the counter only now that a minigame is actually starting
	current_round += 1
	previous_minigame_scene = chosen_scene

	# 5. Load the minigame with animated loading screen & trivia
	if SceneLoader:
		SceneLoader.change_scene(chosen_scene)
	else:
		var load_error: int = get_tree().change_scene_to_file(chosen_scene)
		if load_error != OK:
			push_error("GameManager: failed to load minigame scene '" + chosen_scene + "' (error " + str(load_error) + ") - returning to lobby")
			# A failed load does not count as a played round
			current_round -= 1
			previous_minigame_scene = ""
			current_state = GameState.LOBBY_AQUARIUM
			get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")
			return

	current_state = GameState.MINIGAME

# --- SCORING AND ROUND COMPLETION ---

# Placement-based session scoring:
#   1st: 3 pts, 2nd: 2 pts, 3rd: 1 pt, 4th: 0 pts
#   Tie (2 players): 2 pts each
# The current_state check prevents a second completion signal from
# awarding points twice for the same round.
func complete_minigame(ranked_player_ids: Array, tie: bool = false) -> void:
	if current_state == GameState.ROUND_RESULTS:
		push_warning("GameManager: complete_minigame called twice for one round - ignoring duplicate")
		return

	current_state = GameState.ROUND_RESULTS

	if tie and ranked_player_ids.size() == 2:
		var pd1: PlayerData = get_player_data(ranked_player_ids[0])
		var pd2: PlayerData = get_player_data(ranked_player_ids[1])
		if pd1:
			pd1.total_score += 2
		if pd2:
			pd2.total_score += 2
	else:
		var points = [3, 2, 1, 0]
		for i in range(ranked_player_ids.size()):
			var pid = ranked_player_ids[i]
			var pd = get_player_data(pid)
			if pd:
				var pts: int = points[min(i, points.size() - 1)]
				pd.total_score += pts

	if SceneLoader:
		SceneLoader.change_scene("res://scenes/ui/RoundResults.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/RoundResults.tscn")

func show_podium() -> void:
	current_state = GameState.PODIUM
	if SceneLoader:
		SceneLoader.change_scene("res://scenes/ui/Podium.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/Podium.tscn")

func get_player_data(player_id: int) -> PlayerData:
	for p in players:
		if p.player_id == player_id:
			return p
	return null
