extends Node3D

signal died

@export var debug_prints: bool = false

@export var does_revive: bool = false
@export var revive_time: float = 5.4

@export var see_distance: float = 40.0
@export var agro_distance: float = 15.0
@export var agro_out_range: float = 55.0
@export var indicator_range: float = 33.0

@export var look_factor: float = 3.0

var attack_node_scn: PackedScene = preload("res://src/enemy_attack_thing.tscn")

var debris_scn: PackedScene = preload("res://src/enemy_debris.tscn")
var smoke_scn: PackedScene = preload("res://src/enemy_smoke.tscn")
@export var debris_count: int = 4

var alive: bool = true
var explosion_frame := false

var target: Node3D
var checked_for_target_timeout := 0.0
var agro_on: bool = false

var antennas_out: bool = true

var attack_charge_wait: float = 0.0
var attack_charge: float = 0.0
var attack_cooldown: float = 0.0
var attack_cooling_down: bool = false

var attack_node: Node3D

var color1 := true

@onready var antennas: Array[Node3D] = [
	$Model/Body/Antenna,
	$Model/Body/Antenna2,
	$Model/Body/Antenna3,
	$Model/Body/Antenna4,
]

@onready var shoot_from: Node3D = $Model/ShootFrom

@export_category("Attack")
@export var attack_charge_time: float = 0.8
@export var attack_uncharge_time: float = 4.0
@export var attack_chage_wait_time: float = 0.7
@export var attack_cooldown_time: float = 3.0

@onready var left_eye_material: StandardMaterial3D = $Model/Body/LeftEye.get_surface_override_material(0)
@onready var right_eye_material: StandardMaterial3D = $Model/Body/RightEye.get_surface_override_material(0)

@export_category("Eye")
@onready var eye_white_color: Color = left_eye_material.emission
@export var eye_other_color: Color = Color(0.0, 1.0, 0.0)

@onready var body: Node3D = $Model/Body
@onready var base_body_pos: Vector3 = body.position

func _ready() -> void:
	$Model/Explosion.visible = false
	update_color()
	
	var min_extend_factor: float = 0.3
	var rand_extend_factor: float = randf_range(min_extend_factor, 1.0)
	var total_range: float = 1.0 - min_extend_factor
	var extend_factors: Array[float] = []
	for i in len(antennas):
		extend_factors.append(rand_extend_factor)
		rand_extend_factor = fposmod(rand_extend_factor - min_extend_factor + (total_range / len(antennas)), total_range) + min_extend_factor
	extend_factors.shuffle()
	for i in len(antennas):
		antennas[i].rand_extend_speed_factor = extend_factors[i]

func find_target() -> void:
	var new_target: Node3D = null
	var players: Array[Node] = get_tree().get_nodes_in_group("Player")

	var min_distance := see_distance
	var min_player: Node3D = null
	for p in players:
		var distance := global_position.distance_to(p.global_position)
		if distance < min_distance:
			min_distance = distance
			min_player = p

	if min_player:
		new_target = min_player
	
	if new_target:
		target = new_target
		on_targetted()
	else:
		untarget()

func on_targetted() -> void:
	body_reset()

func untarget() -> void:
	agro_on = false
	target = null
	antennas_off()
	body_reset()

func body_reset() -> void:
	body.position = base_body_pos

func body_shake(strength: float) -> void:
	strength *= 0.05
	var shake_vector: Vector3 = Vector3(
		randf_range(-strength, strength),
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)
	body.position = base_body_pos + shake_vector

func esplode() -> void:
	if attack_node:
		attack_node.queue_free()
	$Model/Explosion.visible = true
	set_deferred("explosion_frame", true)
	die()
	if does_revive:
		get_tree().create_timer(revive_time).timeout.connect(revive)
	
	for i in debris_count:
		var debris: Node3D = debris_scn.instantiate()
		debris.color1 = color1
		get_parent().add_child(debris)
		debris.global_position = global_position
	
	for i in debris_count:
		var smoke: Node3D = smoke_scn.instantiate()
		get_parent().add_child(smoke)
		smoke.global_position = global_position + smoke.velocity * 0.3

func die() -> void:
	alive = false
	untarget()
	$Hurtbox.get_child(0).set_deferred("disabled", true)
	died.emit()

