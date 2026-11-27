extends Node2D

@export var follow_smoothing := 7.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var follow_target: Marker2D = get_parent().get_node("OrbAnchor")
@onready var point_light: PointLight2D = $PointLight2D
@onready var dismiss_glow: Sprite2D = $DismissGlow
@onready var white_dust: GPUParticles2D = $WhiteDust
@onready var dust_material: ParticleProcessMaterial = white_dust.process_material as ParticleProcessMaterial

var is_active := false
var is_placing := false
var is_placed := false
var is_recalling := false
var placed_platform: Node2D
var placed_anchor: Marker2D
var hide_after_glow := false
var dismiss_tween: Tween
var default_scale := Vector2.ONE

func _ready() -> void:
	default_scale = scale
	global_position = follow_target.global_position
	visible = false
	white_dust.emitting = false
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	if not is_active:
		return

	var player := get_parent() as CharacterBody2D
	if player == null:
		return

	var target := follow_target
	if (is_placing or is_placed) and is_instance_valid(placed_anchor):
		target = placed_anchor

	var to_target := target.global_position - global_position
	var weight := 1.0 - exp(-follow_smoothing * delta)
	if is_placed:
		global_position = target.global_position
	else:
		global_position = global_position.lerp(target.global_position, weight)
	var orb_z_index := player.z_index + 1
	if (is_placing or is_placed) and is_instance_valid(placed_platform) and placed_platform.is_in_group("OrbCrates"):
		orb_z_index = int(placed_platform.get("z_index")) + 1
	z_index = orb_z_index

	if is_placing:
		if to_target.length_squared() > 0.01:
			var trail_direction := -to_target.normalized()
			dust_material.direction = Vector3(trail_direction.x, trail_direction.y, 0.0)
		white_dust.emitting = true
		if global_position.distance_to(target.global_position) <= 5.0:
			global_position = target.global_position
			is_placing = false
			is_placed = true
			white_dust.emitting = false
			if is_instance_valid(placed_platform):
				placed_platform.call("on_orb_arrived", self)
	elif is_recalling:
		white_dust.emitting = false
		if global_position.distance_to(target.global_position) <= 8.0:
			global_position = target.global_position
			is_recalling = false
	else:
		white_dust.emitting = false

func place_on(anchor: Marker2D, platform: Node2D, scale_multiplier: Vector2 = Vector2.ONE) -> void:
	if not is_active or is_placing or is_placed or is_recalling:
		return
	is_placing = true
	placed_anchor = anchor
	placed_platform = platform
	scale = default_scale * scale_multiplier

func recall_from_platform(platform: Node2D) -> void:
	if placed_platform != platform:
		return
	is_placing = false
	is_placed = false
	is_recalling = true
	placed_anchor = null
	placed_platform = null
	scale = default_scale
	white_dust.emitting = false

func call_back() -> void:
	if is_placing or is_placed:
		if is_instance_valid(placed_platform):
			placed_platform.call("release_orb", self)

func toggle() -> void:
	if is_placing or is_placed or is_recalling:
		return
	if is_active:
		is_active = false
		animated_sprite.stop()
		animated_sprite.visible = false
		point_light.enabled = false
		_play_toggle_glow(true)
	else:
		is_active = true
		visible = true
		animated_sprite.visible = true
		point_light.enabled = true
		animated_sprite.play(&"Activate")
		animated_sprite.set_frame_and_progress(0, 0.0)
		_play_toggle_glow(false)

func _play_toggle_glow(hide_after: bool) -> void:
	if dismiss_tween and dismiss_tween.is_running():
		dismiss_tween.kill()
	hide_after_glow = hide_after
	dismiss_glow.visible = true
	dismiss_glow.modulate = Color(1, 1, 1, 0.82)
	dismiss_glow.scale = Vector2(0.65, 0.65)
	dismiss_tween = create_tween().set_parallel(true)
	dismiss_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	dismiss_tween.tween_property(dismiss_glow, "modulate:a", 0.0, 0.42)
	dismiss_tween.tween_property(dismiss_glow, "scale", Vector2(2.35, 2.35), 0.42)
	dismiss_tween.chain().tween_callback(_finish_toggle_glow)

func _finish_toggle_glow() -> void:
	dismiss_glow.visible = false
	if hide_after_glow and not is_active:
		visible = false

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"Activate" and is_active:
		animated_sprite.play(&"Idle")
