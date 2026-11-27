extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("respawn_at_start"):
		body.call_deferred("respawn_at_start")