func revive() -> void:
	$PlaceHolder.visible = false
	alive = true
	$Model.visible = true
	$Hurtbox.get_child(0).disabled = false

func ready_attack() -> void:
	attack_charge = 0.0
	attack_node = attack_node_scn.instantiate()
	attack_node.color1 = color1
	add_child(attack_node)
	attack_node.scale_amt = 0
	attack_node.visible = false
	attack_node.global_position = shoot_from.global_position
	attack_node.point_at(target)
	
	attack_charge_wait = 1.0
	attack_cooldown = 0.0

func update_attack_charge(delta: float) -> void:
	if not attack_node:
		return
	
	attack_node.point_at(target)

	if attack_charge_wait > 0.0:
		attack_charge_wait -= delta / attack_chage_wait_time
		attack_node.scale_amt = 0
		return
	if attack_cooldown > 0.0:
		return
	
	attack_charge += delta / attack_charge_time
	attack_charge = clampf(attack_charge, 0.0, 1.0)
	attack_node.scale_amt = attack_charge
	body_shake(attack_charge)
	
	if attack_charge >= 1.0:
		fire_attack()

func fire_attack() -> void:
	body_reset()
	attack_charge = 0.0
	attack_charge_wait = 0.0
	attack_cooldown = 1.0
	attack_cooling_down = true
	antennas_off()
	
	if not attack_node:
		return
	remove_child(attack_node)
	get_parent().add_child(attack_node)
	attack_node.global_position = shoot_from.global_position
	attack_node.point_at(target)
	attack_node.go()
	attack_node = null

func _process(delta: float) -> void:
	if explosion_frame:
		$Model/Explosion.visible = false
		$Model.visible = false
		explosion_frame = false
	elif alive and not $Model.visible:
		$Model.visible = true

	if not alive:
		return
	
	if target:
		if target.global_position.distance_to(global_position) > agro_out_range:
			find_target()
	else:
		checked_for_target_timeout -= delta
		if checked_for_target_timeout <= 0:
			checked_for_target_timeout = 0.2
			find_target()
	
	if attack_cooling_down and attack_cooldown > 0.0:
		attack_cooldown -= delta / attack_cooldown_time
		if attack_node:
			attack_node.scale_amt = 0
		if attack_cooldown <= 0.0:
			attack_cooling_down = false
			attack_charge_wait = 1.0

	if target:

		if not agro_on:
			if target.global_position.distance_to(global_position) < agro_distance:
				agro_on = true
				antennas_on()

		if agro_on:
			if not attack_cooling_down and not antennas_out:
				antennas_on()
			if not attack_node and not attack_cooling_down:
				ready_attack()
		
		update_attack_charge(delta)
		
		var rev_delta_pos := global_position - target.global_position
		var facing := Basis.looking_at(-rev_delta_pos, Vector3.UP)
		global_basis = lerp(global_basis, facing, look_factor * delta)
		
		left_eye_material.emission = eye_white_color
		right_eye_material.emission = eye_white_color
		if rev_delta_pos.length() < indicator_range:
			var is_front_of_target: bool = target.facing_basis.z.dot(rev_delta_pos.normalized()) < -0.5
			if is_front_of_target:
				var is_right_of_target: bool = target.facing_basis.x.dot(rev_delta_pos) > 0.0
				if is_right_of_target:
					right_eye_material.emission = eye_other_color
				else:
					left_eye_material.emission = eye_other_color
	else:
		if attack_charge > 0.0:
			attack_charge -= delta / attack_uncharge_time
			if attack_node:
				attack_node.scale_amt = attack_charge

func antennas_on() -> void:
	antennas_out = true
	for antenna in antennas:
		antenna.extend()

func antennas_off() -> void:
	antennas_out = false
	for antenna in antennas:
		antenna.deextend()

func update_color() -> void:
	var terr_type_checker: Node3D = $TerrainTypeChecker
	terr_type_checker.update()
	color1 = terr_type_checker.current_terrain_type == 1
	set_all_mesh_colors()

func set_all_mesh_colors() -> void:
	_set_all_mesh_colors(self)

func _set_all_mesh_colors(on_node: Node3D) -> void:
	for child in on_node.get_children():
		if child is MeshInstance3D and child.has_method("set_is_color1"):
			child.set_is_color1(color1)
		if child.get_child_count() > 0:
			_set_all_mesh_colors(child)
