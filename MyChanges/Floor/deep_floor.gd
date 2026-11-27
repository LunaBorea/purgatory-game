extends Node
## MyChanges: dark, deep, endless floor.
##
## Everything here happens while the game runs. No original file is edited:
## delete the MyChanges folder (or this node) and the level is exactly as before.
##
## What it does:
##  1. Hides the placeholder dark-red sky and the row of white boxes,
##     and tints the teal water so it fits the night forest.
##  2. Recolours the floor lanes to the dark colour of the background ground.
##  3. Adds a "deep" earth block under every real floor, so there is no grey void
##     under the floor. It only goes under real, solid floor, so a gap in the
##     floor still looks like a gap: you never see floor you could fall through.
##  4. Stretches the first and last floor of every lane very far left and right
##     (with real collision), so the floor is endless for now.
##  5. Puts the grass silhouette from the background on the top edge of the
##     back lane, so the level floor blends into the painted ground.

@export var level_path: NodePath = ^"../Main"

@export_group("Placeholder art")
@export var hide_placeholder_sky := true
@export var hide_white_boxes := true
@export var tint_water := true
@export var water_colors: Array[Color] = [
	Color(0.11, 0.15, 0.19),
	Color(0.085, 0.12, 0.155),
	Color(0.06, 0.09, 0.12),
	Color(0.04, 0.06, 0.085),
]

@export_group("Floor colours")
@export var recolor_floor := true
## Walkable top of each lane: [back lane, middle lane, front lane].
## Farther lanes are lighter, like things far away in fog.
@export var lane_top_colors: Array[Color] = [
	Color(0.3, 0.33, 0.4),
	Color(0.19, 0.215, 0.27),
	Color(0.1, 0.115, 0.155),
]
## Front/side faces of each lane (darker than the tops).
@export var lane_side_colors: Array[Color] = [
	Color(0.18, 0.2, 0.25),
	Color(0.11, 0.125, 0.165),
	Color(0.04, 0.05, 0.07),
]
@export var deep_bottom_color := Color(0, 0, 0)
@export var deep_depth := 750.0
@export_range(0.0, 1.0) var deep_texture_strength := 0.0

@export_group("Endless floor")
@export var extend_floor := true
## How far the floor goes on each side. 500 000 px is several minutes of walking.
@export var extension_length := 500000.0

@export_group("Grass edge")
@export var add_grass := true
@export var grass_texture: Texture2D = preload("res://MyChanges/Background/Images/07_grass.png")
## The part of the grass picture that holds the grass (x, y, width, height).
@export var grass_region := Rect2(0, 899, 7680, 150)
## Grass size per lane: [back lane, middle lane, front lane].
@export var grass_scales: Array[float] = [0.26, 0.22, 0.2]
## The grass always has exactly its lane's colour (Lane Top Colors), like a
## piece of that ground: change a lane's colour and its grass changes with it.
## How many pixels of the grass picture's bottom sink into the floor.
@export var grass_sink := 8.0
## Skip grass on pieces narrower than this (tiny ledges).
@export var grass_min_width := 40.0

@export_group("Lane highlight")
## A soft moonlit edge on the lane you are standing on.
@export var highlight_current_lane := true
@export var rim_color := Color(0.82, 0.9, 1.0)
## How far the soft light reaches down into the lane's surface.
@export var rim_glow_depth := 24.0
@export var rim_alpha_current := 0.5
@export var rim_alpha_other := 0.0

const MIN_FLOOR_WIDTH := 500.0

var _player: Node
var _rims := {}  # lane number -> Array of ColorRect
const STYLED_PREFIXES := ["Ground", "Platform", "Wall"]


func _ready() -> void:
	var level := get_node_or_null(level_path)
	if level == null:
		push_warning("MyChanges/deep_floor: level not found at %s" % level_path)
		return
	_style_placeholders(level)

	var layer_manager := level.get_node_or_null("LayerManager")
	if layer_manager == null:
		push_warning("MyChanges/deep_floor: LayerManager not found")
		return

	var index := 0
	for lane in layer_manager.get_children():
		if not lane is Node2D:
			continue
		index += 1
		var lane_number := _lane_number(String(lane.name), index)
		_style_lane(lane, lane_number)
		# Grass on top of every walkable surface of every lane (drawn over the glow).
		if add_grass:
			var grass_color := _lane_color(lane_top_colors, lane_number)
			var lane_scale: float = grass_scales[clampi(lane_number - 1, 0, grass_scales.size() - 1)]
			for top in _top_rects(lane):
				_add_grass(lane, top, grass_color, lane_scale)

	_player = get_tree().get_first_node_in_group("Player")


