extends Node

var frozen := false

var scn_tree: SceneTree
var freeze_time := 0.1
var unfreeze_timer: Timer

func _ready() -> void:
    scn_tree = get_tree()
    process_mode = Node.PROCESS_MODE_ALWAYS

    unfreeze_timer = Timer.new()
    unfreeze_timer.one_shot = true
    unfreeze_timer.timeout.connect(unfreeze)
    add_child(unfreeze_timer)

func do_hit_freeze(for_time: float = 0.0) -> void:
    frozen = true
    scn_tree.paused = true
    unfreeze_timer.start(for_time if for_time > 0.0 else freeze_time)

func unfreeze() -> void:
    frozen = false
    scn_tree.paused = false
