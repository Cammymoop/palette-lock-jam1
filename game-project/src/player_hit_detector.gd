extends Area3D

@onready var player: Node3D = get_parent()

func _on_area_entered(area: Area3D) -> void:
	var entity: Node3D = area.get_parent()
	if not entity.is_in_group("Explodable"):
		return

	var old_vel: Vector3 = player.residual_velocity
	var vel_perpendicular: Vector3 = old_vel.cross(Vector3.UP)
	if old_vel.length_squared() > 0.0:
		var relative_center: Vector3 = entity.global_position - player.global_position
		var angle_sign := signf(vel_perpendicular.dot(relative_center))
		player.residual_velocity = old_vel.rotated(Vector3.UP, angle_sign * (PI/4))
		var new_perpindicular: Vector3 = player.residual_velocity.cross(Vector3.UP).normalized()
		var delta_to_ideal: Vector3 = new_perpindicular.dot(relative_center * 0.5) * new_perpindicular.normalized()
		prints("delta correction:", delta_to_ideal, "magnitude:", delta_to_ideal.length(), "rel center magnitude:", relative_center.length())
		player.bounced(delta_to_ideal)

		if entity.has_method("esplode"):
			entity.esplode()
		else:
			entity.queue_free()
