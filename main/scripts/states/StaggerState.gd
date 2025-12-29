# res://scripts/states/StaggerState.gd
extends State
class_name StaggerState

var _remaining: float = 0.0

func enter(prev: State) -> void:
	# 进入硬直：停住
	actor.velocity = Vector2.ZERO
	actor.move_and_slide()

	# 表现层：硬直动画你以后可以加
	# 现在先维持当前朝向即可（也可以 set_move_dir(Vector2.ZERO)）
	if is_instance_valid(actor.visual_controller):
		actor.visual_controller.call("set_move_dir", Vector2.ZERO)

func refresh(t: float) -> void:
	# 不叠加：直接刷新剩余时间
	_remaining = maxf(t, 0.0)

func update(delta: float) -> void:
	_remaining -= delta

	# 硬直期间不能移动：保持停住
	actor.velocity = Vector2.ZERO
	actor.move_and_slide()

	if _remaining <= 0.0:
		# 结束后：根据输入回 idle/move
		if actor.move_dir.length() > 0.1:
			actor.to_move()
		else:
			actor.to_idle()
