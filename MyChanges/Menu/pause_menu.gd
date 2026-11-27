extends CanvasLayer
## MyChanges: the pause menu (autoload "PauseMenu").
##
## Press Esc (or Start on a gamepad) during the game: the game pauses, the picture
## behind goes soft and a little darker, and the PURGATORY menu appears.
##   PLAY      back to the game
##   SETTINGS  keys (2 per action), volume, fullscreen, V-Sync (saved automatically)
##   CREDITS   the names in "Credits Text" (edit it in the Inspector of pause_menu.tscn)
##   QUIT      asks first, then closes the game
## Esc goes one page back; on the first page it returns to the game.

@export var art: Texture2D = preload("res://MyChanges/Menu/menu_art.png")
## Parts of menu_art.png (x, y, width, height).
@export var title_region := Rect2(170, 240, 930, 250)
@export var play_region := Rect2(395, 515, 465, 65)
@export var settings_region := Rect2(432, 643, 390, 64)
@export var credits_region := Rect2(456, 766, 342, 64)
@export var quit_region := Rect2(508, 884, 240, 66)
## The star line under the title, reused as a divider on the other pages.
@export var divider_region := Rect2(262, 418, 730, 66)
@export var title_scale := 0.72
@export var button_scale := 0.8
## Lines starting with "#" are headings.
@export_multiline var credits_text := "# A GAME BY\nLunaBorea\nneopolen\nElena-novia\nEkaterinaZakharova-13\n\n# MADE WITH\nGodot Engine"

const FONT_NAMES := ["Cinzel", "Trajan Pro", "Optima", "Baskerville", "Times New Roman"]
const DIM := Color(1, 1, 1, 0.62)
const BRIGHT := Color(1, 1, 1, 1)

var is_open := false

var _root: Control
var _blur: ColorRect
var _pages := {}
var _current_page := ""
var _first_focus := {}
var _font: FontVariation
var _font_wide: FontVariation
var _tween: Tween
var _return_focus: Control

var _tab_pages := {}
var _tab_buttons := {}
var _key_buttons := {}   # [action, slot] -> Button
var _waiting: Array = []  # [action, slot] while waiting for a key
var _hint: Label
var _volume_slider: HSlider
var _fullscreen_button: Button
var _vsync_button: Button


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_fonts()
	_build()
	_root.visible = false


# ================================================================== open / close

func _input(event: InputEvent) -> void:
	if not _waiting.is_empty():
		_capture_key(event)
		return
	var pause_pressed: bool = event.is_action_pressed("pause") \
			or (event is InputEventKey and event.pressed and not event.echo
				and event.physical_keycode == KEY_ESCAPE)
	if not is_open:
		if pause_pressed:
			open()
			get_viewport().set_input_as_handled()
		return
	if pause_pressed or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _current_page == "main":
			close()
		else:
			_show_page("main")


func open() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_show_page("main", false)
	_animate(1.0, 0.28)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_animate(0.0, 0.2)
	# Unpause after the fade, so the key that closed the menu doesn't also make the player jump.
	_tween.tween_callback(func() -> void:
		_root.visible = false
		get_tree().paused = false)