func _process(delta: float) -> void:
	if not highlight_current_lane or _player == null or not "current_mask" in _player:
		return
	var current: int = _player.current_mask
	var weight := 1.0 - exp(-8.0 * delta)
	for lane_number in _rims:
		var target := rim_alpha_current if lane_number == current else rim_alpha_other
		for rim in _rims[lane_number]:
			var c: Color = rim.self_modulate
			c.a = lerpf(c.a, target, weight)
			rim.self_modulate = c


## Same numbering as the game's LayerManager: Layer3 = 1 (back) ... Layer1 = 3 (front).
func _lane_number(lane_name: String, fallback: int) -> int:
	match lane_name:
		"Layer3": return 1
		"Layer2": return 2
		"Layer1": return 3
	return fallback


func _lane_color(colors: Array[Color], lane_number: int) -> Color:
	return colors[clampi(lane_number - 1, 0, colors.size() - 1)]


# ---------------------------------------------------------------- placeholders

func _style_placeholders(level: Node) -> void:
	if hide_placeholder_sky:
		var sky := level.get_node_or_null("Background") as CanvasItem
		if sky:
			sky.visible = false
	if hide_white_boxes:
		var boxes := level.get_node_or_null("WhiteBoxes") as CanvasItem
		if boxes:
			boxes.visible = false
	if tint_water:
		var names := ["ColorRect", "ColorRect2", "ColorRect3", "ColorRect4"]
		for i in names.size():
			var water := level.get_node_or_null(names[i]) as ColorRect
			if water and i < water_colors.size():
				water.color = water_colors[i]


# ---------------------------------------------------------------- lanes

## Styles one lane and returns the rectangles of its real (wide) floors,
## including the endless extensions, sorted left to right.
func _style_lane(lane: Node2D, lane_number: int) -> Array[Rect2]:
	var floors: Array[Node2D] = []
	for child in lane.get_children():
		if not child is CollisionObject2D or not _is_styled(String(child.name)):
			continue
		if recolor_floor:
			_recolor(child, lane_number)
		if String(child.name).begins_with("Ground"):
			var rect := _visual_rect(child)
			if rect.size.x >= MIN_FLOOR_WIDTH:
				floors.append(child)

	var rects: Array[Rect2] = []
	if floors.is_empty():
		return rects
	floors.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return _visual_rect(a).position.x < _visual_rect(b).position.x)

	if extend_floor:
		var left := _extend(floors[0], -1)
		var right := _extend(floors[floors.size() - 1], 1)
		floors.push_front(left)
		floors.push_back(right)

	for body in floors:
		var rect := _visual_rect(body)
		rects.append(rect)
		_add_deep_earth(lane, rect, _lane_color(lane_top_colors, lane_number))

	if highlight_current_lane:
		_add_rims(lane, lane_number)
	return rects


## The walkable top rectangle of every floor piece in the lane (world space).
func _top_rects(lane: Node2D) -> Array[Rect2]:
	var tops: Array[Rect2] = []
	for body in lane.get_children():
		if not body is CollisionObject2D or not _is_styled(String(body.name)):
			continue
		if body.has_meta("my_platform"):
			continue  # has its own painted art (Platforms/platforms.gd)
		for child in body.get_children():
			var rect := child as ColorRect
			if rect and rect.get_meta("my_face", "") == "top":
				tops.append(rect.get_global_transform() * Rect2(Vector2.ZERO, rect.size))
	return tops


## A soft moonlit glow on every walkable surface of the lane (no hard line).
func _add_rims(lane: Node2D, lane_number: int) -> void:
	var rims: Array = []
	for top in _top_rects(lane):
		var rim := TextureRect.new()
		rim.name = "MyLaneRim"
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.texture = _rim_texture()
		rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rim.stretch_mode = TextureRect.STRETCH_SCALE
		rim.position = top.position
		rim.size = Vector2(top.size.x, minf(rim_glow_depth, top.size.y))
		rim.self_modulate = Color(1, 1, 1, rim_alpha_other)
		lane.add_child(rim)
		rims.append(rim)
	_rims[lane_number] = rims


var _rim_tex: GradientTexture2D

## Soft light that is brightest at the top of the surface and fades downward.
func _rim_texture() -> GradientTexture2D:
	if _rim_tex:
		return _rim_tex
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var c := rim_color
	gradient.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.8), Color(c.r, c.g, c.b, 0.4), Color(c.r, c.g, c.b, 0.0)])
	_rim_tex = GradientTexture2D.new()
	_rim_tex.gradient = gradient
	_rim_tex.fill_to = Vector2(0, 1)
	_rim_tex.width = 4
	_rim_tex.height = 64
	return _rim_tex


