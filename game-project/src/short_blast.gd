extends Node3D

var velocity: Vector3 = Vector3.ZERO

var playing: bool = false

func show_blast(new_velocity: Vector3) -> void:
    playing = true
    $AnimationPlayer.play("pew")
    velocity = new_velocity

func _process(delta: float) -> void:
    if playing:
        position += velocity * delta

func _on_animation_player_animation_finished(anim_name:StringName) -> void:
    if anim_name == "pew":
        playing = false
