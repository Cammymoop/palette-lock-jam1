extends Node3D

var terrain_type_source: MeshInstance3D
var terrain_type_source_material: Material
var edge_parameter_name: String = "edge"
var noise_tex: NoiseTexture2D = preload("res://assets/first_noise_tex.tres")
var noise_tex_img: Image

var current_terrain_type: int = -1 

func _ready() -> void:
	check_for_terrain_type_source()
	# Cache an Image version of the texture so we can read pixels every frame
	print("Noise texture: ", noise_tex)
	# Obtain an Image from the underlying FastNoiseLite resource.
	noise_tex_img = noise_tex.noise.get_image(noise_tex.width, noise_tex.height, noise_tex.invert)
	if noise_tex_img == null:
		print_debug("[TerrainTypeChecker] FastNoiseLite.get_image() returned null; will sample via direct noise calls instead.")
	print("Noise texture image: ", noise_tex_img)

func check_for_terrain_type_source() -> void:
	var possible_sources := get_tree().get_nodes_in_group("TerrainTypeSource")
	if possible_sources.size() > 0:
		terrain_type_source = possible_sources[0]
		# Cache the override material from surface 0 if available
		terrain_type_source_material = terrain_type_source.get_surface_override_material(0)
	else:
		print("No terrain type source found")

# Helper: Convert this node's world position to a 0..1 UV inside the QuadMesh
func _get_uv_from_world_position() -> Vector2:
	if terrain_type_source == null:
		print_debug("[TerrainTypeChecker] No terrain_type_source in _get_uv_from_world_position(). Returning (0,0) UV.")
		return Vector2.ZERO

	# Position of this node in the local space of the terrain mesh
	var local_pos: Vector3 = terrain_type_source.to_local(global_transform.origin)

	# Try to derive the mesh size so we can normalise coordinates into 0..1
	var mesh := terrain_type_source.mesh
	var u: float = 0.0
	var v: float = 0.0
	if mesh is QuadMesh:
		var qm: QuadMesh = mesh
		var size: Vector2 = qm.size # full size on X (width) and Y (depth)
		var half_x: float = size.x * 0.5
		var half_z: float = size.y * 0.5
		u = (local_pos.x + half_x) / size.x
		v = (local_pos.z + half_z) / size.y
	else:
		# Fallback: use the mesh AABB
		var aabb: AABB = mesh.get_aabb()
		var rel: Vector3 = local_pos - aabb.position
		u = rel.x / aabb.size.x
		v = rel.z / aabb.size.z

	return Vector2(clamp(u, 0.0, 1.0), clamp(v, 0.0, 1.0))

func update() -> void:
	if terrain_type_source == null:
		check_for_terrain_type_source()
		if terrain_type_source == null:
			print_debug("[TerrainTypeChecker] update(): missing terrain_type_source; skipping terrain check.")
			return
	var sample_at_uv: Vector2 = _get_uv_from_world_position()
	current_terrain_type = get_effective_terrain_type(sample_at_uv)

func get_effective_terrain_type(at_uv: Vector2) -> int:
	var sampled_value: float

	if noise_tex_img != null:
		var sampled_color: Color = _sample_image_bilinear(noise_tex_img, at_uv)
		sampled_value = sampled_color.r
	elif noise_tex.noise != null:
		print("not sampling image")
		# Fallback: sample directly from the underlying Noise resource.
		var width: int = noise_tex.width
		var height: int = noise_tex.height
		var nx: float = at_uv.x * float(width)
		var ny: float = at_uv.y * float(height)
		var raw_noise: float = noise_tex.noise.get_noise_2d(nx, ny) # range [-1,1]
		var normalized: float = clamp((raw_noise + 1.0) * 0.5, 0.0, 1.0) # convert to [0,1]

		# If the NoiseTexture2D has a gradient, apply it just like the texture generation would.
		if noise_tex.color_ramp != null:
			var grad_color: Color = noise_tex.color_ramp.sample(normalized)
			sampled_value = grad_color.r # assuming grayscale gradient; use red channel
		else:
			sampled_value = normalized
	else:
		print_debug("[TerrainTypeChecker] get_effective_terrain_type(): Unable to sample noise (no image and no Noise resource). Returning -1.")
		return -1

	# Compare the sampled value against the shader's edge threshold
	if terrain_type_source_material == null:
		# Try to obtain the material once if not already cached, using per-surface override
		terrain_type_source_material = terrain_type_source.get_surface_override_material(0)
	var edge_param_value: float = 0.5
	if terrain_type_source_material != null:
		edge_param_value = terrain_type_source_material.get_shader_parameter(edge_parameter_name)

	var processed_value: int = 1 if sampled_value >= edge_param_value else 0
	return processed_value

# Bilinear sample helper for Image resources
func _sample_image_bilinear(img: Image, uv: Vector2) -> Color:
	if img == null:
		return Color.WHITE
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 1 or h <= 1:
		return img.get_pixel(0, 0)
	var x: float = clamp(uv.x, 0.0, 1.0) * float(w - 1)
	var y: float = clamp(uv.y, 0.0, 1.0) * float(h - 1)
	var x0: int = int(floor(x))
	var y0: int = int(floor(y))
	var x1: int = min(x0 + 1, w - 1)
	var y1: int = min(y0 + 1, h - 1)
	var dx: float = x - float(x0)
	var dy: float = y - float(y0)
	var c00: Color = img.get_pixel(x0, y0)
	var c10: Color = img.get_pixel(x1, y0)
	var c01: Color = img.get_pixel(x0, y1)
	var c11: Color = img.get_pixel(x1, y1)
	var c0: Color = c00.lerp(c10, dx)
	var c1: Color = c01.lerp(c11, dx)
	return c0.lerp(c1, dy)
