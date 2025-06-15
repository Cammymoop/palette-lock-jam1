extends Node3D

@export var group_respawn := false
@export var group_respawn_timeout := 1.0
@export var each_death_resets_timer := true

var any_dead := false
var all_dead := false
var group_respawn_countdown := 0.0

func _ready() -> void:
    for enemy in get_enemies():
        enemy.died.connect(on_enemy_died.bind(enemy))

        if group_respawn:
            enemy.does_revive = false

func _process(delta: float) -> void:
    check_alive()
    if all_dead:
        return

    if any_dead and group_respawn:
        group_respawn_countdown -= delta
        if group_respawn_countdown <= 0.0:
            revive_group()

func get_enemies() -> Array[Node3D]:
    var enemies: Array[Node3D] = []
    for enemy in get_children():
        if not enemy.is_in_group("Respawnable"):
            continue
        enemies.append(enemy)
    return enemies

func check_alive() -> void:
    any_dead = false
    all_dead = true
    for enemy in get_enemies():
        if enemy.alive:
            all_dead = false
        else:
            any_dead = true

func on_enemy_died(enemy_node: Node3D) -> void:
    if not group_respawn:
        return

    var placeholder: Node3D = enemy_node.get_node_or_null("PlaceHolder")
    if placeholder:
        placeholder.visible = true
    
    if not any_dead or each_death_resets_timer:
        start_respawn_timer()
    
    check_alive()
    if all_dead:
        for enemy in get_enemies():
            var e_placeholder: Node3D = enemy.get_node_or_null("PlaceHolder")
            if e_placeholder:
                e_placeholder.visible = false

func start_respawn_timer() -> void:
    group_respawn_countdown = group_respawn_timeout

func revive_group() -> void:
    for enemy in get_enemies():
        if not enemy.alive:
            enemy.revive()