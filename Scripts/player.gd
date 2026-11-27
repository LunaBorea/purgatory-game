extends CharacterBody2D

signal damaged_percent(percent: float)

const ANIM_IDLE: StringName = &"Idle"
const ANIM_WALKING: StringName = &"Walking"
const ANIM_WALKING_TO_IDLE: StringName = &"Walking-To-Idle"
const ANIM_JUMPING: StringName = &"Jumping"
const ANIM_JUMPING_TO_LAND: StringName = &"Jumping-To-Land"
const DEPTH_Z_STRIDE := 1024

@onready var further_check: Area2D = $FurtherCheck
@onready var closer_check: Area2D = $CloserCheck
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var orb: Node2D = $Orb
@onready var orb_anchor: Marker2D = $OrbAnchor
@onready var walking_dust: GPUParticles2D = $WalkingDust
@onready var walking_dust_material: ParticleProcessMaterial = walking_dust.process_material as ParticleProcessMaterial
@onready var dash_petals: GPUParticles2D = $DashPetals
@onready var dash_petals_material: ParticleProcessMaterial = dash_petals.process_material as ParticleProcessMaterial
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var layer_manager := get_tree().get_first_node_in_group("LayerManager")

@export_group("Movement")
@export var max_speed: float = 220.0
@export var acceleration: float = 1800.0
@export_range(0.0, 1.0) var ground_friction: float = 0.45
@export var ground_braking: float = 3000.0
@export var stop_threshold: float = 5.0

@export_group("Dash")
@export_range(1.0, 2.5, 0.05) var dash_speed_multiplier: float = 2.0
@export_range(0.1, 2.0, 0.1) var dash_duration: float = 0.5
@export_range(0.1, 10.0, 0.1) var dash_cooldown: float = 3.0
@export var dash_tint := Color(1.8, 1.6, 1.3, 1.0)
@export_range(0.02, 0.2, 0.01) var dash_afterimage_interval := 0.07
@export_range(0.05, 0.5, 0.01) var dash_afterimage_lifetime := 0.22
@export var dash_afterimage_tint := Color(0.86, 0.94, 1.0, 0.42)

@export_group("Jump")
@export var coyote_time: float = 0.125
@export var jump_buffer_time: float = 0.125
@export var jump_strength: float = 600.0
@export var gravity: float = 1800.0
@export var jump_cut_multiplier: float = 0.45

@export_group("Damage recoil")
@export_range(0.0, 1.0, 0.05) var damage_recoil_duration := 0.18
@export var damage_recoil_horizontal_speed := 145.0
@export var damage_recoil_bounce_speed := 95.0

var last_grounded_time := -INF
var last_jump_pressed_time := -INF
var dash_duration_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_afterimage_timer := 0.0
var dash_direction := 1
var damage_recoil_remaining := 0.0
var current_damage_recoil_strength := 1.0
var original_sprite_modulate := Color.WHITE

var starting_mask: int = 2
var starting_position := Vector2.ZERO
var current_mask := starting_mask

var last_direction := 1

func take_damage_percent(percent: float, source_position: Vector2 = Vector2.INF, recoil_multiplier: float = 1.0) -> void:
	if percent <= 0.0 or is_invulnerable():
		return
	damaged_percent.emit(percent)
	var recoil_strength := clampf(recoil_multiplier, 0.0, 1.0)
	var knockback_direction := signf(global_position.x - source_position.x) if source_position != Vector2.INF else -float(last_direction)
	if is_zero_approx(knockback_direction):
		knockback_direction = -float(last_direction)
	current_damage_recoil_strength = recoil_strength
	velocity.x = knockback_direction * damage_recoil_horizontal_speed * recoil_strength
	velocity.y = minf(velocity.y, -damage_recoil_bounce_speed * recoil_strength)
	damage_recoil_remaining = damage_recoil_duration * recoil_strength

func is_invulnerable() -> bool:
	return dash_duration_remaining > 0.0

func _ready():
	starting_position = global_position
	original_sprite_modulate = animated_sprite.modulate
	walking_dust.emitting = false
	_update_z_index()
	var idle_first_frame := animated_sprite.sprite_frames.get_frame_texture(ANIM_IDLE, 0)
	animated_sprite.sprite_frames.set_frame(ANIM_IDLE, 0, idle_first_frame, 10.0)
	_play_animation(ANIM_IDLE)
	collision_mask = 0
	set_collision_mask_value(starting_mask, true)
	
	further_check.collision_mask = 0
	further_check.set_collision_mask_value(starting_mask-1, 1)
	closer_check.collision_mask = 0
	closer_check.set_collision_mask_value(starting_mask+1, 1)

