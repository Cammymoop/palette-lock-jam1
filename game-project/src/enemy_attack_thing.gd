@tool
extends Node3D

@export var spinning: bool = true
@export var spin_speed: float = 1.0
@export var charge_scale_max: float = 1.3

@export var attack_speed: float = 9.0
@export var max_distance: float = 30.0

var scale_amt: float = 0.0

var going: bool = false

var distance_traveled: float = 0.0

func _ready() -> void:
    if not Engine.is_editor_hint():
        spinning = true
        scale = Vector3.ZERO

func _process(delta: float) -> void:
    if spinning:
        $LilBits.rotate_z(spin_speed * delta)
    if Engine.is_editor_hint():
        return

    if going:
        position += (-basis.z) * attack_speed * delta
        distance_traveled += attack_speed * delta
        if distance_traveled >= max_distance:
            activate()
    else:
        scale = Vector3.ONE * scale_amt * charge_scale_max

func point_at(target: Node3D) -> void:
    global_basis = Basis.looking_at(target.global_position - global_position, Vector3.UP)

func go() -> void:
    going = true
    scale_amt = 1.0
    scale = Vector3.ONE

func activate() -> void:
    going = false
    queue_free()