func _is_styled(node_name: String) -> bool:
	for prefix in STYLED_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _recolor(body: Node, lane_number: int) -> void:
	# The highest rectangle of a floor piece is its walkable top; the others are faces.
	var top_y := INF
	for child in body.get_children():
		if child is ColorRect:
			var r: Rect2 = child.get_global_transform() * Rect2(Vector2.ZERO, child.size)
			top_y = minf(top_y, r.position.y)
	for child in body.get_children():
		var rect := child as ColorRect
		if rect == null:
			continue
		var global_rect: Rect2 = rect.get_global_transform() * Rect2(Vector2.ZERO, rect.size)
		var is_top := absf(global_rect.position.y - top_y) < 0.5
		rect.set_meta("my_face", "top" if is_top else "side")
		rect.color = _lane_color(lane_top_colors if is_top else lane_side_colors, lane_number)


## The floor's visible rectangle in world space (all its ColorRects together).
func _visual_rect(body: Node) -> Rect2:
	var result := Rect2()
	var first := true
	for child in body.get_children():
		var control := child as Control
		if control == null:
			continue
		var rect: Rect2 = control.get_global_transform() * Rect2(Vector2.ZERO, control.size)
		result = rect if first else result.merge(rect)
		first = false
	return result


## Copies a floor piece (collision included) and stretches it far to one side.
func _extend(source: Node2D, direction: int) -> Node2D:
	var source_rect := _visual_rect(source)
	var copy := source.duplicate() as Node2D
	copy.name = "%s_Endless%s" % [source.name, "Left" if direction < 0 else "Right"]
	copy.scale.x = source.scale.x * extension_length / source_rect.size.x
	source.get_parent().add_child(copy)
	copy.modulate = source.modulate
	var copy_rect := _visual_rect(copy)
	if direction < 0:
		copy.global_position.x += (source_rect.position.x + 1.0) - copy_rect.end.x
	else:
		copy.global_position.x += (source_rect.end.x - 1.0) - copy_rect.position.x
	return copy


# ---------------------------------------------------------------- decoration

func _add_deep_earth(lane: Node2D, floor_rect: Rect2, top_color: Color) -> void:
	var earth := Control.new()
	earth.name = "MyDeepEarth"
	earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	earth.position = Vector2(floor_rect.position.x, floor_rect.end.y - 1.0)
	earth.size = Vector2(floor_rect.size.x, deep_depth)

	# Starts exactly at the lane colour (no visible edge) and fades to black.
	var gradient := Gradient.new()
	gradient.set_color(0, top_color)
	gradient.set_color(1, deep_bottom_color)
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(0, 1)
	gradient_texture.width = 4
	gradient_texture.height = 256

	var fill := TextureRect.new()
	fill.texture = gradient_texture
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size = earth.size
	earth.add_child(fill)

	if deep_texture_strength > 0.0:
		_add_blotches(earth)

	lane.add_child(earth)
	lane.move_child(earth, 0)  # behind everything else in this lane


## Optional soil texture (off by default: deep_texture_strength = 0).
func _add_blotches(earth: Control) -> void:
	# Faint blotches so the earth looks like soil and rock, not flat paint.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var noise_texture := NoiseTexture2D.new()
	noise_texture.noise = noise
	noise_texture.seamless = true
	noise_texture.width = 512
	noise_texture.height = 512
	var blotches := TextureRect.new()
	blotches.texture = noise_texture
	blotches.stretch_mode = TextureRect.STRETCH_TILE
	blotches.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	blotches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blotches.modulate = Color(0.75, 0.82, 1.0, deep_texture_strength)
	# Line the pattern up with the world so neighbouring floor pieces join without a seam.
	var shift := fposmod(earth.position.x, float(noise_texture.width))
	blotches.position = Vector2(-shift, 0)
	blotches.size = earth.size + Vector2(shift, 0)
	earth.clip_contents = true
	earth.add_child(blotches)


func _add_grass(lane: Node2D, floor_rect: Rect2, color: Color, grass_scale: float) -> void:
	if floor_rect.size.x < grass_min_width:
		return
	var grass := Sprite2D.new()
	grass.name = "MyGrassEdge"
	grass.texture = grass_texture
	grass.centered = false
	grass.region_enabled = true
	grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Start each piece at a different spot of the picture so the grass never looks copied.
	var start_x := fposmod(floor_rect.position.x * 3.7, grass_region.size.x)
	grass.region_rect = Rect2(
		Vector2(start_x, grass_region.position.y),
		Vector2(floor_rect.size.x / grass_scale, grass_region.size.y))
	grass.scale = Vector2(grass_scale, grass_scale)
	grass.position = Vector2(
		floor_rect.position.x,
		floor_rect.position.y - (grass_region.size.y - grass_sink) * grass_scale)
	var material := ShaderMaterial.new()
	material.shader = preload("res://MyChanges/Background/crisp_edges.gdshader")
	material.set_shader_parameter("sharpness", 0.0)  # keep the smooth painted blades
	material.set_shader_parameter("recolor", true)
	material.set_shader_parameter("color", color)
	grass.material = material
	lane.add_child(grass)