func respawn_at_start() -> void:
	if orb.is_placing or orb.is_placed:
		orb.call_back()
	global_position = starting_position
	velocity = Vector2.ZERO
	current_mask = starting_mask
	collision_mask = 0
	set_collision_mask_value(starting_mask, true)
	further_check.collision_mask = 0
	if current_mask > 1:
		further_check.set_collision_mask_value(current_mask - 1, true)
	closer_check.collision_mask = 0
	if current_mask < layer_manager.layer_size:
		closer_check.set_collision_mask_value(current_mask + 1, true)
	dash_duration_remaining = 0.0
	dash_afterimage_timer = 0.0
	animated_sprite.modulate = original_sprite_modulate
	walking_dust.emitting = false
	last_grounded_time = -INF
	last_jump_pressed_time = -INF
	_update_z_index()
	_play_animation(ANIM_IDLE)

func _physics_process(delta: float) -> void:
	dash_duration_remaining = maxf(0.0, dash_duration_remaining - delta)
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	damage_recoil_remaining = maxf(0.0, damage_recoil_remaining - delta)
	if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0.0:
		dash_duration_remaining = dash_duration
		dash_cooldown_remaining = dash_cooldown
		dash_direction = last_direction
		damage_recoil_remaining = 0.0
		_emit_dash_petals()
	animated_sprite.modulate = dash_tint if dash_duration_remaining > 0.0 else original_sprite_modulate
	if Input.is_action_just_pressed("orb_toggle"):
		orb.toggle()
	if Input.is_action_just_pressed("orb_platform"):
		_interact_with_orb_holder()
	if Input.is_action_just_pressed("further"):
		_move_further()

	if Input.is_action_just_pressed("closer"):
		_move_closer()
	
	var now := Time.get_ticks_msec() / 1000.0
	var was_on_floor := is_on_floor()

	if was_on_floor:
		last_grounded_time = now

	if Input.is_action_just_pressed("jump"):
		last_jump_pressed_time = now

	var direction := Input.get_axis("left", "right")
	var movement_max_speed := max_speed * (dash_speed_multiplier if dash_duration_remaining > 0.0 else 1.0)
	
	if not was_on_floor:
		velocity.y += gravity * delta

	if dash_duration_remaining > 0.0:
		velocity.x = dash_direction * max_speed * dash_speed_multiplier
	elif damage_recoil_remaining > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, damage_recoil_horizontal_speed * 0.55 * current_damage_recoil_strength * delta)
	elif direction != 0.0:
		var reversing_on_ground := (
			was_on_floor
			and velocity.x != 0.0
			and signf(velocity.x) != signf(direction)
		)

		if reversing_on_ground:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				ground_braking * delta
			)
		else:
			velocity.x = move_toward(
				velocity.x,
				direction * movement_max_speed,
				acceleration * delta
			)

		last_direction = signi(int(direction))

	elif was_on_floor:
		velocity.x *= ground_friction
		if absf(velocity.x) < stop_threshold:
			velocity.x = 0.0

	animated_sprite.flip_h = last_direction < 0
	orb_anchor.position.x = -absf(orb_anchor.position.x) * last_direction

	var jump_is_buffered := now - last_jump_pressed_time <= jump_buffer_time
	var can_coyote_jump := now - last_grounded_time <= coyote_time
	var jump_started := false

	if jump_is_buffered and can_coyote_jump:
		velocity.y = -jump_strength
		last_grounded_time = -INF
		last_jump_pressed_time = -INF
		jump_started = true
		
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	move_and_slide()
	_try_push_orb_crate(direction)
	_update_z_index()
	var on_floor_after_move := is_on_floor()
	_update_walking_dust(direction, on_floor_after_move)

	if dash_duration_remaining > 0.0:
		_play_animation(ANIM_WALKING)
	elif jump_started or not on_floor_after_move:
		_play_animation(ANIM_JUMPING)
	elif not was_on_floor:
		_play_animation(ANIM_JUMPING_TO_LAND)
	elif animated_sprite.animation == ANIM_JUMPING_TO_LAND and animation_player.is_playing():
		pass
	elif direction != 0.0:
		_play_animation(ANIM_WALKING)
	elif animated_sprite.animation == ANIM_WALKING:
		_play_animation(ANIM_WALKING_TO_IDLE)
	elif animated_sprite.animation != ANIM_WALKING_TO_IDLE and animated_sprite.animation != ANIM_JUMPING_TO_LAND:
		_play_animation(ANIM_IDLE)
	_update_dash_afterimage(delta)

func _update_walking_dust(direction: float, on_floor: bool) -> void:
	var is_walking := on_floor and velocity.x * direction > stop_threshold
	walking_dust.emitting = is_walking
	if is_walking:
		walking_dust_material.direction = Vector3(-signf(direction), -0.08, 0.0)

func _update_dash_afterimage(delta: float) -> void:
	if dash_duration_remaining <= 0.0:
		dash_afterimage_timer = 0.0
		return

	dash_afterimage_timer -= delta
	if dash_afterimage_timer > 0.0:
		return
	dash_afterimage_timer = dash_afterimage_interval
	_spawn_dash_afterimage()

func _emit_dash_petals() -> void:
	dash_petals.position.x = -float(dash_direction) * 16.0
	dash_petals_material.direction = Vector3(-float(dash_direction), -0.25, 0.0)
	dash_petals.restart()
	dash_petals.emitting = true

