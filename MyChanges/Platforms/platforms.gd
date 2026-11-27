extends Node
## MyChanges: painted platforms instead of the grey placeholder boxes.
##
## RULE: what you see is exactly what you can stand on.
##  - Every solid platform of every lane gets a picture, also the invisible "support"
##    floors the level uses. A gap in a lane looks like a gap.
##  - The picture is exactly as wide as the solid part, so you never stand on air or
##    fall through an edge you can see.
##  - When a platform is switched off (pressure plate, orb ...) its picture disappears,
##    and it comes back when the platform is switched on again.
##  - Platforms of the lane you are on are bright; the other lanes fade back a little,
##    so you can tell which islands are yours.
##
## Pictures:
##  - platforms up in the air  -> the small floating island (floating_island.png)
##  - platforms in the water   -> the island with roots (water_island.png), standing halfway
##    in the water; the part under the water line is faint and blue.
## Collision is never changed.
##
## This node must come BEFORE DeepFloor in main_with_forest.tscn (DeepFloor skips these pieces).

@export var level_path: NodePath = ^"../Main"

@export_group("Pictures")
@export var floating_texture: Texture2D = preload("res://MyChanges/Platforms/floating_island.png")
## In the floating picture: x of the middle of the body and y of the walkable top (picture pixels).
@export var floating_surface := Vector2(248, 86)
@export var floating_body_width := 197.0
@export var water_texture: Texture2D = preload("res://MyChanges/Platforms/water_island.png")
@export var water_surface := Vector2(245, 56)
@export var water_body_width := 420.0
@export var water_body_height := 154.0

@export_group("Size")
## Picture body width compared to the solid platform. 1 = exactly as wide (no standing on air).
@export var overhang := 1.0
## All platforms get about the same height, the height a platform this wide would have,
## so wide and narrow platforms look like they belong together.
@export var reference_width := 80.0
## Pieces wider than this are real floors, not platforms.
@export var max_platform_width := 400.0
## Bodies whose name starts with one of these have their own art and are left alone.
@export var skip_names: PackedStringArray = ["OrbPlatform", "EscapeGate"]

@export_group("Water")
## Where the water line sits on a water platform: 0 = at the top, 1 = at the bottom.
@export_range(0.0, 1.0) var water_line := 0.45
@export_range(0.0, 1.0) var underwater_visibility := 0.35
@export var water_color := Color(0.085, 0.12, 0.17)

@export_group("Colours")
## Per lane [back, middle, front]: picture brightness and how much it fades into the night fog.
## Same idea as the floor lanes: far lanes are lighter and foggier.
@export var lane_tints: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.92, 0.94, 1.0), Color(0.72, 0.75, 0.82)]
@export var lane_fog: Array[float] = [0.4, 0.12, 0.0]
@export var fog_color := Color(0.3, 0.34, 0.42)
## Soft moonlight on the top of the platforms of the lane you are standing on.
@export var highlight_current_lane := true
## How visible platforms of the OTHER lanes are (1 = same as yours).
@export_range(0.0, 1.0) var other_lane_opacity := 0.55

const SHADER := preload("res://MyChanges/Platforms/platform.gdshader")

var _water_area := Rect2()
## One entry per picture: {sprite, material, lane, body, shapes}
var _platforms: Array[Dictionary] = []
var _player: Node


func _ready() -> void:
	var level := get_node_or_null(level_path)
	if level == null:
		return
	_water_area = _find_water(level)
	var layer_manager := level.get_node_or_null("LayerManager")
	if layer_manager == null:
		return
	for lane in layer_manager.get_children():
		var lane_number := _lane_number(String(lane.name))
		if lane_number == 0:
			continue
		# Visible pieces (with grey boxes) first, then the invisible support floors,
		# so a support right under a visible piece doesn't get a second picture.
		var bodies := lane.get_children()
		bodies.sort_custom(func(a: Node, b: Node) -> bool:
			return _has_faces(a) and not _has_faces(b))
		for body in bodies:
			_style(body, lane_number)
		# Platforms that are added later in the game.
		lane.child_entered_tree.connect(func(node: Node) -> void:
			_style.call_deferred(node, lane_number))
	_player = get_tree().get_first_node_in_group("Player")


func _process(delta: float) -> void:
	var current := -1
	if _player != null and "current_mask" in _player:
		current = _player.current_mask
	var weight := 1.0 - exp(-8.0 * delta)
	for platform in _platforms:
		var sprite: Sprite2D = platform.sprite
		if not is_instance_valid(sprite):
			continue
		# Only show the picture while the platform is really solid.
		sprite.visible = _is_solid(platform.shapes)
		var material: ShaderMaterial = platform.material
		var mine: bool = platform.lane == current
		var glow: float = material.get_shader_parameter("highlight")
		var glow_target := 1.0 if (mine and highlight_current_lane) else 0.0
		material.set_shader_parameter("highlight", lerpf(glow, glow_target, weight))
		var opacity := 1.0 if (mine or current == -1) else other_lane_opacity
		sprite.self_modulate.a = lerpf(sprite.self_modulate.a, opacity, weight)


