extends Node3D

@export var base_speed: float = 15.0
@export var base_turning_factor: float = 4.0
@export var base_stopping_factor: float = 0.4
@export var base_speed_factor: float = 0.3
@export var extra_velocity_decay_factor: float = 0.1

@export_category("Zoom")
@export var zoom_speed: float = 32.0
@export var zoom_alignment_factor: float = 0.90
@export var zoom_activation_time: float = 2.5
@export var zoom_charge_decay: float = 4.0
@export var zoom_turning_factor: float = 1.0

@export var zoom_input_lock_in_time: float = 0.2

@export_category("Braking")
@export var braking_decay_factor: float = 5.0
@export var turning_to_braking_factor: float = 0.1
@export var braking_regen_max_turn: float = 0.08
@export var braking_regen_factor: float = 0.18

@export var zoom_meter_active_color: Color = Color.WHITE
@export var zoom_meter_inactive_color: Color = Color.GRAY

@onready var model: Node3D = $Model
@onready var booster: Node3D = $Model/Tilt/Boost
@onready var model_tilt: Node3D = $Model/Tilt

@onready var zoom_meter: Sprite3D = $MeterPos/Meter

var facing_direction: Vector3 = Vector3.FORWARD

var residual_velocity: Vector3 = Vector3.ZERO

@export_category("Digital Input Smoothing")
@export var do_digital_input_smoothing: bool = true
@export var smooth_no_input_time: float = 0.05
@export var smooth_turning_time: float = 0.15
@export var smooth_non_zoom_time: float = 0.05

var hit_effect_frame := false

var smoothed_non_zoom_inp_angle := Vector2.UP.angle()
var smoothed_turning: float = 0.0
var smoothed_no_input: float = 1.0

var zoom_charge := 0.0
var zooming := false

var is_analog_movment := false

var zoom_input_lock_in_time_remaining := 0.0
var zoom_down_in_threshold := 0.6
var zoom_down_hold_in := false
var zoom_down_brake_threshold := 0.84

const BOUNCE_NO_TURN = 0.4

var no_turn := false
var bounce_countdown := 0.0

var restart_pressed: int = 0

@onready var facing_basis: Basis = model.global_basis

const BOUCE_CORRECTION_TIME = 4/60.0
var need_bounce_correction := false
var bounce_correction_vector: Vector3 = Vector3.ZERO
var bounce_correction_applied: float = 0

@onready var terrain_type_checker: Node3D = $TerrainTypeChecker
@onready var terrain_type_indicator: MeshInstance3D = find_child("TerrainTypeIndicator")

var blast_input_held := false

@export var blast_cooldown_time: float = 0.8
var blast_cooldown := 0.0

@onready var blast_detector: Area3D = find_child("BlastDetector")
@onready var blast_visual: Node3D = find_child("BlastVisual")
@onready var blast_visual_pos: Node3D = find_child("BlastVisualPos")

