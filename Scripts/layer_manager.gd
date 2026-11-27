extends Node2D

const DEPTH_Z_STRIDE := 1024

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var current_layer = player.current_mask
@onready var layer_size = get_children().size()
@export_range(0, 1, 0.01) var ambient_color := 0.0

func _ready():
	var i := 1
	for layer in get_children():
		var layer_number := _collision_layer_for_name(String(layer.name), i)
		layer.z_index = layer_number * DEPTH_Z_STRIDE
		layer.z_as_relative = false
		for node in layer.get_children():
			var distance: int = absi(layer_number - player.current_mask)
			var canvas_item := node as CanvasItem
			if canvas_item != null:
				canvas_item.modulate = Color.from_hsv(ambient_color, float(distance) / 10.0, 1.0 - (float(distance) / 10.0), 1.0)
				if node is Node2D:
					canvas_item.z_as_relative = true
					if node.is_in_group("LayerCollider") or node.is_in_group("OrbPlatforms"):
						canvas_item.z_index = roundi(_depth_y(node as Node2D))
					else:
						# Keep floors and walls behind characters; only tall props need y-sorting.
						canvas_item.z_index = 0
			if node is CollisionObject2D:
				node.collision_layer = 0
				node.set_collision_layer_value(layer_number, true)
		i += 1

func _collision_layer_for_name(layer_name: String, fallback: int) -> int:
	match layer_name:
		"Layer3": return 1
		"Layer2": return 2
		"Layer1": return 3
		_: return fallback

func _depth_y(node: Node2D) -> float:
	var collision_shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return node.global_position.y
	var local_bounds := collision_shape.shape.get_rect()
	var shape_transform := collision_shape.global_transform
	var corners := [
		local_bounds.position,
		Vector2(local_bounds.end.x, local_bounds.position.y),
		Vector2(local_bounds.position.x, local_bounds.end.y),
		local_bounds.end
	]
	var depth_y := -INF
	for corner in corners:
		depth_y = maxf(depth_y, (shape_transform * corner).y)
	return depth_y

var color_transitioning := false

func _process(delta):
	if not player:
		return
	if current_layer != player.current_mask:
		current_layer = player.current_mask
		color_transitioning = true
	if color_transitioning:
		var finished := true
		var i = 1 # Increments
		for layer in get_children():
			for node in layer.get_children():
				var layer_number := _collision_layer_for_name(String(layer.name), i)
				var distance: int = absi(layer_number - player.current_mask)
				var target_color = Color.from_hsv(ambient_color, float(distance) / 10.0, 1.0 - (float(distance) / 10.0), 1.0)
				var weight = 1.0 - exp(-10.0 * delta)
				var canvas_item := node as CanvasItem
				if canvas_item == null:
					continue
				canvas_item.modulate = canvas_item.modulate.lerp(target_color, weight)
				if canvas_item.modulate != target_color:
					finished = false
				else:
					canvas_item.modulate = target_color
			i += 1
		if finished:
			color_transitioning = false