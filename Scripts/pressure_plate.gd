extends Area2D

signal pressed
signal released

@export var required_crate_path: NodePath
@export var controlled_platform_path: NodePath
@export var supporting_collision_group: StringName = &""

@onready var plate_top: Polygon2D = $PlateTop

var _occupying_crates: Array[Node2D] = []
var _is_pressed := false
var _press_tween: Tween
var _required_crate: Node2D
var _controlled_platform: StaticBody2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if not required_crate_path.is_empty():
		_required_crate = get_node_or_null(required_crate_path) as Node2D
	if not controlled_platform_path.is_empty():
		_controlled_platform = get_node_or_null(controlled_platform_path) as StaticBody2D
		if _controlled_platform != null:
			_set_controlled_platform_active(false)
			pressed.connect(_on_controlled_plate_pressed)
			released.connect(_on_controlled_plate_released)
		else:
			push_warning("Pressure plate platform was not found: %s" % controlled_platform_path)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("OrbCrates"):
		return
	if not required_crate_path.is_empty() and body != _required_crate:
		return
	if not _occupying_crates.has(body):
		_occupying_crates.append(body)
	_update_pressed_state()

func _on_body_exited(body: Node2D) -> void:
	_occupying_crates.erase(body)
	_update_pressed_state()

func _on_controlled_plate_pressed() -> void:
	_set_controlled_platform_active(true)

func _on_controlled_plate_released() -> void:
	_set_controlled_platform_active(false)

func _set_controlled_platform_active(active: bool) -> void:
	if _controlled_platform == null:
		return
	_controlled_platform.visible = active
	var platform_shape := _controlled_platform.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if platform_shape != null:
		platform_shape.set_deferred("disabled", not active)
	if supporting_collision_group != &"":
		for support in get_tree().get_nodes_in_group(supporting_collision_group):
			var support_shape := support.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if support_shape != null:
				support_shape.set_deferred("disabled", not active)

func _update_pressed_state() -> void:
	for index in range(_occupying_crates.size() - 1, -1, -1):
		var crate := _occupying_crates[index]
		if not is_instance_valid(crate) or not crate.is_inside_tree():
			_occupying_crates.remove_at(index)
	var should_be_pressed := not _occupying_crates.is_empty()
	if should_be_pressed == _is_pressed:
		return
	_is_pressed = should_be_pressed
	if _is_pressed:
		pressed.emit()
	else:
		released.emit()
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()
	_press_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var target_position := Vector2(0.0, -2.0) if _is_pressed else Vector2(0.0, -5.0)
	_press_tween.tween_property(plate_top, "position", target_position, 0.12)