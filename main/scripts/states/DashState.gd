# res://scripts/states/DashState.gd
extends State
class_name DashState

var _t: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT

func enter(prev: State) -> void:
	_t = 0.0

	# 冲刺方向：优先当前输入，否则用最后一次移动方向
	if actor.move_dir.length() > 0.1:
		_dash_dir = actor.move_dir.normalized()
	else:
		_dash_dir = actor.last_nonzero_move_dir.normalized()

	# 一进入 dash 就开始 CD（你也可以改成 exit 才开始）
	actor.start_dash_cd()

func update(delta: float) -> void:
	_t += delta

	# 强制移动
	actor.velocity = _dash_dir * actor.dash_speed
	actor.move_and_slide()

	# 表现层：通常冲刺也希望保持朝向
	if is_instance_valid(actor.visual_controller):
		actor.visual_controller.call("set_move_dir", _dash_dir)

	# 冲刺结束：回到 idle 或 move
	if _t >= actor.dash_duration:
		if actor.move_dir.length() > 0.1:
			actor.to_move()
		else:
			actor.to_idle()

func is_invincible() -> bool:
	# 前 dash_iframe_duration 秒为无敌帧
	return _t <= actor.dash_iframe_duration
