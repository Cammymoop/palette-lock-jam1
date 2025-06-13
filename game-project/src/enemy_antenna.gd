extends Node3D

@export var non_extended_angle: float = deg_to_rad(55.0)
@export var switching_time: float = 0.09

var extended: bool = false

var switching_progress: float = 0.0

@onready var basis_extended: Basis = basis
@onready var basis_non_extended: Basis = basis_extended * Basis.IDENTITY.rotated(Vector3.RIGHT, non_extended_angle)

@onready var rand_extend_speed_factor: float = 1.0

func _ready() -> void:
    switching_progress = 1.0 if extended else 0.0
    set_angle()

func set_angle() -> void:
    basis = lerp(basis_non_extended, basis_extended, switching_progress)

func _process(delta: float) -> void:
    var change_amt: float = delta / switching_time
    if not extended:
        change_amt = -change_amt
    else:
        change_amt *= rand_extend_speed_factor
    switching_progress = clampf(switching_progress + change_amt, 0.0, 1.0)

    set_angle()

func deextend() -> void:
    extended = false

func extend() -> void:
    extended = true
