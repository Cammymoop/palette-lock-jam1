extends Node3D

@export var does_revive: bool = false
@export var revive_time: float = 1.4

@export var agro_range: float = 70.0

@export var look_factor: float = 3.0

var debris_scn: PackedScene = preload("res://src/enemy_debris.tscn")
var smoke_scn: PackedScene = preload("res://src/enemy_smoke.tscn")
@export var debris_count: int = 4

var alive: bool = true
var explosion_frame := false

var target: Node3D
var checked_for_target_timeout := 0.0

func _ready() -> void:
	$Model/Explosion.visible = false

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
	$Model/Explosion.visible = true
	set_deferred("explosion_frame", true)
	die()
	if does_revive:
		get_tree().create_timer(revive_time).timeout.connect(revive)
	
	for i in debris_count:
		var debris: Node3D = debris_scn.instantiate()
		get_parent().add_child(debris)
		debris.global_position = global_position
	
	for i in debris_count:
		var smoke: Node3D = smoke_scn.instantiate()
		get_parent().add_child(smoke)
		smoke.global_position = global_position + smoke.velocity * 0.3

func die() -> void:
	alive = false
	target = null
	$Hurtbox.get_child(0).set_deferred("disabled", true)

func revive() -> void:
	alive = true
	$Model.visible = true
	$Hurtbox.get_child(0).disabled = false

func _process(delta: float) -> void:
	if explosion_frame:
		$Model/Explosion.visible = false
		$Model.visible = false
		explosion_frame = false

	if not alive:
		return
	
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
