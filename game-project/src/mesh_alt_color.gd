extends MeshInstance3D

@export var is_emission: bool = false
@export var is_color1: bool = true
@export var invert_colors: bool = false
@export var color1: Color = Color("#ee6a7c")
@export var color2: Color = Color("#72dcbb")

func _ready() -> void:
    update_color()

func set_is_color1(value: bool) -> void:
    is_color1 = value
    if invert_colors:
        is_color1 = not is_color1
    update_color()

func update_color() -> void:
    var mat: StandardMaterial3D = get_surface_override_material(0)
    var set_to_color: Color = color1 if is_color1 else color2
    
    if is_emission:
        mat.emission = set_to_color
    else:
        mat.albedo_color = set_to_color