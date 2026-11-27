extends Node2D
## MyChanges: fireflies like real ones on a summer night.
##
## Real fireflies are dark most of the time: every few seconds one slowly lights up,
## glows warm yellow for about a second and fades out again (some flash twice).
## Each one has its own rhythm, so only a few are lit at the same moment.
## In between they drift slowly and bob up and down a little.
## They wrap around the screen, so there are fireflies wherever you walk.
## Keep this node at position (0, 0).

@export var count := 12
## How the swarm moves with the camera: 0 = stuck to the screen,
## 1 = part of the level, more than 1 = in front of the level.
@export var parallax := 0.3
@export var vertical_parallax := 0.25
## Height band the fireflies like to stay in (world y when standing on the floor).
@export var band_top := 120.0
@export var band_bottom := 520.0
@export var size_min := 10.0
@export var size_max := 18.0
@export var speed_min := 3.0
@export var speed_max := 10.0
## How quickly the flying direction wanders. Lower = longer, calmer glides.
@export var wander := 0.05
@export var brightness := 0.9
@export var color_a := Color(1.0, 0.8, 0.26)
@export var color_b := Color(1.0, 0.9, 0.42)

@export_group("Blinking")
## Seconds between two flashes of the same firefly (random between these).
@export var blink_every_min := 5.0
@export var blink_every_max := 11.0
## How long one flash lasts (fade in + fade out), in seconds.
@export var flash_length := 1.3
## Chance that a firefly flashes twice in a row.
@export_range(0.0, 1.0) var double_flash_chance := 0.3
## Glow while "off". 0 = completely dark, like real fireflies.
@export_range(0.0, 0.3) var dark_glow := 0.0

@export var random_seed := 1
## Camera height when standing on the middle lane; keep the same as ForestBackground.
@export var rest_camera_y := 489.0

var _positions: PackedVector2Array
var _sizes: PackedFloat32Array
var _colors: PackedColorArray
var _alphas: PackedFloat32Array
var _ids: PackedFloat32Array
var _periods: PackedFloat32Array
var _offsets: PackedFloat32Array
var _doubles: PackedByteArray
var _noise := FastNoiseLite.new()
var _time := 0.0
var _center := Vector2.ZERO
var _glow: Texture2D


func _ready() -> void:
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = random_seed
	_glow = _make_glow()

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in count:
		_positions.append(Vector2(rng.randf_range(-1500.0, 1500.0), rng.randf_range(band_top, band_bottom)))
		_sizes.append(rng.randf_range(size_min, size_max))
		_colors.append(color_a.lerp(color_b, rng.randf()))
		_alphas.append(0.0)
		_ids.append(rng.randf_range(0.0, 1000.0))
		var period := rng.randf_range(blink_every_min, blink_every_max)
		_periods.append(period)
		_offsets.append(rng.randf_range(0.0, period))
		_doubles.append(1 if rng.randf() < double_flash_chance else 0)


## 0..1 light of one firefly at time t: dark most of the time, a soft flash now and then.
static func flash(t: float, period: float, length: float, double_flash: bool) -> float:
	var local := fposmod(t, period)
	var light := _pulse(local, length)
	if double_flash:
		light = maxf(light, _pulse(local - length * 0.8, length * 0.7) * 0.8)
	return light


static func _pulse(x: float, length: float) -> float:
	if x <= 0.0 or x >= length:
		return 0.0
	var s := sin(PI * x / length)
	return s * s


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	_time += delta
	_center = camera.get_screen_center_position()
	var half_width := get_viewport_rect().size.x / camera.zoom.x * 0.5 + size_max * 2.0 + 60.0
	var layer_center_x := _center.x * parallax

	for i in count:
		var id := _ids[i]
		var p := _positions[i]
		# Smooth random heading, lazy speed, and a little bobbing like a hovering insect.
		var angle := _noise.get_noise_2d(_time * wander, id) * TAU * 1.6
		var speed := lerpf(speed_min, speed_max, 0.5 + 0.5 * _noise.get_noise_2d(_time * 0.08, id + 333.0))
		var velocity := Vector2(cos(angle), sin(angle) * 0.5) * speed
		velocity.y += sin(_time * 1.3 + id) * 6.0
		# Gently steer back into the height band.
		if p.y < band_top:
			velocity.y += (band_top - p.y) * 0.4
		elif p.y > band_bottom:
			velocity.y -= (p.y - band_bottom) * 0.4
		p += velocity * delta
		# Wrap around the visible area.
		if p.x < layer_center_x - half_width:
			p.x += half_width * 2.0
		elif p.x > layer_center_x + half_width:
			p.x -= half_width * 2.0
		_positions[i] = p
		var light := flash(_time + _offsets[i], _periods[i], flash_length, _doubles[i] == 1)
		_alphas[i] = lerpf(dark_glow, 1.0, light) * brightness
	queue_redraw()


func _draw() -> void:
	var lift := (_center.y - rest_camera_y) * (1.0 - vertical_parallax)
	var shift_x := _center.x * (1.0 - parallax)
	for i in count:
		if _alphas[i] <= 0.003:
			continue
		var world := Vector2(_positions[i].x + shift_x, _positions[i].y + lift)
		var size := _sizes[i]
		var color := _colors[i]
		color.a = _alphas[i]
		draw_texture_rect(_glow, Rect2(world - Vector2(size, size) * 0.5, Vector2(size, size)), false, color)
		# Small bright centre: the firefly's tail light.
		draw_circle(world, size * 0.08, Color(1.0, 0.95, 0.7, _alphas[i]), true, -1.0, true)


func _make_glow() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.12, Color(1, 1, 1, 0.75))
	gradient.add_point(0.35, Color(1, 1, 1, 0.2))
	gradient.add_point(0.7, Color(1, 1, 1, 0.05))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
