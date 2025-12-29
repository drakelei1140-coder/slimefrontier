# res://scripts/states/DeadState.gd
extends State
class_name DeadState

var _hooked: bool = false

func enter(prev: State) -> void:
	# 死亡：停住
	actor.velocity = Vector2.ZERO
	actor.move_and_slide()

	# 通知表现层播 die
	if is_instance_valid(actor.visual_controller):
		actor.visual_controller.call("play_die")

		# 这里不直接 queue_free，因为你现有逻辑是：
		# VisualController die_finished -> Player 监听 -> queue_free
		# 所以 DeadState 只负责“开始播”
	_hooked = true

func update(delta: float) -> void:
	# 死亡状态下不做别的
	pass
