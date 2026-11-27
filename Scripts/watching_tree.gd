@tool
extends Sprite2D

const FRAMES: Array[Texture2D] = [
	preload("res://Assets/Objects/WatchingTree/tree1.png"),
	preload("res://Assets/Objects/WatchingTree/tree2.png"),
	preload("res://Assets/Objects/WatchingTree/tree3.png"),
	preload("res://Assets/Objects/WatchingTree/tree4.png"),
	preload("res://Assets/Objects/WatchingTree/tree5.png"),
	preload("res://Assets/Objects/WatchingTree/tree6.png"),
	preload("res://Assets/Objects/WatchingTree/tree7.png"),
	preload("res://Assets/Objects/WatchingTree/tree8.png"),
	preload("res://Assets/Objects/WatchingTree/tree9.png"),
	preload("res://Assets/Objects/WatchingTree/tree10.png"),
	preload("res://Assets/Objects/WatchingTree/tree11.png"),
	preload("res://Assets/Objects/WatchingTree/tree12.png"),
	preload("res://Assets/Objects/WatchingTree/tree13.png"),
	preload("res://Assets/Objects/WatchingTree/tree14.png"),
]

## World-space distance from this node to either extreme gaze.
@export_range(1.0, 10000.0, 1.0, "or_greater") var tracking_range: float = 600.0
## Exponential response rate; larger values follow more quickly.
@export_range(0.1, 60.0, 0.1, "or_greater") var tracking_speed: float = 8.0
## Maximum rate of travel through the sequence, in frames per second.
@export_range(0.1, 120.0, 0.1, "or_greater") var max_frames_per_second: float = 30.0
@export_range(1, 14, 1) var default_frame: int = 7:
	set(value):
		default_frame = clampi(value, 1, 14)
		if Engine.is_editor_hint() and is_inside_tree():
			_show_frame(float(default_frame - 1))
## Optional explicit target; otherwise the first node in the Player group is used.
@export var player: Node2D

var _gaze: float
var _blend_material: ShaderMaterial

func _ready() -> void:
	# Each instance needs its own uniforms when trees track independently.
	_blend_material = material.duplicate() as ShaderMaterial
	material = _blend_material
	_gaze = float(default_frame - 1)
	_show_frame(_gaze)
	set_process(not Engine.is_editor_hint())

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node2D
	if not is_instance_valid(player):
		return
	var relative_x := player.global_position.x - global_position.x
	var target := (clampf(relative_x / maxf(tracking_range, 1.0), -1.0, 1.0) + 1.0) * 0.5 * (FRAMES.size() - 1)
	var smoothed := lerpf(_gaze, target, 1.0 - exp(-tracking_speed * delta))
	_gaze = move_toward(_gaze, smoothed, max_frames_per_second * delta)
	_show_frame(_gaze)

func _show_frame(value: float) -> void:
	if not _blend_material:
		return
	var lower := clampi(int(floor(value)), 0, FRAMES.size() - 1)
	var upper := mini(lower + 1, FRAMES.size() - 1)
	texture = FRAMES[lower]
	_blend_material.set_shader_parameter("next_frame", FRAMES[upper])
	_blend_material.set_shader_parameter("frame_blend", value - lower)