func _spawn_dash_afterimage() -> void:
	var ghost_parent := get_tree().current_scene
	if ghost_parent == null:
		ghost_parent = get_parent()
	if ghost_parent == null:
		return

	var afterimage := AnimatedSprite2D.new()
	afterimage.sprite_frames = animated_sprite.sprite_frames
	afterimage.animation = animated_sprite.animation
	afterimage.frame = animated_sprite.frame
	afterimage.frame_progress = animated_sprite.frame_progress
	afterimage.flip_h = animated_sprite.flip_h
	afterimage.centered = animated_sprite.centered
	afterimage.offset = animated_sprite.offset
	afterimage.texture_filter = animated_sprite.texture_filter
	afterimage.modulate = dash_afterimage_tint
	afterimage.z_as_relative = false
	afterimage.z_index = z_index - 1
	ghost_parent.add_child(afterimage)
	afterimage.global_transform = animated_sprite.global_transform

	var faded_color := dash_afterimage_tint
	faded_color.a = 0.0
	var fade_tween := afterimage.create_tween()
	fade_tween.tween_property(afterimage, "modulate", faded_color, dash_afterimage_lifetime)
	fade_tween.finished.connect(afterimage.queue_free)

func _on_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		ANIM_WALKING_TO_IDLE:
			_play_animation(ANIM_IDLE)
		ANIM_JUMPING_TO_LAND:
			if not is_on_floor():
				_play_animation(ANIM_JUMPING)
			elif Input.get_axis("left", "right") != 0.0:
				_play_animation(ANIM_WALKING)
			else:
				_play_animation(ANIM_IDLE)

func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	animation_player.play(animation_name)

func _update_z_index() -> void:
	# Match the active layer's z band, then sort by the player's feet.
	z_index = clampi(current_mask * DEPTH_Z_STRIDE + roundi(global_position.y), -4096, 4096)
func _move_further() -> void:
	if current_mask <= 1 or has_overlapping_group_body("LayerCollider", further_check):
		return
	var target_layer := current_mask - 1
	var carried_crate := _get_carried_orb_crate()
	collision_mask = 0
	global_position.y -= 32.0
	set_collision_mask_value(target_layer, true)
	current_mask = target_layer
	further_check.collision_mask = 0
	if current_mask > 1:
		further_check.set_collision_mask_value(current_mask - 1, true)
	closer_check.collision_mask = 0
	if current_mask < layer_manager.layer_size:
		closer_check.set_collision_mask_value(current_mask + 1, true)
	_update_z_index()
	if carried_crate != null:
		carried_crate.call("move_with_player", current_mask, -32.0)

func _move_closer() -> void:
	if current_mask >= layer_manager.layer_size or _is_standing_on_layer_locked_platform() or has_overlapping_group_body("LayerCollider", closer_check):
		return
	var target_layer := current_mask + 1
	var carried_crate := _get_carried_orb_crate()
	collision_mask = 0
	global_position.y += 32.0
	set_collision_mask_value(target_layer, true)
	current_mask = target_layer
	further_check.collision_mask = 0
	if current_mask > 1:
		further_check.set_collision_mask_value(current_mask - 1, true)
	closer_check.collision_mask = 0
	if current_mask < layer_manager.layer_size:
		closer_check.set_collision_mask_value(current_mask + 1, true)
	_update_z_index()
	if carried_crate != null:
		carried_crate.call("move_with_player", current_mask, 32.0)

func _is_standing_on_layer_locked_platform() -> bool:
	if not is_on_floor():
		return false
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if collision.get_normal().y > -0.5:
			continue
		var floor_body := collision.get_collider() as Node
		if floor_body != null and floor_body.is_in_group("LayerDownLocked"):
			return true
	return false

func _try_push_orb_crate(direction: float) -> void:
	if is_zero_approx(direction):
		return
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		var crate := collision.get_collider() as RigidBody2D
		if crate == null or not crate.is_in_group("OrbCrates"):
			continue
		if collision.get_normal().x * direction < -0.5:
			crate.call("receive_push", signf(direction), current_mask, global_position.y)

func _get_carried_orb_crate() -> Node2D:
	if not bool(orb.get("is_placed")) and not bool(orb.get("is_placing")):
		return null
	var receiver := orb.get("placed_platform") as Node2D
	if receiver != null and receiver.is_in_group("OrbCrates"):
		return receiver
	return null

func has_overlapping_group_body(group_name: String, check: Area2D) -> bool:
	for body in check.get_overlapping_bodies():
		if body.is_in_group(group_name):
			return true
	return false

func _interact_with_orb_holder() -> void:
	if orb.is_placing or orb.is_placed:
		orb.call_back()
		return
	if orb.is_recalling:
		return
	for group_name in ["OrbCrates", "OrbPlatforms"]:
		for receiver in get_tree().get_nodes_in_group(group_name):
			if receiver.has_method("interact") and receiver.call("interact", self, orb):
				return
