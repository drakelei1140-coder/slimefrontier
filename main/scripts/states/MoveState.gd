extends Node
class_name MoveState
"""
MoveState（旧状态系统用）
修复点：任何临时变量都给明确类型，避免 Godot 无法推断类型导致 Parse Error
"""

func state_tick(role_actor: ActorBase, delta: float) -> void:
	# 明确类型：Vector2
	var input_move_direction: Vector2 = role_actor.input_move_direction

	# 没输入 -> 回到 IDLE（这里只是示例，具体怎么切要看你的旧状态机）
	if input_move_direction.length() <= 0.1:
		role_actor.velocity = Vector2.ZERO
		role_actor.move_and_slide()
		role_actor.visual_set_move_direction(Vector2.ZERO)
		return

	var move_speed: float = role_actor.get_role_current_move_speed()
	role_actor.velocity = input_move_direction.normalized() * move_speed
	role_actor.move_and_slide()
	role_actor.visual_set_move_direction(input_move_direction)
