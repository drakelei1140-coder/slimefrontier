# res://scripts/states/State.gd
extends RefCounted
class_name State

# 状态基类：不挂节点，不进场景树
# 只作为“逻辑对象”被 ActorBase 持有

var actor: ActorBase

func _init(_actor: ActorBase) -> void:
	actor = _actor

# 进入状态时调用
func enter(prev: State) -> void:
	pass

# 离开状态时调用
func exit(next: State) -> void:
	pass

# 每帧逻辑更新（在 ActorBase._physics_process 调）
func update(delta: float) -> void:
	pass

# 处理输入（由 ActorBase 把输入向量、按键事件喂进来）
func handle_input(move_dir: Vector2, dash_pressed: bool) -> void:
	pass

# 受击入口（由 ActorBase.apply_hit 调用）
func on_hit(stagger_time: float) -> void:
	# 默认：进入硬直（如果有硬直时间）
	if stagger_time > 0.0:
		actor.to_stagger(stagger_time)
