extends AnimatedSprite2D

## Multiplier for the one-time sequence; 1.0 plays all frames in three seconds.
@export_range(0.1, 4.0, 0.05, "or_greater") var playback_speed: float = 1.0

func _ready() -> void:
	animation_finished.connect(_on_sequence_finished)
	speed_scale = maxf(playback_speed, 0.01)
	frame = 0
	play("fly")

func _on_sequence_finished() -> void:
	hide()
	pause()
