extends Node
## MyChanges: small tweaks to the team's new background art, without editing their files.
##  - Watching trees: darker, so they sit in the night forest like the other trees.
##    The eyes keep glowing. (Uses MyChanges/Effects/watching_tree_dark.gdshader.)
##  - Crows: wings flap a little faster, which looks more natural.
## Works for trees/crows placed in the level and for ones added later.

@export_group("Watching trees")
@export var darken_trees := true
## Multiplied onto the tree's colours (not the eyes). Lower = darker.
@export var tree_tint := Color(0.5, 0.55, 0.68)
## How much the trees fade into the night mist, like the trees behind them.
@export_range(0.0, 1.0) var tree_mist := 0.12
@export var mist_color := Color(0.16, 0.19, 0.25)

@export_group("Crows")
## 1 = the original speed. 1.3 = 30 % faster wing beats.
@export_range(0.5, 3.0, 0.05) var crow_wing_speed := 1.3

@export_group("Fireflies")
## The team's fireflies blink like real ones (same rhythm settings as the background swarm).
@export var blink_fireflies := true
@export var firefly_color := Color(1.0, 0.86, 0.36)
@export var blink_every_min := 5.0
@export var blink_every_max := 11.0
@export var flash_length := 1.3

const FIREFLY_SCENE := "res://Scenes/Entities/firefly.tscn"
const Swarm := preload("res://MyChanges/Background/firefly_swarm.gd")
var _fireflies: Array[Dictionary] = []
var _time := 0.0

const TREE_SCENE := "res://Scenes/Entities/watching_tree.tscn"
const CROW_SCENE := "res://Scenes/Entities/crow.tscn"
const CROW_PASS_SCENE := "res://Scenes/Entities/crow_pass.tscn"
const DARK_TREE_SHADER := preload("res://MyChanges/Effects/watching_tree_dark.gdshader")


func _ready() -> void:
	# Wait one frame: the trees and crows set themselves up in their own _ready first.
	await get_tree().process_frame
	for node in get_tree().root.find_children("*", "", true, false):
		_tweak(node)
	get_tree().node_added.connect(func(node: Node) -> void: _tweak.call_deferred(node))


func _tweak(node: Node) -> void:
	if not is_instance_valid(node) or node.has_meta("my_tweaked"):
		return
	match node.scene_file_path:
		TREE_SCENE:
			if darken_trees:
				_darken_tree(node as CanvasItem)
		CROW_SCENE:
			node.set("wing_frames_per_second", float(node.get("wing_frames_per_second")) * crow_wing_speed)
		FIREFLY_SCENE:
			var sprite := node.get_node_or_null("Sprite2D") as CanvasItem
			if blink_fireflies and sprite:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(node.get_path())
				var period := rng.randf_range(blink_every_min, blink_every_max)
				sprite.self_modulate = Color(firefly_color, 0.0)
				_fireflies.append({
					"sprite": sprite, "period": period,
					"offset": rng.randf_range(0.0, period), "double": rng.randf() < 0.3,
				})
		CROW_PASS_SCENE:
			var sprite := node as AnimatedSprite2D
			if sprite:
				sprite.speed_scale *= crow_wing_speed
		_:
			return
	node.set_meta("my_tweaked", true)


func _process(delta: float) -> void:
	_time += delta
	for firefly in _fireflies:
		var sprite: CanvasItem = firefly.sprite
		if not is_instance_valid(sprite):
			continue
		var light := Swarm.flash(_time + firefly.offset, firefly.period, flash_length, firefly.double)
		sprite.self_modulate.a = light


func _darken_tree(tree: CanvasItem) -> void:
	var material := tree.material as ShaderMaterial
	if material == null:
		return
	# Same material the tree already animates (frame, blend, eye settings stay), new shader.
	material.shader = DARK_TREE_SHADER
	material.set_shader_parameter("body_tint", Vector3(tree_tint.r, tree_tint.g, tree_tint.b))
	material.set_shader_parameter("mist_color", mist_color)
	material.set_shader_parameter("mist", tree_mist)
