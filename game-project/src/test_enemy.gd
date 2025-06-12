extends Node3D

@export var does_revive: bool = false
@export var revive_time: float = 1.4

@export var agro_range: float = 70.0

@export var look_factor: float = 3.0

var alive: bool = true

var target: Node3D
var checked_for_target_timeout := 0.0

func find_target() -> void:
	target = null
	var players: Array[Node] = get_tree().get_nodes_in_group("Player")

	var min_distance := agro_range
	var min_player: Node3D = null
	for p in players:
		var distance := global_position.distance_to(p.global_position)
		if distance < min_distance:
			min_distance = distance
			min_player = p

	if min_player:
		target = min_player

func esplode() -> void:
	if not does_revive:
		queue_free()
	else:
		die()
		get_tree().create_timer(revive_time).timeout.connect(revive)

func die() -> void:
	alive = false
	for child in $Model.get_children():
		child.visible = false
	$Model/Explosion.visible = true
	$Hurtbox.get_child(0).set_deferred("disabled", true)

func revive() -> void:
	alive = true
	$Model.visible = true
	$Hurtbox.get_child(0).disabled = false

func _process(delta: float) -> void:
	if not alive:
		$Model.visible = false
	
	if target:
		if target.global_position.distance_to(global_position) > agro_range * 2:
			find_target()
	else:
		checked_for_target_timeout -= delta
		if checked_for_target_timeout <= 0:
			checked_for_target_timeout = 0.2
			find_target()
	
	if target:
		var facing := Basis.looking_at(target.global_position - global_position, Vector3.UP)
		global_basis = lerp(global_basis, facing, look_factor * delta)
