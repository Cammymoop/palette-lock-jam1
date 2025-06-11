extends Marker3D

@export var follow_target: NodePath
@export var lerp_factor: float = 0.1
@export var distance_accel_factor: float = 2.0
@export var distance_accel_base: float = 1.0

@export_category("Zoom")
@export var zoom_in_distance: float = 6.0
@export var zoom_out_distance: float = 20.0
@export var zoom_increment: float = 0.1
@export var mouse_wheel_zooms: bool = true

@onready var camera: Camera3D = $CameraZoomHome/Camera3D

var is_following: bool = false
var following_this_node: Node3D

var camera_target_zoom_amt := 0.0

func _ready() -> void:
	following_this_node = get_node_or_null(follow_target)
	is_following = following_this_node != null
	if not is_following:
		print_debug("Camera pivot is not following any node")
	
	camera_target_zoom_amt = zoom_out_distance / cam_zoom_range()

func cam_zoom_range() -> float:
	return zoom_out_distance + zoom_in_distance

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	if mouse_wheel_zooms and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera_target_zoom_amt += zoom_increment
	elif mouse_wheel_zooms and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera_target_zoom_amt -= zoom_increment
	camera_target_zoom_amt = clampf(camera_target_zoom_amt, 0.0, 1.0)
	

func _process(delta: float) -> void:
	if is_following:
		var to_global_pos = following_this_node.global_position
		to_global_pos.y = global_position.y
		var pos_diff = (to_global_pos - global_position).length() / distance_accel_base
		var distance_accel = distance_accel_factor * pos_diff
		var effective_lerp_factor = minf(lerp_factor, lerp_factor * distance_accel)

		position = lerp(global_position, to_global_pos, effective_lerp_factor * 30 * delta)
	
	update_camera_zoom(delta)

func update_camera_zoom(delta: float) -> void:
	var cur_amt = -camera.position.z
	cur_amt = (zoom_out_distance - camera.position.z) / cam_zoom_range()
	
	var new_zoom_amt = lerp(cur_amt, camera_target_zoom_amt, 3.0 * delta)
	new_zoom_amt = clampf(new_zoom_amt, 0.0, 1.0)
	if abs(new_zoom_amt - camera_target_zoom_amt) < 0.001:
		new_zoom_amt = camera_target_zoom_amt
	camera.position.z = zoom_out_distance - new_zoom_amt * cam_zoom_range()
