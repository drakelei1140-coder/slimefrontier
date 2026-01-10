extends Node
class_name Enemy01TestDirector

@export var enemy_scene: PackedScene
@export var enemy_parent: NodePath

const SPAWN_POS := Vector2(0.0, 0.0)
const MOVE_OFFSET := Vector2(500.0, 0.0)
const MOVE_DURATION := 1.5
const SPAWN_RIGHT := Vector2(256,0)
const TARGET_LEFT := SPAWN_RIGHT - MOVE_OFFSET

var current_enemy: Node2D = null
var _spawn_button: Button = null
var _kill_button: Button = null
var _stagger_button: Button = null
var _is_killing: bool = false
var _sequence_tween: Tween = null
var _first_arrival_handled: bool = false


func _ready() -> void:
	update_ui_state()


func register_debug_buttons(spawn_button: Button, kill_button: Button, stagger_button: Button) -> void:
	_spawn_button = spawn_button
	_kill_button = kill_button
	_stagger_button = stagger_button
	update_ui_state()


func can_spawn() -> bool:
	return current_enemy == null or not is_instance_valid(current_enemy)


func spawn_enemy() -> void:
	if not can_spawn():
		return
	if enemy_scene == null:
		push_error("Enemy01TestDirector: enemy_scene 未设置")
		return

	var parent_node := get_node_or_null(enemy_parent)
	if parent_node == null:
		push_error("Enemy01TestDirector: enemy_parent 未设置或无效")
		return

	var enemy_instance := enemy_scene.instantiate()
	parent_node.add_child(enemy_instance)

	var enemy_node := enemy_instance as Node2D
	if enemy_node != null:
		enemy_node.global_position = SPAWN_RIGHT

	current_enemy = enemy_node
	_is_killing = false
	_first_arrival_handled = false
	update_ui_state()

	_run_sequence(enemy_node)


func kill_enemy() -> void:
	if not is_instance_valid(current_enemy):
		return
	if _is_killing:
		return

	_is_killing = true
	if _sequence_tween != null:
		_sequence_tween.kill()

	var visual := _get_visual_controller(current_enemy)
	if visual != null and visual.has_method("apply_state"):
		visual.call("apply_state", "die")

	if visual != null and visual.has_signal("die_finished"):
		await visual.die_finished

	if is_instance_valid(current_enemy):
		current_enemy.queue_free()

	current_enemy = null
	_is_killing = false
	update_ui_state()


func stagger_enemy() -> void:
	if not is_instance_valid(current_enemy):
		return
	if _is_killing:
		return

	# ✅ 改为调用敌人自己的入口：由 Enemy_01.gd 控制硬直时长 + 自动回 walk
	if current_enemy.has_method("trigger_stagger"):
		current_enemy.call("trigger_stagger")
		return

	# 兜底：如果某个敌人没实现 trigger_stagger，才直接播动画（但不会自动回退）
	var visual := _get_visual_controller(current_enemy)
	if visual != null and visual.has_method("apply_state"):
		visual.call("apply_state", "stagger")


func update_ui_state() -> void:
	if _spawn_button != null:
		_spawn_button.disabled = not can_spawn()
	if _kill_button != null:
		_kill_button.disabled = can_spawn()
	if _stagger_button != null:
		_stagger_button.disabled = can_spawn()


func _run_sequence(enemy: Node2D) -> void:
	if enemy == null:
		return

	var visual := _get_visual_controller(enemy)
	if visual != null and visual.has_method("apply_state"):
		visual.call("apply_state", "walk")

	_start_movement_loop(enemy)


func _should_stop_sequence(enemy: Node2D) -> bool:
	if _is_killing:
		return true
	if not is_instance_valid(enemy):
		return true
	return current_enemy != enemy


func _start_movement_loop(enemy: Node2D) -> void:
	_sequence_tween = create_tween()
	_sequence_tween.set_loops()
	var distance_to_right := enemy.global_position.distance_to(SPAWN_RIGHT)
	var distance_to_left := enemy.global_position.distance_to(TARGET_LEFT)
	var go_left_first := distance_to_right <= distance_to_left

	if go_left_first:
		_sequence_tween.tween_property(enemy, "global_position", TARGET_LEFT, MOVE_DURATION)
		_sequence_tween.tween_callback(func() -> void:
			_on_reach_left(enemy)
		)
		_sequence_tween.tween_property(enemy, "global_position", SPAWN_RIGHT, MOVE_DURATION)
	else:
		_sequence_tween.tween_property(enemy, "global_position", SPAWN_RIGHT, MOVE_DURATION)
		_sequence_tween.tween_property(enemy, "global_position", TARGET_LEFT, MOVE_DURATION)
		_sequence_tween.tween_callback(func() -> void:
			_on_reach_left(enemy)
		)


func _get_visual_controller(enemy: Node2D) -> Node:
	if enemy == null:
		return null
	return enemy.get_node_or_null("Visual/Enemy01Visual")


func _on_reach_left(enemy: Node2D) -> void:
	if _first_arrival_handled:
		return
	if _should_stop_sequence(enemy):
		return

	_first_arrival_handled = true
	if _sequence_tween != null:
		_sequence_tween.kill()
		_sequence_tween = null

	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		if _should_stop_sequence(enemy):
			return
		if enemy.has_method("trigger_attack"):
			enemy.call("trigger_attack")
		_start_movement_loop(enemy)
	)
