extends StaticBody2D

signal orb_placed
signal orb_recalled

const GROUND10_SCENE: PackedScene = preload("res://Scenes/Entities/ground_10.tscn")

@export_range(1, 3, 1) var current_layer := 1
@export_range(0.1, 1.0, 0.05) var stored_orb_scale := 0.5
@export var ground_parent_path: NodePath
@export var ground_position := Vector2(1828.8, 584.0)
@export_range(1, 3, 1) var ground_collision_layer := 3

@onready var interaction_area: Area2D = $InteractionArea
@onready var visuals: Node2D = $Visuals
@onready var orb_anchor: Marker2D = $OrbAnchor

var nearby_players: Array[Node2D] = []
var placed_orb: Node2D
var brightness_tween: Tween
var ground_parent: Node2D
var ground_instance: StaticBody2D

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	if not ground_parent_path.is_empty():
		ground_parent = get_node_or_null(ground_parent_path) as Node2D

func is_player_in_range(player: Node2D) -> bool:
	return nearby_players.has(player)

func interact(player: Node2D, orb: Node2D) -> bool:
	if not is_player_in_range(player):
		return false
	if int(player.get("current_mask")) != current_layer:
		return false
	if placed_orb != null:
		return false
	if not bool(orb.get("is_active")) or bool(orb.get("is_placing")) or bool(orb.get("is_placed")) or bool(orb.get("is_recalling")):
		return false

	placed_orb = orb
	orb.call("place_on", orb_anchor, self, Vector2.ONE * stored_orb_scale)
	return true

func on_orb_arrived(orb: Node2D) -> void:
	if placed_orb == orb:
		_set_occupied(true)
		_spawn_ground10()
		orb_placed.emit()

func release_orb(orb: Node2D) -> void:
	if placed_orb != orb:
		return

	placed_orb = null
	_set_occupied(false)
	_set_ground10_active(false)
	orb_recalled.emit()
	if is_instance_valid(orb):
		orb.call("recall_from_platform", self)

func _spawn_ground10() -> void:
	if ground_parent == null:
		return
	if is_instance_valid(ground_instance):
		_set_ground10_active(true)
		return
	ground_instance = GROUND10_SCENE.instantiate() as StaticBody2D
	if ground_instance == null:
		return
	ground_instance.position = ground_position
	ground_instance.collision_layer = 1 << (ground_collision_layer - 1)
	ground_instance.collision_mask = 1
	ground_parent.add_child(ground_instance)
	_set_ground10_active(true)

func _set_ground10_active(active: bool) -> void:
	if is_instance_valid(ground_instance):
		ground_instance.visible = active
		var collision_shape := ground_instance.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape != null:
			collision_shape.set_deferred("disabled", not active)
	_set_ground10_support_collisions(active)

func _set_ground10_support_collisions(active: bool) -> void:
	for support in get_tree().get_nodes_in_group("Ground10Support"):
		var collision_shape := support.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape != null:
			collision_shape.set_deferred("disabled", not active)
func _set_occupied(occupied: bool) -> void:
	if brightness_tween and brightness_tween.is_running():
		brightness_tween.kill()
	brightness_tween = create_tween()
	brightness_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var target_color := Color(1.14, 1.08, 0.94, 1.0) if occupied else Color.WHITE
	brightness_tween.tween_property(visuals, "modulate", target_color, 0.22)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and not nearby_players.has(body):
		nearby_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	nearby_players.erase(body)
