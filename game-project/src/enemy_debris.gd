extends Node3D

@export var upward_velocity: float = 10.0
@export var max_spread: float = PI / 9.0
@export var min_spread: float = 0

@export var gravity: float = 9.8

@export var tumble_min: float = 2.0
@export var tumble_x: float = 8
@export var tumble_z: float = 5

@export var scale_out: bool = false
@export var scale_out_time: float = 0.5
@export_exp_easing() var scale_out_curve: float = 2.0

var time_passed := 0.0

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	velocity = Vector3.UP.rotated(Vector3.RIGHT, randf_range(min_spread, max_spread)) * randf_range(upward_velocity * 0.8, upward_velocity)
	velocity = velocity.rotated(Vector3.UP, randf_range(0, TAU))
	
	tumble_x = randf_range(tumble_min, tumble_x)
	tumble_z = randf_range(tumble_min, tumble_z)
	
	scale_out_time *= randf_range(0.7, 1.0)


func _process(delta: float) -> void:
	time_passed += delta
	velocity.y -= gravity * delta
	global_position += velocity * delta
	
	var scale_out_progress := 0.0
	if scale_out:
		scale_out_progress = ease(time_passed / scale_out_time, scale_out_curve)
		scale = scale.lerp(Vector3.ZERO, scale_out_progress)
	
	rotate_object_local(Vector3.RIGHT, tumble_x * delta)
	rotate_object_local(Vector3.BACK, tumble_z * delta)

	if global_position.y < -2 or scale_out_progress >= 1.0:
		queue_free()