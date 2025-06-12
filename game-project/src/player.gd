extends Node3D

@export var base_speed: float = 15.0
@export var base_turning_factor: float = 0.3
@export var base_stopping_factor: float = 0.05
@export var base_speed_factor: float = 0.3

@export_category("Zoom")
@export var zoom_speed: float = 32.0
@export var zoom_alignment_factor: float = 0.98
@export var zoom_activation_time: float = 4.5
@export var zoom_charge_decay: float = 4.0
@export var zoom_turning_factor: float = 0.5

@export var zoom_meter_active_color: Color = Color.WHITE
@export var zoom_meter_inactive_color: Color = Color.GRAY

@onready var model: Node3D = $Model
@onready var booster: Node3D = $Model/Tilt/Boost
@onready var model_tilt: Node3D = $Model/Tilt

@onready var zoom_meter: Sprite3D = $MeterPos/Meter

var facing_direction: Vector3 = Vector3.FORWARD

var residual_velocity: Vector3 = Vector3.ZERO

var zoom_charge := 0.0
var zooming := false

const BOUNCE_NO_TURN = 0.4

var no_turn := false
var bounce_countdown := 0.0

func _process(delta: float) -> void:
	
	var active_camera: Camera3D = get_viewport().get_camera_3d()

	var inp_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	if no_turn:
		bounce_countdown -= delta
		if bounce_countdown <= 0.0:
			no_turn = false

	var cam_forward := -active_camera.global_transform.basis.z
	cam_forward.y = 0
	var direction := Basis.looking_at(cam_forward, Vector3.UP) * Vector3(inp_dir.x, 0, inp_dir.y)

	booster.visible = false
	if no_turn:
		direction = residual_velocity.normalized()
		inp_dir = Vector2.UP

	if inp_dir.length() > 0.01:
		booster.visible = true
		if not zooming: 
			var threshold_speed := base_speed * zoom_alignment_factor
			var alignment := residual_velocity.dot(direction)
			if alignment > threshold_speed:
				zoom_charge += delta / zoom_activation_time
				if zoom_charge > 1.0:
					activate_zoom()
			elif alignment < 0.0:
				deactivate_zoom()
			else:
				zoom_charge -= zoom_charge_decay * (1.0 - (alignment/base_speed)) * delta
		else:
			var norm_alignment := residual_velocity.normalized().dot(direction)
			zoom_charge -= zoom_charge_decay * (1.0 - norm_alignment) * delta
	else:
		if zoom_charge > 0.0:
			if not zooming:
				zoom_charge -= zoom_charge_decay * delta
			else:
				zoom_charge -= zoom_charge_decay * 0.3 * delta
		direction = Vector3.ZERO
	
	if zooming and zoom_charge <= 0.0:
		deactivate_zoom()	
	zoom_charge = maxf(zoom_charge, 0.0)
	update_zoom_meter()
	
	if direction.length_squared() > 0.0:
		var to_speed = base_speed
		var base_speeding := base_speed_factor * 60.0
		var base_turning := base_turning_factor * 60.0

		var turning_factor = base_turning
		if zooming:
			to_speed = zoom_speed
			turning_factor *= zoom_turning_factor

		var new_vel_speed: float = lerp(residual_velocity.length(), to_speed, base_speeding * delta)

		var cur_vel_angle: float = residual_velocity.signed_angle_to(Vector3.FORWARD, Vector3.UP)
		var target_vel_angle: float = direction.signed_angle_to(Vector3.FORWARD, Vector3.UP)
		var new_vel_angle: float = lerp_angle(cur_vel_angle, target_vel_angle, turning_factor * delta)

		residual_velocity = Vector3.FORWARD.rotated(Vector3.UP, -new_vel_angle) * new_vel_speed
	else:
		if not zooming:
			residual_velocity = lerp(residual_velocity, Vector3.ZERO, base_stopping_factor)
	
	if residual_velocity.length_squared() > 0.0:
		facing_direction = residual_velocity.normalized()
	$Model.rotation.y = lerp_angle($Model.rotation.y, atan2(-facing_direction.x, -facing_direction.z), 6.0 * delta)

	global_position += residual_velocity * delta
	
	if zooming:
		active_camera.pivot.look_toward = residual_velocity.normalized()

func update_zoom_meter() -> void:
	var grad: GradientTexture1D = zoom_meter.texture
	var norm_charge := clampf(zoom_charge, 0.0, 1.0)
	grad.gradient.set_offset(1, 1 - norm_charge)
	grad.gradient.set_color(1, zoom_meter_active_color if zooming else zoom_meter_inactive_color)

func activate_zoom() -> void:
	zooming = true
	booster.scale = Vector3.ONE
	booster.scale.z = 1.6
	model_tilt.rotate_x(PI / 16)
	zoom_charge = 1.0

func deactivate_zoom() -> void:
	zooming = false
	booster.scale = Vector3.ONE * 0.8
	model_tilt.basis = Basis.IDENTITY
	zoom_charge = 0.0

func bounced() -> void:
	no_turn = true
	bounce_countdown = BOUNCE_NO_TURN