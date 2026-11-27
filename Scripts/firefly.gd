extends Node2D

# Each closed path starts at the placement point. The points on either side
# of that shared point match, giving every pattern transition the same tangent.
const PATHS = [
	[Vector2(0, 0), Vector2(0.32, 0), Vector2(0.72, -0.34), Vector2(0.30, -0.72), Vector2(-0.46, -0.58), Vector2(-0.32, 0)],
	[Vector2(0, 0), Vector2(0.32, 0), Vector2(0.55, 0.48), Vector2(-0.10, 0.75), Vector2(-0.72, 0.32), Vector2(-0.32, 0)],
	[Vector2(0, 0), Vector2(0.32, 0), Vector2(0.74, -0.12), Vector2(0.40, -0.47), Vector2(-0.42, -0.73), Vector2(-0.32, 0)],
]

## Maximum flight displacement on each axis, in local pixels.
@export_range(0.0, 1000.0, 1.0, "or_greater") var horizontal_range: float = 120.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var vertical_range: float = 75.0
## Time taken by one loop at the average speed.
@export_range(1.0, 120.0, 0.1, "or_greater") var seconds_per_loop: float = 12.0
## Gentle speed variation across the three-loop sequence.
@export_range(0.0, 0.35, 0.01) var speed_variation: float = 0.18

@onready var sprite: Sprite2D = $Sprite2D
var _phase: float = 0.0

func _process(delta: float) -> void:
	var rate := 1.0 + speed_variation * sin(_phase * TAU / 3.0)
	_phase = fposmod(_phase + delta * rate / maxf(seconds_per_loop, 1.0), 3.0)
	var pattern := int(_phase)
	var path: Array = PATHS[pattern]
	var progress := (_phase - pattern) * path.size()
	var index := int(progress)
	var point: Vector2 = path[index % path.size()].cubic_interpolate(
		path[(index + 1) % path.size()], path[(index + path.size() - 1) % path.size()], path[(index + 2) % path.size()], progress - index)
	# cubic_interpolate is called on the current point, with previous/next neighbors.
	sprite.position = Vector2(point.x * horizontal_range, point.y * vertical_range)
