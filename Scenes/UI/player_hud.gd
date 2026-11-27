extends Control

@export var orb_sanity_drain_per_second := 5.5
@export var crate_sanity_drain_per_second := 5.0
@export var sanity_recovery_per_second := 8.0
@export var sanity_recovery_delay := 2.0
@export_range(1.0, 500.0, 1.0) var max_health := 100.0
@export var recovery_flower_texture: Texture2D
@export_range(1.0, 1.15) var orb_zoom_multiplier := 1.06
@export_range(0.75, 1.0) var dash_zoom_multiplier := 0.9
@export_range(0.0, 0.3) var orb_vignette_strength := 0.16
@export var screen_effect_smoothing := 8.0

@onready var sanity_fill_material: ShaderMaterial = $SanityFill.material as ShaderMaterial
@onready var health_loss_material: ShaderMaterial = $HealthLoss.material as ShaderMaterial
@onready var flower_particles: GPUParticles2D = $FlowerParticles
@onready var particle_material: ParticleProcessMaterial = flower_particles.process_material as ParticleProcessMaterial
@onready var vignette_material: ShaderMaterial = $"../Vignette".material as ShaderMaterial
@onready var elapsed_time_label: Label = $"../ElapsedTime"
@onready var elapsed_timer: Timer = $ElapsedTimer
@onready var damage_outline: ColorRect = $"../DamageOutline"

var sanity := 100.0
var health := 100.0
var time_since_orb_removed := 0.0
var depletion_flower_texture: Texture2D
var normal_camera_zoom := Vector2.ONE
var camera_zoom_initialized := false
var current_vignette_strength := 0.0
var elapsed_seconds := 0
var damage_outline_tween: Tween

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and player.has_signal("damaged_percent"):
		player.connect("damaged_percent", _on_player_damaged_percent)
	health = max_health
	damage_outline.material.set_shader_parameter("strength", 0.0)
	depletion_flower_texture = flower_particles.texture
	flower_particles.emitting = false
	_update_sanity_fill()
	_update_health_bar()
	elapsed_time_label.text = "Time: 0:00"
	elapsed_timer.timeout.connect(_on_elapsed_timer_timeout)
	elapsed_timer.start()

func _on_player_damaged_percent(percent: float) -> void:
	_flash_damage_outline()
	var damage_amount := max_health * clampf(percent, 0.0, 100.0) / 100.0
	health = maxf(0.0, health - damage_amount)
	_update_health_bar()

func _flash_damage_outline() -> void:
	if damage_outline_tween != null and damage_outline_tween.is_running():
		damage_outline_tween.kill()
	damage_outline.material.set_shader_parameter("strength", 1.0)
	damage_outline_tween = create_tween()
	damage_outline_tween.tween_method(_set_damage_outline_strength, 1.0, 0.0, 0.4)

func _set_damage_outline_strength(value: float) -> void:
	damage_outline.material.set_shader_parameter("strength", value)

func _on_elapsed_timer_timeout() -> void:
	elapsed_seconds += 1
	var minutes := floori(elapsed_seconds / 60.0)
	var seconds := elapsed_seconds % 60
	elapsed_time_label.text = "Time: %d:%02d" % [minutes, seconds]
func _process(delta: float) -> void:
	var orb_is_active := false
	var orb_is_placed := false
	var orb_is_in_holder := false
	var camera: Camera2D
	var player := get_tree().get_first_node_in_group("Player")
	if player != null:
		var orb := player.get_node_or_null("Orb")
		if orb != null:
			orb_is_active = bool(orb.get("is_active"))
			orb_is_placed = bool(orb.get("is_placed"))
			var receiver := orb.get("placed_platform") as Node2D
			orb_is_in_holder = orb_is_placed and receiver != null and (receiver.is_in_group("OrbCrates") or receiver.is_in_group("OrbPlatforms"))
		camera = player.get_node_or_null("Camera2D") as Camera2D

	var dash_is_active := player != null and float(player.get("dash_duration_remaining")) > 0.0
	_update_screen_effects(delta, orb_is_active, dash_is_active, camera)

	var sanity_is_changing := false
	if orb_is_placed:
		time_since_orb_removed = 0.0
		if sanity > 0.0:
			var drain_rate: float = crate_sanity_drain_per_second if orb_is_in_holder else orb_sanity_drain_per_second
			sanity = maxf(0.0, sanity - drain_rate * delta)
			sanity_is_changing = true
			flower_particles.texture = depletion_flower_texture
			particle_material.color = Color(1.0, 0.92, 0.68, 1.0)
	elif sanity < 100.0:
		time_since_orb_removed += delta
		if time_since_orb_removed >= sanity_recovery_delay:
			sanity = minf(100.0, sanity + sanity_recovery_per_second * delta)
			sanity_is_changing = true
			flower_particles.texture = recovery_flower_texture
			particle_material.color = Color(1.0, 1.0, 1.0, 1.0)

	flower_particles.emitting = sanity_is_changing
	if sanity_is_changing:
		flower_particles.position.x = lerpf(
			605.0,
			240.0,
			(100.0 - sanity) / 100.0
		)
		flower_particles.position.y = 115.0

	_update_sanity_fill()

func _update_screen_effects(delta: float, orb_is_active: bool, dash_is_active: bool, camera: Camera2D) -> void:
	var blend := 1.0 - exp(-screen_effect_smoothing * delta)
	var target_vignette_strength := orb_vignette_strength if orb_is_active else 0.0
	current_vignette_strength = lerpf(
		current_vignette_strength,
		target_vignette_strength,
		blend
	)
	vignette_material.set_shader_parameter("strength", current_vignette_strength)

	if camera == null:
		return
	if not camera_zoom_initialized:
		normal_camera_zoom = camera.zoom
		camera_zoom_initialized = true

	var target_zoom_multiplier := 1.0
	if dash_is_active:
		target_zoom_multiplier = dash_zoom_multiplier
	elif orb_is_active:
		target_zoom_multiplier = orb_zoom_multiplier
	var target_zoom := normal_camera_zoom * target_zoom_multiplier
	camera.zoom = camera.zoom.lerp(target_zoom, blend)

func _update_sanity_fill() -> void:
	var depletion := clampf((100.0 - sanity) / 100.0, 0.0, 1.0)
	sanity_fill_material.set_shader_parameter("depletion", depletion)

func _update_health_bar() -> void:
	var health_fraction := clampf(health / max_health, 0.0, 1.0)
	health_loss_material.set_shader_parameter("health_fraction", health_fraction)
