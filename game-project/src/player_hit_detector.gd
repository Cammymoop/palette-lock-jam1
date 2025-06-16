extends Area3D

@onready var player: Node3D = find_parent("Player")

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
		player.bounced(delta_to_ideal)

		if player.can_ram():
			if entity.has_method("esplode"):
				entity.esplode()
			else:
				entity.queue_free()

func find_body_aabb(body: Node3D) -> AABB:
	var collision_shape: ConcavePolygonShape3D = body.get_node("CollisionShape3D").shape
	if not collision_shape:
		print_debug("No collision shape found for body: ", body.name)
		return AABB()

	var aabb: AABB = AABB()
	aabb.position = body.global_position
	for face_vertex in collision_shape.get_faces():
		aabb = aabb.expand(body.to_global(face_vertex))
	return aabb


func _on_body_entered(body: Node3D) -> void:
	var body_center: Vector3 = find_body_aabb(body).get_center()
	var fake_normal: Vector3 = player.global_position - body_center
	fake_normal.y = 0.0
	fake_normal = fake_normal.normalized()
	#var fake_tangent: Vector3 = fake_normal.cross(Vector3.UP)

	#var flipped_velocity: Vector3 = player.residual_velocity * -1
	#var reflected_velocity: Vector3 = (2.0 * flipped_velocity.dot(fake_tangent) * fake_tangent) - flipped_velocity
	player.residual_velocity = player.residual_velocity.length() * fake_normal
	player.bounced(Vector3.ZERO)
