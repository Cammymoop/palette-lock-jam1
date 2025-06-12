extends Marker3D

const RADIANS_PER_PIXEL_MOVED := 0.005

@export var follow_target: NodePath
@export var lerp_factor: float = 0.1
@export var distance_accel_factor: float = 2.0
@export var distance_accel_base: float = 1.0
@export var angle_lerp_factor: float = 3.0
@export var angle_lerp_large_start: float = 0.5
@export var angle_lerp_large_factor: float = 3.0

@export_category("Turning")
@export var mouse_turn_factor: float = 1.0
@export var mouse_turn_factor_immediate_factor: float = 0.25
@export var mouse_turn_hold_required := true
@export var capture_on_mouse_turn_hold := true
@export var cam_turn_factor: float = 6.0

@export_category("Zoom")
@export var zoom_in_distance: float = 6.0
@export var zoom_out_distance: float = 20.0
@export var zoom_increment: float = 0.1
@export var mouse_wheel_zooms: bool = true
@export var zoom_in_analog_factor: float = 3.0

@onready var camera: Camera3D = $CameraZoomHome/Camera3D

var is_following: bool = false
var following_this_node: Node3D

var camera_target_zoom_amt := 0.0

var look_toward: Vector3 = Vector3.FORWARD
var full_rotation_offset: float = 0.0
var rotate_locked := false

func _ready() -> void:
	var cam_forward := -global_basis.z
	cam_forward.y = 0
	look_toward = cam_forward.normalized()

	following_this_node = get_node_or_null(follow_target)
	is_following = following_this_node != null
	if not is_following:
		print_debug("ready: Camera pivot is not following any node")
	
	camera_target_zoom_amt = zoom_out_distance / cam_zoom_range()
	
	$CameraZoomHome/Camera3D.pivot = self

func cam_zoom_range() -> float:
	return zoom_out_distance + zoom_in_distance

func _input(event: InputEvent) -> void:
	var mbutton_event: InputEventMouseButton = event as InputEventMouseButton
	if mbutton_event:
		handle_mouse_button_event(mbutton_event)
	var mmove_event: InputEventMouseMotion = event as InputEventMouseMotion
	if mmove_event:
		handle_mouse_motion_event(mmove_event)
	
func handle_mouse_button_event(event: InputEventMouseButton) -> void:
	if mouse_wheel_zooms and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera_target_zoom_amt += zoom_increment
	elif mouse_wheel_zooms and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera_target_zoom_amt -= zoom_increment
	camera_target_zoom_amt = clampf(camera_target_zoom_amt, 0.0, 1.0)
	
func handle_mouse_motion_event(event: InputEventMouseMotion) -> void:
	if rotate_locked:
		return
	
	var do_mouse_turn := true
	if mouse_turn_hold_required:
		do_mouse_turn = Input.is_action_pressed("mouse_turn_hold")
	
	if do_mouse_turn:
		var mouse_horiz := event.screen_relative.x
		var turn_by := mouse_horiz * mouse_turn_factor * RADIANS_PER_PIXEL_MOVED
		look_toward = look_toward.rotated(Vector3.UP, turn_by)
		rotate_y(turn_by)

func _process(delta: float) -> void:
	if is_following:
		var to_global_pos = following_this_node.global_position
		to_global_pos.y = global_position.y
		var pos_diff = (to_global_pos - global_position).length() / distance_accel_base
		var distance_accel = distance_accel_factor * pos_diff
		var effective_lerp_factor = minf(lerp_factor, lerp_factor * distance_accel)

		position = lerp(global_position, to_global_pos, effective_lerp_factor * 30 * delta)
	
	if Input.is_action_pressed("zoom_in_analog") or Input.is_action_pressed("zoom_out_analog"):
		var strength := Input.get_axis("zoom_out_analog", "zoom_in_analog")
		camera_target_zoom_amt += zoom_in_analog_factor * strength * delta

	camera_target_zoom_amt = clampf(camera_target_zoom_amt, 0.0, 1.0)
	
	update_camera_zoom(delta)
	
	if not rotate_locked:
		if Input.is_action_pressed("turn_cam_left") or Input.is_action_pressed("turn_cam_right"):
			var strength := Input.get_axis("turn_cam_right", "turn_cam_left")
			var turn_by := strength * cam_turn_factor * delta
			look_toward = look_toward.rotated(Vector3.UP, turn_by)
			rotate_y(turn_by * mouse_turn_factor_immediate_factor)
	
	if DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CAPTURED:
		if not capture_on_mouse_turn_hold or not Input.is_action_pressed("mouse_turn_hold"):
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	else:
		if capture_on_mouse_turn_hold and Input.is_action_just_pressed("mouse_turn_hold"):
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	
	if look_toward.length_squared() > 0.0:
		var my_looking := -global_basis.z
		var extra_factor := 0.0

		var dot_product := my_looking.dot(look_toward)
		if dot_product < angle_lerp_large_start:
			var dot_range := 1.0 + angle_lerp_large_start
			extra_factor = (dot_product - (1.0 - angle_lerp_large_start)) / -dot_range

		var new_looking := my_looking.slerp(look_toward, angle_lerp_factor * (1 + extra_factor) * delta)
		global_basis = Basis.looking_at(new_looking, Vector3.UP)

func update_camera_zoom(delta: float) -> void:
	var cur_amt = -camera.position.z
	cur_amt = (zoom_out_distance - camera.position.z) / cam_zoom_range()
	
	var new_zoom_amt = lerp(cur_amt, camera_target_zoom_amt, 3.0 * delta)
	new_zoom_amt = clampf(new_zoom_amt, 0.0, 1.0)
	if abs(new_zoom_amt - camera_target_zoom_amt) < 0.001:
		new_zoom_amt = camera_target_zoom_amt
	camera.position.z = zoom_out_distance - new_zoom_amt * cam_zoom_range()
