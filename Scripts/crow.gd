extends Node2D

## Horizontal speed in world units per second, towards the left.
@export_range(0.0, 500.0, 1.0, "or_greater") var flight_speed: float = 55.0
## Number of sheet frames shown per second.
@export_range(0.1, 30.0, 0.1, "or_greater") var wing_frames_per_second: float = 8.0
## Maximum vertical offset in local units; zero disables the body movement.
@export_range(0.0, 5.0, 0.05) var body_motion: float = 0.6

@onready var sprite: Sprite2D = $Sprite2D
var _phase: float = 0.0

func _process(delta: float) -> void:
	position.x -= flight_speed * delta
	_phase = fposmod(_phase + wing_frames_per_second * delta, 12.0)
	sprite.frame = int(_phase)
	# Frames 0 and 11 have raised wings; frames 5 to 7 have lowered wings.
	sprite.position.y = body_motion * cos(TAU * _phase / 12.0)
