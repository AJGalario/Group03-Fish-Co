extends Node

## InputManager — Auto-detects gamepads and remaps player input actions.
##
## How it works:
##   · P1 defaults to keyboard (WASD).
##   · P2 defaults to keyboard (Arrow keys).
##   · P3 and P4 are auto-assigned to connected gamepads (device 0, 1 …).
##     If no gamepad is present for that slot, they fall back to keyboard (IJKL / Numpad).
##
## Provides:
##   InputManager.get_device_type(player_id)        -> "keyboard" or "gamepad"
##   InputManager.get_control_scheme(player_id)     -> "WASD", "ARROWS", "GAMEPAD", "IJKL", "NUMPAD"
##   InputManager.get_direction_legends(player_id)  -> Dictionary of direction labels

signal device_changed(player_id: int, device_type: String)

const GAMEPAD_SLOTS = [2, 3]
var _device_map: Dictionary = {0: -1, 1: -1, 2: -1, 3: -1}

const LEGENDS_WASD    := {"Up": "W", "Left": "A", "Down": "S", "Right": "D"}
const LEGENDS_ARROWS  := {"Up": "↑", "Left": "←", "Down": "↓", "Right": "→"}
const LEGENDS_GAMEPAD := {"Up": "▲", "Left": "◄", "Down": "▼", "Right": "►"}
const LEGENDS_IJKL    := {"Up": "I", "Left": "J", "Down": "K", "Right": "L"}
const LEGENDS_NUMPAD  := {"Up": "8", "Left": "4", "Down": "5", "Right": "6"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_assign_gamepads()

func get_device_type(player_id: int) -> String:
	if _device_map.get(player_id, -1) >= 0:
		return "gamepad"
	return "keyboard"

func get_device_index(player_id: int) -> int:
	return _device_map.get(player_id, -1)

func is_using_gamepad(player_id: int) -> bool:
	return _device_map.get(player_id, -1) >= 0

func get_control_scheme(player_id: int) -> String:
	var pd = GameManager.get_player_data(player_id) if GameManager else null
	if pd and pd.control_scheme != "":
		return pd.control_scheme

	if is_using_gamepad(player_id):
		return "GAMEPAD"

	match player_id:
		0: return "WASD"
		1: return "ARROWS"
		2: return "IJKL"
		3: return "NUMPAD"
		_: return "WASD"

func get_direction_legends(player_id: int) -> Dictionary:
	var scheme = get_control_scheme(player_id)
	match scheme:
		"WASD":    return LEGENDS_WASD
		"ARROWS":  return LEGENDS_ARROWS
		"GAMEPAD": return LEGENDS_GAMEPAD
		"IJKL":    return LEGENDS_IJKL
		"NUMPAD":  return LEGENDS_NUMPAD
		_:         return LEGENDS_WASD

func set_player_claimed_scheme(player_id: int, scheme: String, dev_id: int = -1) -> void:
	var pd = GameManager.get_player_data(player_id) if GameManager else null
	if pd:
		pd.control_scheme = scheme
		pd.device_id = dev_id
		pd.is_claimed = true
	if dev_id >= 0:
		_device_map[player_id] = dev_id
		_remap_actions(player_id, dev_id)
	device_changed.emit(player_id, "gamepad" if dev_id >= 0 else "keyboard")

func _assign_gamepads() -> void:
	var connected = Input.get_connected_joypads()

	for slot_rank in range(GAMEPAD_SLOTS.size()):
		var pid = GAMEPAD_SLOTS[slot_rank]
		var old_device = _device_map.get(pid, -1)
		var new_device = -1

		if slot_rank < connected.size():
			new_device = connected[slot_rank]

		_device_map[pid] = new_device

		if new_device != old_device:
			_remap_actions(pid, new_device)
			_sync_player_data(pid, new_device)
			var dtype = "gamepad" if new_device >= 0 else "keyboard"
			device_changed.emit(pid, dtype)

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_assign_gamepads()

func _remap_actions(player_id: int, device_index: int) -> void:
	var prefix = "p%d_" % (player_id + 1)
	var dirs = ["up", "down", "left", "right", "jump", "action", "slap"]

	for dir in dirs:
		var action = prefix + dir
		if not InputMap.has_action(action):
			continue

		var kept = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				pass
			else:
				kept.append(ev)
		InputMap.action_erase_events(action)
		for ev in kept:
			InputMap.action_add_event(action, ev)

		if device_index >= 0:
			_add_joy_events(action, dir, device_index)

func _add_joy_events(action: String, dir: String, dev: int) -> void:
	match dir:
		"left":
			var ax = InputEventJoypadMotion.new()
			ax.device = dev
			ax.axis = JOY_AXIS_LEFT_X
			ax.axis_value = -1.0
			InputMap.action_add_event(action, ax)
			var dp = InputEventJoypadButton.new()
			dp.device = dev
			dp.button_index = JOY_BUTTON_DPAD_LEFT
			InputMap.action_add_event(action, dp)
		"right":
			var ax = InputEventJoypadMotion.new()
			ax.device = dev
			ax.axis = JOY_AXIS_LEFT_X
			ax.axis_value = 1.0
			InputMap.action_add_event(action, ax)
			var dp = InputEventJoypadButton.new()
			dp.device = dev
			dp.button_index = JOY_BUTTON_DPAD_RIGHT
			InputMap.action_add_event(action, dp)
		"up":
			var ax = InputEventJoypadMotion.new()
			ax.device = dev
			ax.axis = JOY_AXIS_LEFT_Y
			ax.axis_value = -1.0
			InputMap.action_add_event(action, ax)
			var dp = InputEventJoypadButton.new()
			dp.device = dev
			dp.button_index = JOY_BUTTON_DPAD_UP
			InputMap.action_add_event(action, dp)
		"down":
			var ax = InputEventJoypadMotion.new()
			ax.device = dev
			ax.axis = JOY_AXIS_LEFT_Y
			ax.axis_value = 1.0
			InputMap.action_add_event(action, ax)
			var dp = InputEventJoypadButton.new()
			dp.device = dev
			dp.button_index = JOY_BUTTON_DPAD_DOWN
			InputMap.action_add_event(action, dp)
		"jump":
			var btn = InputEventJoypadButton.new()
			btn.device = dev
			btn.button_index = JOY_BUTTON_A
			InputMap.action_add_event(action, btn)
		"action":
			var btn = InputEventJoypadButton.new()
			btn.device = dev
			btn.button_index = JOY_BUTTON_B
			InputMap.action_add_event(action, btn)
		"slap":
			var btn = InputEventJoypadButton.new()
			btn.device = dev
			btn.button_index = JOY_BUTTON_X
			InputMap.action_add_event(action, btn)

func _sync_player_data(player_id: int, device_index: int) -> void:
	if not GameManager:
		return
	var pd = GameManager.get_player_data(player_id)
	if pd:
		pd.device_id = device_index
		if device_index >= 0:
			pd.control_scheme = "GAMEPAD"