func _lane_number(lane_name: String) -> int:
	match lane_name:
		"Layer3": return 1
		"Layer2": return 2
		"Layer1": return 3
	return 0


func _find_water(level: Node) -> Rect2:
	var area := Rect2()
	var found := false
	for water_name in ["ColorRect", "ColorRect2", "ColorRect3", "ColorRect4"]:
		var water := level.get_node_or_null(NodePath(water_name)) as Control
		if water:
			var rect: Rect2 = water.get_global_transform() * Rect2(Vector2.ZERO, water.size)
			area = rect if not found else area.merge(rect)
			found = true
	return area


func _has_faces(body: Node) -> bool:
	for child in body.get_children():
		if child is ColorRect:
			return true
	return false


func _shapes(body: Node) -> Array[CollisionShape2D]:
	var shapes: Array[CollisionShape2D] = []
	for child in body.get_children():
		if child is CollisionShape2D and child.shape != null:
			shapes.append(child)
	return shapes


func _is_solid(shapes: Array) -> bool:
	for shape in shapes:
		if is_instance_valid(shape) and not shape.disabled:
			return true
	return false


## The solid area of a body in world space (all its collision shapes together).
func _solid_rect(shapes: Array[CollisionShape2D]) -> Rect2:
	var rect := Rect2()
	for i in shapes.size():
		var r: Rect2 = shapes[i].global_transform * shapes[i].shape.get_rect()
		rect = r if i == 0 else rect.merge(r)
	return rect


func _already_drawn(lane_number: int, rect: Rect2) -> bool:
	for platform in _platforms:
		if platform.lane != lane_number:
			continue
		var other: Rect2 = platform.rect
		var overlap := minf(rect.end.x, other.end.x) - maxf(rect.position.x, other.position.x)
		if overlap > minf(rect.size.x, other.size.x) * 0.5 and absf(rect.position.y - other.position.y) < 8.0:
			return true
	return false


func _style(body: Node, lane_number: int) -> void:
	if not is_instance_valid(body) or not body is StaticBody2D or body is AnimatableBody2D:
		return
	if body.has_meta("my_platform"):
		return
	for prefix in skip_names:
		if String(body.name).begins_with(prefix):
			return
	var shapes := _shapes(body)
	if shapes.is_empty():
		return
	var rect := _solid_rect(shapes)
	if rect.size.x > max_platform_width or rect.size.x < 8.0:
		return

	# Hide the grey placeholder boxes.
	for child in body.get_children():
		if child is ColorRect:
			child.visible = false
	var center_x := rect.get_center().x
	var in_water := _water_area.has_area() \
			and center_x > _water_area.position.x and center_x < _water_area.end.x \
			and rect.position.y > _water_area.position.y - 60.0
	body.set_meta("my_platform", "water" if in_water else "floating")
	if _already_drawn(lane_number, rect):
		return  # a support right under a visible piece: that piece's picture already shows it

	var texture := water_texture if in_water else floating_texture
	var surface := water_surface if in_water else floating_surface
	var body_width := water_body_width if in_water else floating_body_width
	var width_scale := rect.size.x * overhang / body_width
	var reference_scale := reference_width * overhang / body_width
	var height_scale := sqrt(width_scale * reference_scale)

	var sprite := Sprite2D.new()
	sprite.name = "MyPlatformArt"
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -surface
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.add_child(sprite)
	# The grass roots sink 2 px into the top so you stand on the grass, not above it.
	var top := Vector2(center_x, rect.position.y + 2.0)
	sprite.global_transform = Transform2D(0.0, Vector2(width_scale, height_scale), 0.0, top)

	var lane := clampi(lane_number - 1, 0, 2)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", lane_tints[lane])
	material.set_shader_parameter("fog", lane_fog[lane])
	material.set_shader_parameter("fog_color", fog_color)
	material.set_shader_parameter("surface_y", rect.position.y)
	material.set_shader_parameter("in_water", in_water)
	material.set_shader_parameter("water_y", rect.position.y + water_line * water_body_height * height_scale)
	material.set_shader_parameter("water_color", water_color)
	material.set_shader_parameter("underwater_visibility", underwater_visibility)
	material.set_shader_parameter("highlight", 0.0)
	sprite.material = material
	sprite.visible = _is_solid(shapes)
	_platforms.append({
		"sprite": sprite, "material": material, "lane": lane_number,
		"rect": rect, "shapes": shapes,
	})
