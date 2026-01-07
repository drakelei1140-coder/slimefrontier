extends Area2D
class_name OneShotDamageDealer

@export var damage_amount: int = 1
@export var stagger_amount: float = 0.0
@export var target_group: StringName = &"player"

var _hit_targets: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func begin_attack() -> void:
	_hit_targets.clear()


func set_active(is_active: bool) -> void:
	visible = is_active
	monitoring = is_active
	monitorable = is_active

	for child in get_children():
		var shape := child as CollisionShape2D
		if shape == null:
			continue
		if child.get_parent() != self:
			continue
		shape.disabled = not is_active


func _on_area_entered(area: Area2D) -> void:
	_try_apply_damage(area)


func _on_body_entered(body: Node) -> void:
	_try_apply_damage(body)


func _try_apply_damage(node: Node) -> void:
	var target := _resolve_contact_target(node)
	if target == null:
		return

	if _hit_targets.has(target):
		return

	_hit_targets[target] = true
	_apply_damage_to_target(target)


func _resolve_contact_target(node: Node) -> ActorBase:
	var actor := node as ActorBase
	if actor == null and node.get_parent() != null:
		actor = node.get_parent() as ActorBase

	if actor == null:
		return null

	if target_group != StringName("") and not actor.is_in_group(target_group):
		return null

	return actor


func _apply_damage_to_target(target: ActorBase) -> void:
	if not is_instance_valid(target):
		return

	if target.has_method("role_apply_hit"):
		target.role_apply_hit(damage_amount, stagger_amount)
	elif target.has_method("apply_damage"):
		target.apply_damage(damage_amount, self)
	elif target.has_method("apply_contact_damage"):
		target.apply_contact_damage(damage_amount, self)
