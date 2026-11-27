extends RigidBody2D

const DEPTH_Z_STRIDE := 1024

@export_range(1, 3, 1) var current_layer := 2
@export var match_player_layer_on_interact := false
@export var push_force := 1450.0
@export var max_push_speed := 150.0
@export var idle_braking_strength := 1300.0
@export var stopping_velocity_threshold := 2.0
@export_range(0.1, 1.0, 0.05) var stored_orb_scale := 0.5

@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var orb_anchor: Marker2D = $OrbAnchor
@onready var interaction_area: Area2D = $InteractionArea
@onready var player: Node = get_tree().get_first_node_in_group("Player")
@onready var layer_manager: Node = get_tree().get_first_node_in_group("LayerManager")

var nearby_players: Array[Node2D] = []
var placed_orb: Node2D
var _orb_has_arrived := false
var _push_force_received := false
var _layer_rest_y := 0.0

func _ready() -> void:
	add_to_group("OrbCrates")
	gravity_scale = 0.0
	lock_rotation = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	mass = 3.0
	linear_damp = 1.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	z_as_relative = false
	# Keep the F-key interaction range the same when an individual crate is scaled.
	interaction_area.global_scale = Vector2.ONE
	_layer_rest_y = global_position.y
	_apply_layer(current_layer)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if player == null or layer_manager == null:
		return
	var player_layer := int(player.get("current_mask"))
	var layer_distance: int = absi(current_layer - player_layer)
	var saturation := float(layer_distance) / 10.0
	var target_tint := Color.from_hsv(float(layer_manager.get("ambient_color")), saturation, 1.0 - saturation, 1.0)
	modulate = modulate.lerp(target_tint, 1.0 - exp(-10.0 * delta))

func can_be_pushed() -> bool:
	return (
		_orb_has_arrived
		and is_instance_valid(placed_orb)
		and bool(placed_orb.get("is_placed"))
		and placed_orb.get("placed_platform") == self
	)

func receive_push(direction: float, pushing_layer: int, pusher_y: float) -> void:
	if pushing_layer != current_layer or pusher_y > global_position.y + 24.0 or not can_be_pushed() or not is_equal_approx(absf(direction), 1.0):
		return
	apply_central_force(Vector2(direction * push_force, 0.0))
	_push_force_received = true

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var body_velocity := state.linear_velocity
	body_velocity.x = clampf(body_velocity.x, -max_push_speed, max_push_speed)
	if not _push_force_received:
		body_velocity.x = move_toward(body_velocity.x, 0.0, idle_braking_strength * state.step)
		if absf(body_velocity.x) <= stopping_velocity_threshold:
			body_velocity.x = 0.0
	body_velocity.y = 0.0
	var rest_transform := state.transform
	rest_transform.origin.y = _layer_rest_y
	state.transform = rest_transform
	_push_force_received = false
	state.linear_velocity = body_velocity

func interact(by_player: Node2D, orb: Node2D) -> bool:
	if not _player_is_in_interaction_range(by_player) or by_player.global_position.y > global_position.y + 24.0:
		return false
	if placed_orb != null or not bool(orb.get("is_active")):
		return false
	if bool(orb.get("is_placing")) or bool(orb.get("is_placed")) or bool(orb.get("is_recalling")):
		return false
	var player_layer := int(by_player.get("current_mask"))
	if current_layer != player_layer:
		if not match_player_layer_on_interact:
			return false
		_apply_layer(player_layer)
	placed_orb = orb
	orb.call("place_on", orb_anchor, self, Vector2.ONE * stored_orb_scale)
	orb.global_position = orb_anchor.global_position
	return true

func _player_is_in_interaction_range(candidate: Node2D) -> bool:
	var shape_node := interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return nearby_players.has(candidate)
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		return nearby_players.has(candidate)
	var area_scale := interaction_area.global_scale
	var radius := circle.radius * maxf(absf(area_scale.x), absf(area_scale.y))
	return interaction_area.global_position.distance_squared_to(candidate.global_position) <= radius * radius

func on_orb_arrived(orb: Node2D) -> void:
	if placed_orb == orb:
		_orb_has_arrived = true
		freeze = false

func release_orb(orb: Node2D) -> void:
	if placed_orb != orb:
		return
	placed_orb = null
	_orb_has_arrived = false
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_push_force_received = false
	if is_instance_valid(orb):
		orb.call("recall_from_platform", self)

func can_shift_with_player(target_layer: int, vertical_offset: float) -> bool:
	if placed_orb == null or target_layer < 1 or target_layer > 3:
		return false
	if target_layer == current_layer:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_shape.shape
	query.transform = body_shape.global_transform.translated(Vector2(0.0, vertical_offset))
	query.collision_mask = 1 << (target_layer - 1)
	query.margin = 0.0
	query.exclude = [get_rid()]
	var player_body := get_tree().get_first_node_in_group("Player") as CollisionObject2D
	if player_body != null:
		query.exclude.append(player_body.get_rid())
	return get_world_2d().direct_space_state.intersect_shape(query, 8).is_empty()

func move_with_player(target_layer: int, vertical_offset: float) -> void:
	if placed_orb == null or target_layer < 1 or target_layer > 3:
		return
	global_position.y += vertical_offset
	_layer_rest_y = global_position.y
	linear_velocity = Vector2.ZERO
	_push_force_received = false
	_apply_layer(target_layer)
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)

func _apply_layer(layer_number: int) -> void:
	current_layer = layer_number
	var layer_bit := 1 << (current_layer - 1)
	collision_layer = layer_bit
	collision_mask = layer_bit | 1
	z_index = clampi(current_layer * DEPTH_Z_STRIDE + roundi(global_position.y + 16.0), -4096, 4096)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and not nearby_players.has(body):
		nearby_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	nearby_players.erase(body)
