@tool
extends Node3D

@export var spinning: bool = true
@export var spin_speed: float = 1.0
@export var charge_scale_max: float = 1.7

@export var attack_speed: float = 18.0
@export var max_distance: float = 37.0
@export var fadeout_distance: float = 7.0

var scale_amt: float = 0.0

var going: bool = false
var color1: bool = true

var distance_traveled: float = 0.0

func _ready() -> void:
    if not Engine.is_editor_hint():
        spinning = true
        scale = Vector3.ZERO
    
        $ColoredPart.set_is_color1(color1)

func _process(delta: float) -> void:
    if spinning:
        $LilBits.rotate_z(spin_speed * delta)
    if Engine.is_editor_hint():
        return

    if going:
        position += (-basis.z) * attack_speed * delta
        distance_traveled += attack_speed * delta
        var unfadeout_distance := max_distance - fadeout_distance
        if distance_traveled >= max_distance:
            activate()
        elif distance_traveled >= unfadeout_distance:
            scale_amt = 1.0 - ((distance_traveled - unfadeout_distance) / fadeout_distance)
            udpate_scale()
    else:
        udpate_scale()

func point_at(target: Node3D) -> void:
    global_basis = Basis.looking_at(target.global_position - global_position, Vector3.UP)

func go() -> void:
    going = true
    scale_amt = 1.0
    udpate_scale()

func activate() -> void:
    going = false
    queue_free()

func udpate_scale() -> void:
    visible = scale_amt > 0.0
    if going:
        scale = Vector3.ONE * scale_amt
    else:
        scale = Vector3.ONE * scale_amt * charge_scale_max