func _animate(to: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var material := _blur.material as ShaderMaterial
	_tween.tween_method(func(v: float) -> void: material.set_shader_parameter("amount", v),
		material.get_shader_parameter("amount"), to, time)
	_tween.tween_property(_pages_holder(), "modulate:a", to, time)
	_tween.set_parallel(false)


func _pages_holder() -> Control:
	return _root.get_node("Pages")


func _show_page(page_name: String, fade := true) -> void:
	_waiting = []
	# Remember which main button opened the page, so "back" lands on it again.
	var focused := _root.get_viewport().gui_get_focus_owner()
	if _current_page == "main" and page_name != "main" and focused and _pages["main"].is_ancestor_of(focused):
		_return_focus = focused
	var target: Control = _first_focus.get(page_name)
	if page_name == "main" and _current_page != "main" and is_instance_valid(_return_focus):
		target = _return_focus
	for key in _pages:
		_pages[key].visible = key == page_name
	_current_page = page_name
	var page: Control = _pages[page_name]
	if fade:
		page.modulate.a = 0.0
		create_tween().tween_property(page, "modulate:a", 1.0, 0.18)
	if target:
		target.grab_focus.call_deferred()


# ================================================================== building

func _make_fonts() -> void:
	var system := SystemFont.new()
	system.font_names = PackedStringArray(FONT_NAMES)
	system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font = FontVariation.new()
	_font.base_font = system
	_font.spacing_glyph = 3
	_font_wide = FontVariation.new()
	_font_wide.base_font = system
	_font_wide.spacing_glyph = 9


func _build() -> void:
	_root = Control.new()
	_root.name = "Menu"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	_blur = ColorRect.new()
	_blur.name = "Blur"
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://MyChanges/Menu/menu_blur.gdshader")
	material.set_shader_parameter("amount", 0.0)
	_blur.material = material
	_root.add_child(_blur)

	var pages := CenterContainer.new()
	pages.name = "Pages"
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(pages)

	_pages["main"] = _build_main()
	_pages["settings"] = _build_settings()
	_pages["credits"] = _build_credits()
	_pages["quit"] = _build_quit()
	for key in _pages:
		pages.add_child(_pages[key])


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 26
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		theme.set_stylebox(state, "Button", empty)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", BRIGHT if state != "font_color" else DIM)
	theme.set_color("font_color", "Label", DIM)

	# Thin slider in the same style as the lines under the buttons.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.25)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(1, 1, 1, 0.85)
	filled.content_margin_top = 1
	filled.content_margin_bottom = 1
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	# A soft frame around the slider when it is chosen with the keyboard.
	var slider_focus := StyleBoxFlat.new()
	slider_focus.bg_color = Color(1, 1, 1, 0.05)
	slider_focus.border_color = Color(1, 1, 1, 0.5)
	slider_focus.set_border_width_all(1)
	slider_focus.set_corner_radius_all(6)
	slider_focus.set_expand_margin_all(8)
	theme.set_stylebox("focus", "HSlider", slider_focus)
	var dot := _circle_texture(18, Color(1, 1, 1, 0.9))
	theme.set_icon("grabber", "HSlider", dot)
	theme.set_icon("grabber_highlight", "HSlider", _circle_texture(22, BRIGHT))
	return theme


func _circle_texture(size: int, color: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			image.set_pixel(x, y, Color(color, color.a * clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = art
	texture.region = region
	return texture


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 18)
	return page


## A button made from a part of the menu picture (PLAY, SETTINGS ...).
func _art_button(region: Rect2, on_press: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = region.size * button_scale
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var picture := TextureRect.new()
	picture.texture = _atlas(region)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.modulate = DIM
	button.add_child(picture)
	_add_hover(button, picture)
	button.pressed.connect(on_press)
	return button


## A text button with a fading line under it, in the style of the menu picture.
func _text_button(text: String, font_size: int, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", _font_wide)
	button.add_theme_font_size_override("font_size", font_size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(0, font_size * 1.9)
	var line := _line()
	line.anchor_left = -0.12
	line.anchor_right = 1.12
	line.anchor_top = 1.0
	line.anchor_bottom = 1.0
	line.offset_top = -4
	line.offset_bottom = -2
	line.modulate = Color(1, 1, 1, 0.45)
	button.add_child(line)
	_add_hover(button, line)
	button.pressed.connect(on_press)
	return button


func _line() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 2
	var line := TextureRect.new()
	line.texture = texture
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _divider() -> TextureRect:
	var divider := TextureRect.new()
	divider.texture = _atlas(divider_region)
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	divider.custom_minimum_size = divider_region.size * 0.75
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _heading(text: String, font_size := 58) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font_wide)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", BRIGHT)
	return label


func _label(text: String, font_size := 24, color := DIM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Mouse over = keyboard focus, so mouse, keyboard and gamepad all look the same.
func _add_hover(button: Button, glow: CanvasItem) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(button.grab_focus)
	var dim_alpha := glow.modulate.a
	button.focus_entered.connect(func() -> void:
		button.pivot_offset = button.size * 0.5
		var t := create_tween().set_parallel(true)
		t.tween_property(glow, "modulate:a", 1.0, 0.15)
		t.tween_property(button, "scale", Vector2.ONE * 1.04, 0.15))
	button.focus_exited.connect(func() -> void:
		var t := create_tween().set_parallel(true)
		t.tween_property(glow, "modulate:a", dim_alpha, 0.2)
		t.tween_property(button, "scale", Vector2.ONE, 0.2))


# ------------------------------------------------------------------ pages

func _build_main() -> Control:
	var page := _page()
	page.add_theme_constant_override("separation", 26)
	var title := TextureRect.new()
	title.texture = _atlas(title_region)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = title_region.size * title_scale
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	page.add_child(gap)
	var play := _art_button(play_region, close)
	var buttons: Array[Control] = [
		play,
		_art_button(settings_region, func() -> void: _show_page("settings")),
		_art_button(credits_region, func() -> void: _show_page("credits")),
		_art_button(quit_region, func() -> void: _show_page("quit")),
	]
	for button in buttons:
		page.add_child(button)
	_link_vertical(buttons)
	_first_focus["main"] = play
	var hint := _label("↑ ↓  or  W S   choose      Enter   select      Esc   back", 18, Color(1, 1, 1, 0.38))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(hint)
	return page


## Up / down moves through these in order and wraps around (bottom -> top).
func _link_vertical(controls: Array[Control]) -> void:
	for i in controls.size():
		var previous := controls[(i - 1 + controls.size()) % controls.size()]
		var next := controls[(i + 1) % controls.size()]
		controls[i].focus_neighbor_top = controls[i].get_path_to(previous)
		controls[i].focus_neighbor_bottom = controls[i].get_path_to(next)


func _build_settings() -> Control:
	var page := _page()
	page.custom_minimum_size = Vector2(980, 0)
	page.add_child(_heading("SETTINGS"))
	page.add_child(_divider())

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 64)
	page.add_child(tabs)

	var holder := MarginContainer.new()
	holder.custom_minimum_size = Vector2(980, 520)
	holder.add_theme_constant_override("margin_top", 16)
	page.add_child(holder)

	var contents := {
		"controls": _build_controls(),
		"audio": _build_audio(),
		"display": _build_display(),
	}
	for key in contents:
		var tab := _text_button(String(key).to_upper(), 26, _select_tab.bind(key))
		tabs.add_child(tab)
		# With keys: ← → along the tabs switches the page right away.
		tab.focus_entered.connect(_select_tab.bind(key))
		_tab_buttons[key] = tab
		holder.add_child(contents[key])
		_tab_pages[key] = contents[key]

	# ← → / A D always move along the tabs (and wrap around).
	var tab_list: Array = _tab_buttons.values()
	for i in tab_list.size():
		var tab: Button = tab_list[i]
		tab.focus_neighbor_left = tab.get_path_to(tab_list[(i - 1 + tab_list.size()) % tab_list.size()])
		tab.focus_neighbor_right = tab.get_path_to(tab_list[(i + 1) % tab_list.size()])

	var back := _text_button("BACK", 28, func() -> void: _show_page("main"))
	page.add_child(back)
	_first_focus["settings"] = _tab_buttons["controls"]
	_select_tab("controls")
	return page


func _select_tab(key: String) -> void:
	_waiting = []
	for k in _tab_pages:
		_tab_pages[k].visible = k == key
		var tab: Button = _tab_buttons[k]
		tab.add_theme_color_override("font_color", BRIGHT if k == key else DIM)


func _build_controls() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	grid.add_child(_label("ACTION", 18, Color(1, 1, 1, 0.4)))
	grid.add_child(_label("KEY", 18, Color(1, 1, 1, 0.4)))
	grid.add_child(_label("SECOND KEY", 18, Color(1, 1, 1, 0.4)))

	for entry in GameSettings.ACTIONS:
		var label := _label(String(entry.label).to_upper(), 22)
		label.custom_minimum_size = Vector2(300, 0)
		grid.add_child(label)
		for slot in 2:
			var button := _key_button(entry.action, slot)
			grid.add_child(button)
			_key_buttons[[entry.action, slot]] = button

	_hint = _label("Choose a key and press Enter (or click) to change it", 18, Color(1, 1, 1, 0.45))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
	box.add_child(_text_button("RESET KEYS", 20, func() -> void:
		GameSettings.reset_keys()
		_hint.text = "Keys are back to default"))
	GameSettings.changed.connect(_refresh_keys)
	_refresh_keys()
	return box


func _key_button(action: String, slot: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(190, 40)
	button.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.0)
	normal.border_color = Color(1, 1, 1, 0.3)
	normal.border_width_bottom = 1
	var active := normal.duplicate() as StyleBoxFlat
	active.bg_color = Color(1, 1, 1, 0.07)
	active.border_color = Color(1, 1, 1, 0.95)
	button.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "focus", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, active)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(button.grab_focus)
	button.pressed.connect(func() -> void:
		_waiting = [action, slot]
		button.text = "press a key…"
		_hint.text = "Press the new key for %s   ·   Esc = cancel   ·   Delete = empty" \
				% GameSettings.label_for(action).to_upper())
	return button


func _refresh_keys() -> void:
	for id in _key_buttons:
		var button: Button = _key_buttons[id]
		button.text = GameSettings.key_name(GameSettings.get_key(id[0], id[1]))


func _capture_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		if event is InputEventMouseButton and event.pressed:
			_cancel_capture()  # clicking somewhere else cancels
		return
	get_viewport().set_input_as_handled()
	var action: String = _waiting[0]
	var slot: int = _waiting[1]
	var keycode: Key = (event as InputEventKey).physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if keycode == KEY_ESCAPE:
		_cancel_capture()
		return
	_waiting = []
	if keycode == KEY_DELETE or keycode == KEY_BACKSPACE:
		keycode = KEY_NONE
	var taken_from := GameSettings.set_key(action, slot, keycode)
	_hint.text = "Saved" if taken_from == "" else "Saved (removed from %s)" % taken_from.to_upper()
	_refresh_keys()
	(_key_buttons[[action, slot]] as Button).grab_focus()


func _cancel_capture() -> void:
	_waiting = []
	_hint.text = "Choose a key and press Enter (or click) to change it"
	_refresh_keys()


func _build_audio() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	box.add_child(row)
	var label := _label("MASTER VOLUME", 22)
	label.custom_minimum_size = Vector2(300, 0)
	row.add_child(label)
	_volume_slider = HSlider.new()
	_volume_slider.custom_minimum_size = Vector2(380, 30)
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = GameSettings.master_volume
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_volume_slider)
	var value_label := _label("%d%%" % roundi(GameSettings.master_volume * 100.0), 22)
	value_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(value_label)
	_volume_slider.value_changed.connect(func(v: float) -> void:
		GameSettings.set_master_volume(v)
		value_label.text = "%d%%" % roundi(v * 100.0))
	_volume_slider.mouse_entered.connect(_volume_slider.grab_focus)
	return box


func _build_display() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_fullscreen_button = _toggle_row(box, "FULLSCREEN", func() -> void:
		GameSettings.set_fullscreen(not GameSettings.fullscreen)
		_refresh_toggles())
	_vsync_button = _toggle_row(box, "V-SYNC", func() -> void:
		GameSettings.set_vsync(not GameSettings.vsync)
		_refresh_toggles())
	_refresh_toggles()
	return box


func _toggle_row(parent: Control, text: String, on_press: Callable) -> Button:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	parent.add_child(row)
	var label := _label(text, 22)
	label.custom_minimum_size = Vector2(300, 0)
	row.add_child(label)
	var button := _text_button("", 22, on_press)
	button.custom_minimum_size = Vector2(190, 44)
	row.add_child(button)
	return button


func _refresh_toggles() -> void:
	_fullscreen_button.text = "ON" if GameSettings.fullscreen else "OFF"
	_vsync_button.text = "ON" if GameSettings.vsync else "OFF"


func _build_credits() -> Control:
	var page := _page()
	page.add_child(_heading("CREDITS"))
	page.add_child(_divider())
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	page.add_child(lines)
	for line in credits_text.split("\n"):
		var text := line.strip_edges()
		if text.begins_with("#"):
			var heading := _label(text.trim_prefix("#").strip_edges(), 20, Color(1, 1, 1, 0.45))
			heading.add_theme_font_override("font", _font_wide)
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lines.add_child(heading)
		else:
			var name_label := _label(text, 30, BRIGHT)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lines.add_child(name_label)
	var back := _text_button("BACK", 28, func() -> void: _show_page("main"))
	page.add_child(back)
	_first_focus["credits"] = back
	return page


func _build_quit() -> Control:
	var page := _page()
	page.add_child(_heading("QUIT"))
	page.add_child(_divider())
	var question := _label("Leave Purgatory?", 30, BRIGHT)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(question)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 90)
	page.add_child(row)
	var stay := _text_button("NO", 28, func() -> void: _show_page("main"))
	row.add_child(_text_button("YES", 28, func() -> void: get_tree().quit()))
	row.add_child(stay)
	_first_focus["quit"] = stay
	return page