var last_terrain_type := -1

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		restart_pressed += 1
		$RestartLabel.show()
		$RestartDoublePressTimeout.start()
	if restart_pressed >= 2:
		get_tree().reload_current_scene()
		return


	if need_bounce_correction:
		apply_bounce_correction(delta / BOUCE_CORRECTION_TIME)
	
	if hit_effect_frame:
		hit_effect_frame = false
	
	if blast_cooldown > 0.0:
		blast_cooldown -= delta
	elif InputJustPressedRememberer.is_blast_just_pressed():
		do_blast()
	
	var active_camera: Camera3D = get_viewport().get_camera_3d()

	var analog_inp_dir: Vector2 = Input.get_vector("move_left_analog", "move_right_analog", "move_forward_analog", "move_back_analog")
	var digital_inp_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	if digital_inp_dir.length_squared() > 0:
		is_analog_movment = false
	elif not is_analog_movment and analog_inp_dir.length_squared() > 0:
		is_analog_movment = true
	
	var inp_dir := analog_inp_dir if is_analog_movment else digital_inp_dir

	if not is_analog_movment and do_digital_input_smoothing:
		if digital_inp_dir == Vector2.ZERO:
			smoothed_no_input += minf(delta / smooth_no_input_time, 1.0)
		else:
			smoothed_no_input = 0.0

		var actual_turning := digital_inp_dir.x
		var diff := actual_turning - smoothed_turning
		var smooth_sign := signf(diff)
		smoothed_turning += smooth_sign * minf(delta / smooth_turning_time, absf(diff))

		var angle_delta := Vector2.RIGHT.rotated(smoothed_non_zoom_inp_angle).angle_to(digital_inp_dir)
		var delta_sign := signf(angle_delta)
		smoothed_non_zoom_inp_angle += delta_sign * minf(delta / smooth_non_zoom_time, absf(angle_delta))
		
		if smoothed_no_input >= 1:
			inp_dir = Vector2.ZERO
		elif zooming:
			inp_dir = Vector2(smoothed_turning, inp_dir.y)
		else:
			inp_dir = Vector2.RIGHT.rotated(smoothed_non_zoom_inp_angle)
	
	if no_turn:
		bounce_countdown -= delta
		if bounce_countdown <= 0.0:
			no_turn = false

	var cam_forward := -active_camera.global_transform.basis.z
	cam_forward.y = 0
	var direction := Basis.looking_at(cam_forward, Vector3.UP) * Vector3(inp_dir.x, 0, inp_dir.y)
	
	var braking := false
	
	if zooming and zoom_input_lock_in_time_remaining > 0.0:
		zoom_input_lock_in_time_remaining -= delta
		direction = residual_velocity.normalized()
		zoom_down_hold_in = inp_dir.y > zoom_down_in_threshold
	elif zooming:
		var vel_basis := Basis.looking_at(residual_velocity, Vector3.UP)
		direction = vel_basis * Vector3(inp_dir.x, 0, inp_dir.y)
		braking = inp_dir.y > zoom_down_brake_threshold
		if zoom_down_hold_in:
			braking = false
			if inp_dir.y < zoom_down_in_threshold:
				zoom_down_hold_in = false

	booster.visible = false
	if no_turn:
		direction = residual_velocity.normalized()
		inp_dir = Vector2.UP

	if not zooming and inp_dir.length() > 0.01:
		booster.visible = true
		var threshold_speed := base_speed * zoom_alignment_factor
		var alignment := residual_velocity.dot(direction)
		if alignment > threshold_speed:
			zoom_charge += delta / zoom_activation_time
		elif alignment < 0.0:
			deactivate_zoom()
		else:
			zoom_charge -= zoom_charge_decay * (1.0 - (alignment/base_speed)) * delta
	elif zooming:
		booster.visible = true
		var braking_amt := 1.0 if braking else 0.0
		var abs_horiz := absf(inp_dir.x)
		braking_amt = maxf(braking_amt, abs_horiz * turning_to_braking_factor)
		if not braking and abs_horiz < braking_regen_max_turn:
			zoom_charge += braking_regen_factor * delta
		else:
			zoom_charge -= braking_decay_factor * braking_amt * delta
	else:
		if zoom_charge > 0.0:
			if not zooming:
				zoom_charge -= zoom_charge_decay * delta
			else:
				zoom_charge -= zoom_charge_decay * 0.3 * delta
		direction = Vector3.ZERO
	zoom_charge = clampf(zoom_charge, 0.0, 1.0)
	
	var base_speeding := base_speed_factor * 60.0
	if zooming:
		var to_speed := zoom_speed
		var turning_factor = inp_dir.x * zoom_turning_factor

		var new_vel_speed: float = lerp(residual_velocity.length(), to_speed, base_speeding * delta)
		var cur_vel_angle: float = residual_velocity.signed_angle_to(Vector3.FORWARD, Vector3.UP)
		var new_vel_angle: float = cur_vel_angle + (turning_factor * delta)
		residual_velocity = Vector3.FORWARD.rotated(Vector3.UP, -new_vel_angle) * new_vel_speed
	elif direction.length_squared() > 0.0:
		var to_speed := base_speed
		var turning_factor := base_turning_factor
		
		var vel_speed := residual_velocity.length()
		
		# overvelocity decay
		if vel_speed > to_speed:
			var overspeed := vel_speed - to_speed
			overspeed *= 1 - (extra_velocity_decay_factor * delta)
			residual_velocity = residual_velocity.normalized() * (to_speed + overspeed)

		# calculate what the change in velocity would've been if we had no overvelocity
		#var clamped_new_vel_speed: float = lerp(minf(vel_speed, to_speed), to_speed, base_speeding * delta)

		#var cur_vel_angle: float = residual_velocity.signed_angle_to(Vector3.FORWARD, Vector3.UP)
		#var target_vel_angle: float = direction.signed_angle_to(Vector3.FORWARD, Vector3.UP)
		#var new_vel_angle: float = lerp_angle(cur_vel_angle, target_vel_angle, turning_factor * delta)

		#var changed_residual_velocity = Vector3.FORWARD.rotated(Vector3.UP, -new_vel_angle) * clamped_new_vel_speed
		var clamped_old_residual_velocity := residual_velocity.normalized() * minf(residual_velocity.length(), to_speed)
		var changed_residual_velocity := clamped_old_residual_velocity.lerp(direction * to_speed, turning_factor * delta)
		var vel_diff := changed_residual_velocity - clamped_old_residual_velocity

		# add that to the actual residual velocity, meaning overvelocity is left alone other than decay
		residual_velocity += vel_diff
	else:
		residual_velocity = lerp(residual_velocity, Vector3.ZERO, base_stopping_factor * delta)
	
	if not zooming and zoom_charge >= 0.93 and Input.is_action_just_pressed("activate_boost"):
		activate_zoom()
	elif zooming and zoom_charge <= 0.0:
		deactivate_zoom()	
	zoom_charge = maxf(zoom_charge, 0.0)
	update_zoom_meter()

	if residual_velocity.length_squared() > 0.0:
		facing_direction = residual_velocity.normalized()

	$Model.rotation.y = lerp_angle($Model.rotation.y, atan2(-facing_direction.x, -facing_direction.z), 6.0 * delta)

	global_position += residual_velocity * delta
	
	terrain_type_checker.update()
	if terrain_type_checker.current_terrain_type != last_terrain_type:
		last_terrain_type = terrain_type_checker.current_terrain_type
		
		if last_terrain_type != -1:
			terrain_type_indicator.set_is_color1(last_terrain_type == 0)
	
	if zooming or Input.is_action_just_pressed("activate_boost"):
		active_camera.pivot.look_toward = residual_velocity.normalized()
	
	if residual_velocity.length_squared() > 0.001:
		facing_basis = get_global_facing_basis()

