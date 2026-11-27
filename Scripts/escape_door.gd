extends Node2D

@export var platform_path: NodePath
@export_range(0.2, 6.0, 0.1) var open_duration := 5.0

var gate_tween: Tween
var is_open := false
var close_pending := false
var gate_visuals: Array[Node2D] = []
var gate_blockers: Array[AnimatableBody2D] = []
var blocker_collisions: Array[CollisionShape2D] = []
var blocker_closed_scales: Array[Vector2] = []

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("EscapeGateVisuals"):
		var visual := node as Node2D
		if visual != null:
			gate_visuals.append(visual)
	for node in get_tree().get_nodes_in_group("EscapeGateBlockers"):
		var blocker := node as AnimatableBody2D
		if blocker == null:
			continue
		var shape := blocker.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null:
			continue
		gate_blockers.append(blocker)
		blocker_collisions.append(shape)
		blocker_closed_scales.append(blocker.scale)
		shape.set_deferred("disabled", false)

	var platform := get_node_or_null(platform_path)
	if platform != null:
		if platform.has_signal("orb_placed"):
			platform.connect("orb_placed", Callable(self, "open_gate"))
		if platform.has_signal("orb_recalled"):
			platform.connect("orb_recalled", Callable(self, "close_gate"))
	close_gate()

func _process(_delta: float) -> void:
	if close_pending and not _player_is_in_gate_clearance():
		_close_gate_now()

func open_gate() -> void:
	close_pending = false
	is_open = true
	if gate_tween and gate_tween.is_running():
		gate_tween.kill()
	for shape in blocker_collisions:
		shape.set_deferred("disabled", false)

	gate_tween = create_tween()
	gate_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	gate_tween.set_parallel(true)
	for visual in gate_visuals:
		gate_tween.tween_property(visual, "scale", Vector2(1, 0), open_duration)
	for index in range(gate_blockers.size()):
		var closed_scale: Vector2 = blocker_closed_scales[index]
		var opening_scale := Vector2(closed_scale.x, closed_scale.y * 0.02)
		gate_tween.tween_property(gate_blockers[index], "scale", opening_scale, open_duration)
	gate_tween.set_parallel(false)
	gate_tween.tween_callback(Callable(self, "_finish_open"))

func close_gate() -> void:
	if _player_is_in_gate_clearance():
		close_pending = true
		return
	_close_gate_now()

func _close_gate_now() -> void:
	close_pending = false
	is_open = false
	if gate_tween and gate_tween.is_running():
		gate_tween.kill()
	for visual in gate_visuals:
		visual.scale = Vector2.ONE
	for index in range(gate_blockers.size()):
		gate_blockers[index].scale = blocker_closed_scales[index]
		blocker_collisions[index].set_deferred("disabled", false)

func _player_is_in_gate_clearance() -> bool:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return false
	var offset := player.global_position - global_position
	return absf(offset.x) <= 68.0 and offset.y >= -140.0 and offset.y <= 35.0

func _finish_open() -> void:
	if not is_open:
		return
	for visual in gate_visuals:
		visual.scale = Vector2(1, 0)
	for shape in blocker_collisions:
		shape.set_deferred("disabled", true)