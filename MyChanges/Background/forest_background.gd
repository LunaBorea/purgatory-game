extends Node2D
## MyChanges: the forest background.
##
## Sideways scrolling and endless repeating is done by the Parallax2D layers.
## This script adds the up/down part: when the camera goes up (jumping onto
## high platforms) far layers follow it more than near ones, so you never see
## the top edge of the pictures and the forest feels deep.

## Camera height when standing on the middle floor lane (where you start). At this height the
## painted ground lines up with the level floor.
@export var rest_camera_y := 489.0

## Extra space kept between the top of the pictures and the top of the screen.
@export var top_margin := 12.0

@onready var fills: Node2D = $Fills
var _layers: Array[Node2D] = []
var _factors: Array[float] = []
var _cover_tops: Array[float] = []


func _ready() -> void:
	for child in get_children():
		if child is Parallax2D and child.has_node("Lift"):
			_layers.append(child.get_node("Lift"))
			_factors.append(float(child.get_meta("vertical_parallax", 1.0)))
			_cover_tops.append(float(child.get_meta("cover_top", -INF)))


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.get_screen_center_position()
	fills.global_position.x = center.x
	# Top of what is actually visible: works for any window size, fullscreen and zoom.
	var visible_height := get_viewport().get_visible_rect().size.y / camera.zoom.y
	var screen_top := center.y - visible_height * 0.5
	for i in _layers.size():
		var lift := (center.y - rest_camera_y) * (1.0 - _factors[i])
		# Never let the top edge of a picture come into view: lift the layer instead.
		lift = minf(lift, screen_top - top_margin - _cover_tops[i])
		_layers[i].position.y = lift
