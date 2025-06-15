extends Node

var _blast_just_pressed := false
var blast_just_pressed := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
    if not _blast_just_pressed:
        blast_just_pressed = false

    if Input.is_action_just_pressed("blast"):
        _blast_just_pressed = true
        blast_just_pressed = true
    
    if not get_tree().paused:
        if not Input.is_action_pressed("blast"):
            _blast_just_pressed = false

func is_blast_just_pressed() -> bool:
    var was_pressed := blast_just_pressed
    if blast_just_pressed and not _blast_just_pressed:
        blast_just_pressed = false

    return was_pressed