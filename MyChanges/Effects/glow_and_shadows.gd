extends Node
## MyChanges: soft glow around the character and the orb, and soft shadows on
## the ground under the character, the orb and the hunters.
##
## Shadows are soft dark ovals on the floor right below each one. When you jump,
## the shadow stays on the ground and gets smaller and fainter the higher you are.

@export_group("Glow")
@export var player_glow_color := Color(0.8, 0.88, 1.0)
@export var player_glow_size := 150.0
@export var player_glow_strength := 0.32
@export var player_glow_offset := Vector2(0, -20)
@export var orb_glow_color := Color(1.0, 0.8, 0.52)
@export var orb_glow_size := 210.0
@export var orb_glow_strength := 0.55
## How much the glow breathes in and out (0 = steady).
@export var glow_pulse := 0.15

@export_group("Shadows")
@export var shadow_strength := 0.6
@export var player_shadow_size := Vector2(58, 13)
@export var orb_shadow_size := Vector2(40, 9)
@export var hunter_shadow_size := Vector2(110, 20)
## Height (px) at which a shadow has shrunk and faded the most.
@export var fade_height := 260.0

var _player: Node2D
var _orb: Node2D
var _player_glow: Sprite2D
var _orb_glow: Sprite2D
var _player_shadow: Sprite2D
var _orb_shadow: Sprite2D
var _time := 0.0
var _glow_texture: Texture2D
var _shadow_texture: Texture2D


func _ready() -> void:
	_glow_texture = _radial(Color(1, 1, 1, 1), [0.0, 0.25, 0.6, 1.0], [1.0, 0.45, 0.1, 0.0])
	_shadow_texture = _radial(Color(0, 0, 0, 1), [0.0, 0.45, 1.0], [1.0, 0.6, 0.0])
	# Wait one frame so the level has finished setting itself up.
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _player:
		_player_glow = _add_glow(_player, player_glow_color, player_glow_size, player_glow_offset)
		_player_shadow = _add_floating_shadow(player_shadow_size)
		_orb = _player.get_node_or_null("Orb") as Node2D
		if _orb:
			_orb_glow = _add_glow(_orb, orb_glow_color, orb_glow_size, Vector2.ZERO)
			_orb_shadow = _add_floating_shadow(orb_shadow_size)
	for node in get_tree().root.find_children("*", "Node2D", true, false):
		if node.scene_file_path == "res://Scenes/Entities/the_hunter.tscn":
			_add_hunter_shadow(node)


func _process(delta: float) -> void:
	_time += delta
	var pulse := 1.0 - glow_pulse + glow_pulse * sin(_time * 1.7)
	if is_instance_valid(_player_glow):
		_player_glow.modulate.a = player_glow_strength * pulse
	if is_instance_valid(_orb_glow):
		_orb_glow.modulate.a = orb_glow_strength * (1.0 - glow_pulse + glow_pulse * sin(_time * 2.3 + 1.0))


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var mask: int = _player.get("collision_mask") if "collision_mask" in _player else 0xFFFF
	_place_shadow(_player_shadow, _player.global_position, mask, player_shadow_size, _player.z_index - 1)
	if is_instance_valid(_orb) and _orb.visible:
		_place_shadow(_orb_shadow, _orb.global_position, mask, orb_shadow_size, _player.z_index - 2)
	elif _orb_shadow:
		_orb_shadow.visible = false


## Puts a shadow on the ground straight below `from`.
func _place_shadow(shadow: Sprite2D, from: Vector2, mask: int, size: Vector2, z: int) -> void:
	if shadow == null:
		return
	var space := _player.get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	if _player is CollisionObject2D:
		exclude.append((_player as CollisionObject2D).get_rid())
	var query := PhysicsRayQueryParameters2D.create(from + Vector2(0, -6), from + Vector2(0, 900), mask, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		shadow.visible = false
		return
	var height := maxf(0.0, hit.position.y - from.y)
	var t := clampf(height / fade_height, 0.0, 1.0)
	shadow.visible = true
	shadow.global_position = hit.position
	shadow.scale = size * lerpf(1.0, 0.45, t) / _shadow_texture.get_size()
	shadow.modulate.a = shadow_strength * lerpf(1.0, 0.15, t)
	shadow.z_index = z


func _add_floating_shadow(size: Vector2) -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.name = "MyShadow"
	shadow.texture = _shadow_texture
	shadow.top_level = true
	shadow.z_as_relative = false
	shadow.scale = size / _shadow_texture.get_size()
	shadow.visible = false
	add_child(shadow)
	return shadow


func _add_hunter_shadow(hunter: Node2D) -> void:
	var shadow := Sprite2D.new()
	shadow.name = "MyShadow"
	shadow.texture = _shadow_texture
	shadow.scale = hunter_shadow_size / _shadow_texture.get_size() / hunter.global_scale.abs()
	shadow.modulate.a = shadow_strength
	hunter.add_child(shadow)
	hunter.move_child(shadow, 0)  # behind the hunter's sprite


func _add_glow(target: Node2D, color: Color, size: float, offset: Vector2) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.name = "MyGlow"
	glow.texture = _glow_texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.self_modulate = color
	var parent_scale := target.global_scale.abs()
	glow.scale = Vector2(size, size) / _glow_texture.get_size() / parent_scale
	glow.position = offset / parent_scale
	target.add_child(glow)
	target.move_child(glow, 0)  # behind the sprite
	return glow


func _radial(color: Color, offsets: Array, alphas: Array) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	var colors := PackedColorArray()
	for a in alphas:
		colors.append(Color(color.r, color.g, color.b, a))
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
