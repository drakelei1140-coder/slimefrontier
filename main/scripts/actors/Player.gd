extends "res://main/scripts/actors/ActorBase.gd"
class_name Player
"""
Player：输入层
- 负责：读取 InputMap，把输入写入 ActorBase 的 input_* 字段
- 逻辑运算：全部交给 ActorBase（状态机、dash、无敌帧等）
"""

@export var input_move_deadzone: float = 0.25

@onready var cached_visual_controller: Node = $Visual/PureSlimeVisual


func _ready() -> void:
	# 把表现层引用交给 ActorBase
	role_visual_controller = cached_visual_controller

	# 死亡动画播完 -> 销毁角色节点（你当前调试流程：die 后消失）
	if is_instance_valid(cached_visual_controller) and cached_visual_controller.has_signal("die_finished"):
		cached_visual_controller.connect("die_finished", _on_visual_die_finished)

	#role_current_facing_direction = Vector2.LEFT
	#role_last_nonzero_move_direction = Vector2.LEFT

	# 调用基类初始化
	super._ready()


func _physics_process(delta: float) -> void:
	# 1) 读取移动方向
	var raw_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 2) 死区过滤（避免手柄漂移）
	if raw_dir.length() < input_move_deadzone:
		raw_dir = Vector2.ZERO

	# 3) 写入基类输入字段
	input_move_direction = raw_dir

	# 4) 读取 dash（一次性触发）
	if Input.is_action_just_pressed("dash"):
		input_dash_pressed_this_frame = true

	# 5) 跑基类逻辑
	super._physics_process(delta)


func _on_visual_die_finished() -> void:
	queue_free()
