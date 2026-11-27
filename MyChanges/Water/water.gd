extends Node2D
## MyChanges: animated water in the pit.
##
## Finds the old teal water rectangles of the level, hides them and puts the
## animated water (Water/Frames) in the same place instead. The water picture
## repeats sideways, so it fills the pit at any width, and below the picture
## the water gets darker and darker into the deep.

@export var level_path: NodePath = ^"../Main"
@export var old_water_names: PackedStringArray = ["ColorRect", "ColorRect2", "ColorRect3", "ColorRect4"]
@export var frames_per_second := 8.0
## Size of the water picture in the world (1 = 512 x 160 px).
@export var picture_scale := 1.0
## Row of the picture where the wave line is (the part above it is transparent).
@export var wave_line_row := 18.0
@export var deep_color := Color(0.0275, 0.0392, 0.0627)
@export var depth := 1400.0
@export var show_reflection := true
@export_range(0.0, 1.0) var reflection_strength := 0.3
## How far down the reflection reaches before it fades out.
@export var reflection_depth := 380.0

var _frames: Array[Texture2D] = []
var _sprite: Sprite2D
var _time := 0.0


func _ready() -> void:
	for i in 100:
		var path := "res://MyChanges/Water/Frames/water_%02d.png" % i
		if not ResourceLoader.exists(path):
			break
		_frames.append(load(path))
	var level := get_node_or_null(level_path)
	if level == null or _frames.is_empty():
		return

	var area := Rect2()
	var found := false
	for water_name in old_water_names:
		var old := level.get_node_or_null(NodePath(water_name)) as Control
		if old == null:
			continue
		var rect: Rect2 = old.get_global_transform() * Rect2(Vector2.ZERO, old.size)
		area = rect if not found else area.merge(rect)
		found = true
		old.visible = false
	if not found:
		return

	var size := _frames[0].get_size() * picture_scale
	_sprite = Sprite2D.new()
	_sprite.texture = _frames[0]
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_rect = Rect2(0, 0, area.size.x / picture_scale, _frames[0].get_height())
	_sprite.scale = Vector2(picture_scale, picture_scale)
	_sprite.position = Vector2(area.position.x, area.position.y - wave_line_row * picture_scale)
	add_child(_sprite)

	# Deep water under the picture: from the picture's bottom colour to black.
	var gradient := Gradient.new()
	gradient.set_color(0, deep_color)
	gradient.set_color(1, Color(0, 0, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 256
	var deep := TextureRect.new()
	deep.texture = texture
	deep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	deep.stretch_mode = TextureRect.STRETCH_SCALE
	deep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deep.position = Vector2(area.position.x, _sprite.position.y + size.y - 1.0)
	deep.size = Vector2(area.size.x, depth)
	add_child(deep)

	# Reflection of the forest on the water surface.
	if show_reflection:
		var reflection := ColorRect.new()
		reflection.name = "Reflection"
		reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reflection.light_mask = 0
		reflection.position = Vector2(area.position.x, area.position.y)
		reflection.size = Vector2(area.size.x, reflection_depth)
		var reflection_material := ShaderMaterial.new()
		reflection_material.shader = preload("res://MyChanges/Water/water_reflection.gdshader")
		reflection_material.set_shader_parameter("strength", reflection_strength)
		reflection.material = reflection_material
		add_child(reflection)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_time += delta
	_sprite.texture = _frames[int(_time * frames_per_second) % _frames.size()]
