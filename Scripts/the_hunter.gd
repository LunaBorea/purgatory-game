extends Node2D

const ANIM_SPIKE: StringName = &"TheHunterSpike"
const ANIM_JUMP: StringName = &"TheHunterJump"
const ANIM_JUMP_REVERSE: StringName = &"TheHunterJumpReverse"
const ANIM_BITE: StringName = &"TheHunterBite"

@export_group("Detection")
@export_range(1, 3, 1) var layer_number := 2
@export var require_matching_layer := true
@export_range(32.0, 600.0, 8.0) var detection_radius := 190.0
@export_range(16.0, 240.0, 4.0) var bite_radius := 76.0
@export_range(0.0, 30.0, 0.5) var return_delay_seconds := 8.0

@export_group("Visual alignment")
@export_range(-10.0, 10.0, 0.5) var spike_frame_2_y_correction := 3.0
@export_range(-60.0, 60.0, 0.5) var jump_animation_vertical_offset := 37.0
@export_range(-30.0, 30.0, 0.5) var jump_return_vertical_offset := 20.0
@export_range(-30.0, 30.0, 0.5) var jump_return_horizontal_offset := 10.0
@export var jump_frame_y_corrections: PackedFloat32Array = PackedFloat32Array([
	16.0, 16.0, 15.0, 13.0, 14.0, 12.0, 30.0,
	28.0, 19.0, -1.0, 12.0, 1.0, 0.0, 0.0
])
@export var bite_frame_y_corrections: PackedFloat32Array = PackedFloat32Array([
	0.0, 13.0, 13.0, 13.0, 0.0, 16.0, -7.0,
	-7.0, 16.0, 16.0, 0.0, 0.0, 0.0
])
@export var bite_frame_x_corrections: PackedFloat32Array = PackedFloat32Array([
	0.0, -4.0, -4.0, -4.0, 0.0, 22.4, 8.7,
	8.7, 22.4, 22.4, 0.0, 0.0, 0.0
])

@export var activation_platform_path: NodePath

@export_group("Attack")
@export_range(0.0, 100.0, 0.5) var bite_damage_percent := 7.0
@export_range(0.0, 1.0, 0.05) var damage_recoil_multiplier := 1.0
@export_range(0.1, 10.0, 0.1) var attack_cooldown := 1.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var bite_area: Area2D = $BiteArea
@onready var player: Node2D = get_tree().get_first_node_in_group("Player")

var _attack_cooldown_remaining := 0.0
var _bite_animation_playing := false
var _jump_form_active := false
var _jump_sequence_completed := false
var _is_reversing_jump := false
var _return_timer_remaining := -1.0
var _jump_resume_frame := 0
var _jump_resume_progress := 0.0

func _ready() -> void:
	_set_area_radius(detection_area, detection_radius)
	_set_area_radius(bite_area, bite_radius)
	animated_sprite.animation_changed.connect(_apply_frame_alignment)
	animated_sprite.frame_changed.connect(_apply_frame_alignment)
	_apply_frame_alignment()
	animated_sprite.play(ANIM_SPIKE)
	if not activation_platform_path.is_empty():
		visible = false
		detection_area.monitoring = false
		bite_area.monitoring = false
		set_physics_process(false)
		var platform := get_node_or_null(activation_platform_path)
		if platform != null and platform.has_signal("orb_placed"):
			platform.connect("orb_placed", _on_orb_platform_placed)
		else:
			push_warning("Hunter activation platform was not found: %s" % activation_platform_path)

func _on_orb_platform_placed() -> void:
	if visible:
		return
	visible = true
	detection_area.monitoring = true
	bite_area.monitoring = true
	_jump_form_active = true
	_jump_sequence_completed = false
	_is_reversing_jump = false
	_bite_animation_playing = false
	_attack_cooldown_remaining = 0.0
	_return_timer_remaining = -1.0
	animated_sprite.play(ANIM_JUMP)
	_apply_frame_alignment()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		return

	var player_detected := _player_is_in_area(detection_area)
	var player_close := _player_is_in_area(bite_area)
	if player_detected:
		_return_timer_remaining = -1.0
		if _is_reversing_jump:
			_is_reversing_jump = false
			_jump_sequence_completed = false
			animated_sprite.play(ANIM_JUMP)
		elif not _jump_form_active:
			_jump_form_active = true
			_jump_sequence_completed = false
			animated_sprite.play(ANIM_JUMP)
	elif _jump_form_active and _jump_sequence_completed and not _bite_animation_playing and not _is_reversing_jump:
		_set_jump_top_pose()
		if _return_timer_remaining < 0.0:
			_return_timer_remaining = return_delay_seconds
		else:
			_return_timer_remaining = maxf(0.0, _return_timer_remaining - delta)
		if _return_timer_remaining <= 0.0:
			_is_reversing_jump = true
			_return_timer_remaining = -1.0
			animated_sprite.play(ANIM_JUMP_REVERSE)

	if player_close and _attack_cooldown_remaining <= 0.0 and not _bite_animation_playing:
		_start_bite()
		return

	if _bite_animation_playing:
		return

	if _jump_form_active and _jump_sequence_completed and not _is_reversing_jump:
		if player_detected:
			_set_bite_idle_pose()
		else:
			_set_jump_top_pose()
	elif not _jump_form_active:
		_play_form(ANIM_SPIKE)

