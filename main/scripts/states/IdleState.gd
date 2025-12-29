# res://scripts/states/IdleState.gd
extends State
class_name IdleState

func enter(prev: State) -> void:
	# 进入待机：停住
	actor.velocity = Vector2.ZERO
	actor.move_and_slide()

	# 通知表现层：idle（用 set_move_dir(Vector2.ZERO) 最简单）
	if is_instance_valid(actor.visual_controller):
		actor.visual_controller.call("set_move_dir", Vector2.ZERO)

func handle_input(move_dir: Vector2, dash_pressed: bool) -> void:
	# idle 时有输入就转 move
	if move_dir.length() > 0.1:
		actor.to_move()