func get_global_facing_basis() -> Basis:
	if residual_velocity == Vector3.ZERO:
		return facing_basis
	return Basis.looking_at(residual_velocity, Vector3.UP)

func apply_bounce_correction(amt: float) -> void:
	amt = minf(amt, 1 - bounce_correction_applied)
	var correction_vec := bounce_correction_vector * amt
	global_position += correction_vec
	bounce_correction_applied += amt
	if bounce_correction_applied >= 1.0:
		need_bounce_correction = false
		bounce_correction_applied = 0


func update_zoom_meter() -> void:
	var grad: GradientTexture1D = zoom_meter.texture
	var norm_charge := clampf(zoom_charge, 0.0, 1.0)
	grad.gradient.set_offset(1, 1 - norm_charge)
	grad.gradient.set_color(1, zoom_meter_active_color if zooming else zoom_meter_inactive_color)

func activate_zoom() -> void:
	zooming = true
	zoom_input_lock_in_time_remaining = zoom_input_lock_in_time
	smoothed_turning = 0
	booster.scale = Vector3.ONE
	booster.scale.z = 1.6
	model_tilt.rotate_x(PI / 10)
	zoom_charge = 1.0

func deactivate_zoom() -> void:
	zooming = false
	zoom_input_lock_in_time_remaining = 0.0
	booster.scale = Vector3.ONE * 0.8
	model_tilt.basis = Basis.IDENTITY
	zoom_charge = 0.0

func bounced(new_bounce_correction: Vector3) -> void:
	if need_bounce_correction:
		# add all the lingering bounce correction at once
		apply_bounce_correction(1.0)

	no_turn = true
	bounce_countdown = BOUNCE_NO_TURN
	if zooming or true:
		HitFreezer.do_hit_freeze()
		if new_bounce_correction.length_squared() > 0.0:
			set_bounce_correction(new_bounce_correction)
	
	hit_effect_frame = true

func set_bounce_correction(new_bounce_correction: Vector3) -> void:
	need_bounce_correction = true
	bounce_correction_vector = new_bounce_correction
	bounce_correction_applied = 0

func do_blast() -> void:
	blast_visual.show_blast(residual_velocity)
	blast_visual.global_transform = blast_visual_pos.global_transform
	
	var found_explodable_areas := blast_detector.get_overlapping_areas()
	for explodable_area in found_explodable_areas:
		var entity: Node3D = explodable_area.get_parent()
		if not entity or not entity.is_in_group("Explodable"):
			continue

		if entity.has_method("esplode"):
			entity.esplode()
		else:
			entity.queue_free()
	
	blast_cooldown = blast_cooldown_time


func _on_restart_double_press_timeout_timeout() -> void:
	restart_pressed = 0
	$RestartLabel.hide()

func can_ram() -> bool:
	return zooming