func _set_area_radius(area: Area2D, radius: float) -> void:
	var collision_shape := area.get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision_shape.shape.duplicate() as CircleShape2D
	circle.radius = radius
	collision_shape.shape = circle

func _player_is_in_area(area: Area2D) -> bool:
	if not area.overlaps_body(player):
		return false
	if area == bite_area and player.has_method("is_invulnerable") and player.call("is_invulnerable"):
		return false
	if not require_matching_layer:
		return true
	return int(player.get("current_mask")) == layer_number

func _start_bite() -> void:
	_bite_animation_playing = true
	if animated_sprite.animation == ANIM_JUMP:
		_jump_resume_frame = animated_sprite.frame
		_jump_resume_progress = animated_sprite.frame_progress
	animated_sprite.play(ANIM_BITE)
	if _apply_bite_damage():
		_attack_cooldown_remaining = attack_cooldown
	else:
		_bite_animation_playing = false

func _apply_bite_damage() -> bool:
	var hit_player := get_tree().get_first_node_in_group("Player") as Node2D
	if not is_instance_valid(hit_player) or not hit_player.has_method("take_damage_percent"):
		return false
	player = hit_player
	hit_player.call("take_damage_percent", bite_damage_percent, global_position, damage_recoil_multiplier)
	return true

func _restore_form_after_bite() -> void:
	if not _jump_form_active:
		_play_form(ANIM_SPIKE)
		return

	if _jump_sequence_completed:
		if _player_is_in_area(detection_area):
			_set_bite_idle_pose()
		else:
			_set_jump_top_pose()
			_return_timer_remaining = return_delay_seconds
	else:
		animated_sprite.play(ANIM_JUMP)
		animated_sprite.set_frame_and_progress(_jump_resume_frame, _jump_resume_progress)

func _set_bite_idle_pose() -> void:
	if animated_sprite.animation == ANIM_BITE and not animated_sprite.is_playing() and animated_sprite.frame == 0:
		return
	animated_sprite.play(ANIM_BITE)
	animated_sprite.set_frame_and_progress(0, 0.0)
	animated_sprite.pause()

func _set_jump_top_pose() -> void:
	if animated_sprite.animation == ANIM_JUMP and not animated_sprite.is_playing() and animated_sprite.frame == 13:
		return
	animated_sprite.play(ANIM_JUMP)
	animated_sprite.set_frame_and_progress(13, 0.0)
	animated_sprite.pause()

func _play_form(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func _apply_frame_alignment() -> void:
	animated_sprite.offset = Vector2.ZERO
	if animated_sprite.animation == ANIM_SPIKE and animated_sprite.frame == 2:
		animated_sprite.offset.y = spike_frame_2_y_correction
	elif animated_sprite.animation == ANIM_JUMP:
		_apply_jump_frame_alignment(animated_sprite.frame)
	elif animated_sprite.animation == ANIM_JUMP_REVERSE:
		var source_frame := 13 - animated_sprite.frame
		_apply_jump_frame_alignment(
			source_frame,
			jump_return_vertical_offset,
			jump_return_horizontal_offset
		)
	elif animated_sprite.animation == ANIM_BITE:
		var bite_frame := animated_sprite.frame
		if bite_frame >= 0 and bite_frame < bite_frame_y_corrections.size():
			animated_sprite.offset.y = bite_frame_y_corrections[bite_frame]
			if bite_frame < bite_frame_x_corrections.size():
				animated_sprite.offset.x = bite_frame_x_corrections[bite_frame]

func _apply_jump_frame_alignment(
	source_frame: int,
	extra_vertical_offset: float = 0.0,
	extra_horizontal_offset: float = 0.0
) -> void:
	if source_frame >= 0 and source_frame < jump_frame_y_corrections.size():
		animated_sprite.offset = Vector2(
			extra_horizontal_offset,
			jump_frame_y_corrections[source_frame] + jump_animation_vertical_offset + extra_vertical_offset
		)

func _on_animation_finished() -> void:
	match animated_sprite.animation:
		ANIM_JUMP:
			_jump_sequence_completed = true
			if _player_is_in_area(detection_area):
				_set_bite_idle_pose()
			else:
				_set_jump_top_pose()
				_return_timer_remaining = return_delay_seconds
		ANIM_BITE:
			_bite_animation_playing = false
			_restore_form_after_bite()
		ANIM_JUMP_REVERSE:
			_is_reversing_jump = false
			_jump_form_active = false
			_jump_sequence_completed = false
			_play_form(ANIM_SPIKE)
