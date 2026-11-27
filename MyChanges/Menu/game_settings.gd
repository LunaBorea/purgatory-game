extends Node
## MyChanges: player settings (autoload "GameSettings").
##
## - Every action works with WASD AND the arrow keys, and with a gamepad.
## - Keys can be changed in the menu (2 keys per action). Gamepad buttons stay as they are.
## - Volume, fullscreen and V-Sync.
## Everything is saved to user://settings.cfg and loaded when the game starts.

signal changed

const SAVE_PATH := "user://settings.cfg"

## The actions the player can rebind, in the order the menu shows them.
const ACTIONS: Array[Dictionary] = [
	{"action": "left", "label": "Move Left"},
	{"action": "right", "label": "Move Right"},
	{"action": "jump", "label": "Jump"},
	{"action": "further", "label": "Lane Back"},
	{"action": "closer", "label": "Lane Front"},
	{"action": "dash", "label": "Dash"},
	{"action": "orb_toggle", "label": "Orb"},
	{"action": "orb_platform", "label": "Use Orb Holder"},
	{"action": "pause", "label": "Pause Menu"},
]

## Default keyboard keys [first, second]. KEY_NONE = empty slot.
const DEFAULT_KEYS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_NONE],
	"further": [KEY_W, KEY_UP],
	"closer": [KEY_S, KEY_DOWN],
	"dash": [KEY_SHIFT, KEY_NONE],
	"orb_toggle": [KEY_R, KEY_NONE],
	"orb_platform": [KEY_F, KEY_NONE],
	"pause": [KEY_ESCAPE, KEY_NONE],
}

## Gamepad defaults (added only if the action has no gamepad input yet).
const DEFAULT_PAD_BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A],
	"further": [JOY_BUTTON_DPAD_UP],
	"closer": [JOY_BUTTON_DPAD_DOWN],
	"dash": [JOY_BUTTON_B],
	"orb_toggle": [JOY_BUTTON_Y],
	"orb_platform": [JOY_BUTTON_X],
	"pause": [JOY_BUTTON_START],
}
const DEFAULT_PAD_AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0],
	"right": [JOY_AXIS_LEFT_X, 1.0],
}

var master_volume := 1.0
var fullscreen := false
var vsync := true

var _keys := {}  # action -> [keycode, keycode]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry in ACTIONS:
		var action: String = entry.action
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		_add_gamepad_defaults(action)
	_add_menu_keys()
	_keys = _default_keys()
	load_settings()
	apply_all()


## Menus work with the arrow keys AND WASD; Enter / Space / E to choose, Backspace to go back.
func _add_menu_keys() -> void:
	var extra := {
		"ui_up": [KEY_W], "ui_down": [KEY_S], "ui_left": [KEY_A], "ui_right": [KEY_D],
		"ui_accept": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E],
		"ui_cancel": [KEY_BACKSPACE],
	}
	for action in extra:
		for keycode in extra[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


# ------------------------------------------------------------------ keys

func get_key(action: String, slot: int) -> Key:
	return _keys.get(action, [KEY_NONE, KEY_NONE])[slot]


## Sets a key. If another action already used that key, it is taken away from it
## (so one key never does two things). Returns the label of that action, or "".
func set_key(action: String, slot: int, keycode: Key) -> String:
	var taken_from := ""
	if keycode != KEY_NONE:
		for other in _keys:
			for i in 2:
				if _keys[other][i] == keycode and not (other == action and i == slot):
					_keys[other][i] = KEY_NONE
					taken_from = label_for(other)
	_keys[action][slot] = keycode
	_apply_keys()
	save_settings()
	changed.emit()
	return taken_from


func reset_keys() -> void:
	_keys = _default_keys()
	_apply_keys()
	save_settings()
	changed.emit()


func label_for(action: String) -> String:
	for entry in ACTIONS:
		if entry.action == action:
			return entry.label
	return action


static func key_name(keycode: Key) -> String:
	if keycode == KEY_NONE:
		return "—"
	match keycode:
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_ESCAPE: return "Esc"
	return OS.get_keycode_string(keycode)


func _default_keys() -> Dictionary:
	var keys := {}
	for action in DEFAULT_KEYS:
		keys[action] = (DEFAULT_KEYS[action] as Array).duplicate()
	return keys


func _apply_keys() -> void:
	for action in _keys:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		for keycode in _keys[action]:
			if keycode != KEY_NONE:
				var event := InputEventKey.new()
				# Physical keys: the same place on the keyboard on every layout (WASD on AZERTY too).
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)


func _add_gamepad_defaults(action: String) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return
	for button in DEFAULT_PAD_BUTTONS.get(action, []):
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	if DEFAULT_PAD_AXES.has(action):
		var motion := InputEventJoypadMotion.new()
		motion.axis = DEFAULT_PAD_AXES[action][0]
		motion.axis_value = DEFAULT_PAD_AXES[action][1]
		InputMap.action_add_event(action, motion)
	InputMap.action_set_deadzone(action, 0.3)


# ------------------------------------------------------------------ other settings

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window()
	save_settings()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_window()
	save_settings()


func apply_all() -> void:
	_apply_keys()
	_apply_volume()
	_apply_window()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)


func _apply_window() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ------------------------------------------------------------------ save / load

func save_settings() -> void:
	var config := ConfigFile.new()
	for action in _keys:
		config.set_value("keys", action, _keys[action])
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for action in _keys:
		var saved = config.get_value("keys", action, null)
		if saved is Array and saved.size() == 2:
			_keys[action] = [int(saved[0]) as Key, int(saved[1]) as Key]
	master_volume = float(config.get_value("audio", "master_volume", master_volume))
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	vsync = bool(config.get_value("display", "vsync", vsync))
