extends Node
class_name Enemy01TestDirector

@export var enemy_scene: PackedScene
@export var enemy_parent: NodePath

const SPAWN_POS := Vector2(256.0, 0.0)
const MOVE_OFFSET := Vector2(500.0, 0.0)
const MOVE_DURATION := 1.5

var current_enemy: Node2D = null
var _spawn_button: Button = null
var _kill_button: Button = null
var _is_killing: bool = false
var _sequence_tween: Tween = null


func _ready() -> void:
	update_ui_state()


func register_debug_buttons(spawn_button: Button, kill_button: Button) -> void:
	_spawn_button = spawn_button
	_kill_button = kill_button
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
		enemy_node.global_position = SPAWN_POS

	current_enemy = enemy_node
	_is_killing = false
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


func update_ui_state() -> void:
	if _spawn_button != null:
		_spawn_button.disabled = not can_spawn()
	if _kill_button != null:
		_kill_button.disabled = can_spawn()


func _run_sequence(enemy: Node2D) -> void:
	if enemy == null:
		return

	var visual := _get_visual_controller(enemy)
	if visual != null and visual.has_method("apply_state"):
		visual.call("apply_state", "walk")

	_sequence_tween = create_tween()
	_sequence_tween.tween_property(enemy, "global_position", SPAWN_POS + MOVE_OFFSET, MOVE_DURATION)
	await _sequence_tween.finished

	if _should_stop_sequence(enemy):
		return

	if visual != null and visual.has_method("apply_state"):
		visual.call("apply_state", "stagger")

	await get_tree().create_timer(1.0).timeout
	if _should_stop_sequence(enemy):
		return

	if visual != null and visual.has_method("apply_state"):
		visual.call("apply_state", "attack")


func _should_stop_sequence(enemy: Node2D) -> bool:
	if _is_killing:
		return true
	if not is_instance_valid(enemy):
		return true
	return current_enemy != enemy


func _get_visual_controller(enemy: Node2D) -> Node:
	if enemy == null:
		return null
	return enemy.get_node_or_null("Visual/Enemy01Visual")
