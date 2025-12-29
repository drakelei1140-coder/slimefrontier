extends Node2D
class_name TailPivotSway
"""
TailPivotSway：尾巴摆动（二阶系统）
- 无骨骼版：让一个尾巴节点（默认 GhostTail）用“弹簧 + 阻尼”跟随 TailPivot.rotation
- 用于 ghost 的尾巴甩动效果
"""

@export var tail_visual_node_path: NodePath = NodePath("GhostTail")

@export var tail_rotation_multiplier: float = 1.6   # 尾巴摆动放大倍数
@export var tail_spring_response: float = 24.0      # 回拉强度（越大跟得越紧）
@export var tail_damping: float = 18.0              # 阻尼（越大越不抖）

var visual_tail_node: Node2D = null
var tail_angular_velocity: float = 0.0


func _ready() -> void:
	visual_tail_node = get_node_or_null(tail_visual_node_path) as Node2D
	tail_angular_velocity = 0.0


# 供 VisualController 调用：死亡时/重置时清空甩动状态
func reset_tail_sway_state() -> void:
	tail_angular_velocity = 0.0
	if visual_tail_node != null:
		visual_tail_node.rotation = 0.0


func _process(delta: float) -> void:
	if visual_tail_node == null:
		return

	var dt := maxf(delta, 0.0001)

	# TailPivot 本体 rotation 是“根部摆动”
	var base_rotation := rotation

	# 尾巴想要跟随的目标角度（可放大）
	var target_rotation := base_rotation * tail_rotation_multiplier

	# 二阶系统：a = (target - current) * response - vel * damping
	var angular_accel := (target_rotation - visual_tail_node.rotation) * tail_spring_response \
		- tail_angular_velocity * tail_damping

	tail_angular_velocity += angular_accel * dt
	visual_tail_node.rotation += tail_angular_velocity * dt
