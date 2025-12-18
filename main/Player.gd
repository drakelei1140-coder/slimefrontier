extends ActorBase
class_name Player

@export var move_speed: float = 300.0
@export var deadzone: float = 0.25

@onready var visual_controller: VisualController = $Visual/PureSlimeVisual

enum State { ALIVE, DYING, DEAD }
var state: State = State.ALIVE


func _physics_process(delta: float) -> void:
	# 死亡/死亡中：不响应输入、不移动
	if state != State.ALIVE:
		velocity = Vector2.ZERO
		move_and_slide() # 可选：让角色继续参与碰撞滑动/停住更稳定；不想调用也可以删掉
		return

	# 读取输入方向
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 死区过滤（手柄漂移）
	if dir.length() < deadzone:
		dir = Vector2.ZERO

	# 传给 VisualController 切动画/朝向
	if is_instance_valid(visual_controller):
		visual_controller.set_move_dir(dir)

	# 移动
	velocity = dir * move_speed
	move_and_slide()


func die() -> void:
	# 防止重复触发
	if state != State.ALIVE:
		return

	state = State.DYING
	velocity = Vector2.ZERO

	# 如果你希望死后彻底不再推挤/被碰撞影响，可以禁用碰撞：
	# $CollisionShape2D.disabled = true

	if is_instance_valid(visual_controller):
		visual_controller.play_die()

func _ready() -> void:
	if is_instance_valid(visual_controller):
		visual_controller.die_finished.connect(_on_die_finished)

func _on_die_finished() -> void:
	queue_free()
