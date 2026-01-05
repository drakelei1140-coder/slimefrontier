extends Area2D
class_name ContactDamageDealer

@export var contact_damage_amount: int = 1
@export var contact_damage_interval: float = 0.5
@export var contact_apply_on_enter: bool = true
@export var contact_target_group: StringName = &"player"

var _active_targets: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	_update_contact_damage(delta)


func _on_body_entered(body: Node) -> void:
	_try_start_contact_with_node(body)


func _on_body_exited(body: Node) -> void:
	_stop_contact_for_node(body)


func _on_area_entered(area: Area2D) -> void:
	_try_start_contact_with_node(area)


func _on_area_exited(area: Area2D) -> void:
	_stop_contact_for_node(area)


func _try_start_contact_with_node(node: Node) -> void:
	var target := _resolve_contact_target(node)
	if target == null:
		return

	_start_contact_for_target(target)


func _stop_contact_for_node(node: Node) -> void:
	var target := _resolve_contact_target(node)
	if target == null:
		return

	_stop_contact_for_target(target)


func _resolve_contact_target(node: Node) -> ActorBase:
	var actor := node as ActorBase
	if actor == null and node.get_parent() != null:
		actor = node.get_parent() as ActorBase

	if actor == null:
		return null

	if contact_target_group != StringName("") and not actor.is_in_group(contact_target_group):
		return null

	return actor


func _start_contact_for_target(target: ActorBase) -> void:
	if _active_targets.has(target):
		var existing_state: Dictionary = _active_targets[target]
		existing_state["overlap_count"] = int(existing_state.get("overlap_count", 0)) + 1
		_active_targets[target] = existing_state
		return

	_active_targets[target] = {
		"accumulator": 0.0,
		"overlap_count": 1,
	}

	var cleanup_callable := _on_target_tree_exited.bind(target)
	if not target.tree_exited.is_connected(cleanup_callable):
		target.tree_exited.connect(cleanup_callable, CONNECT_ONE_SHOT)

	if contact_apply_on_enter:
		_apply_contact_damage_to_target(target)


func _stop_contact_for_target(target: ActorBase) -> void:
	if not _active_targets.has(target):
		return

	var state: Dictionary = _active_targets[target]
	state["overlap_count"] = int(state.get("overlap_count", 0)) - 1

	if state["overlap_count"] <= 0:
		_active_targets.erase(target)
		return

	_active_targets[target] = state


func _on_target_tree_exited(target: ActorBase) -> void:
	_active_targets.erase(target)


func _update_contact_damage(delta: float) -> void:
	var targets := _active_targets.keys()
	for target in targets:
		if not is_instance_valid(target):
			_active_targets.erase(target)
			continue

		var state: Dictionary = _active_targets[target]
		var accumulator: float = float(state.get("accumulator", 0.0)) + delta

		var interval := maxf(contact_damage_interval, 0.001)
		while accumulator >= interval:
			accumulator -= interval
			_apply_contact_damage_to_target(target)

		state["accumulator"] = accumulator
		_active_targets[target] = state


func _apply_contact_damage_to_target(target: ActorBase) -> void:
	if not is_instance_valid(target):
		return

	if target.has_method("apply_contact_damage"):
		target.apply_contact_damage(contact_damage_amount, self)
	elif target.has_method("apply_damage"):
		target.apply_damage(contact_damage_amount, self)
