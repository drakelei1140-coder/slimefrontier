extends Node2D
class_name ActorHpBar

@export var actor_path: NodePath = ".."                # 默认认为自己是挂在角色节点下面
@export var anchor_path: NodePath = NodePath()         # 可选：指向角色上的 Marker2D/Node2D（头顶锚点）
@export var offset: Vector2 = Vector2(0, 0)          # 没有 anchor 时的备用偏移
@export var bar_size: Vector2 = Vector2(40, 8)         # 血条大小（屏幕里看起来接近角色大小）

@onready var bar: TextureProgressBar = $HPBar
@onready var _anchor: Node2D = get_node_or_null(anchor_path)

var _actor: Node = null

func _ready() -> void:
	_actor = get_node_or_null(actor_path)

	# 初始位置：如果没有锚点，就用 offset
	if _anchor == null:
		position = offset

	# TextureProgressBar 的 position 是左上角，所以居中要减半宽
	bar.size = bar_size
	bar.position = Vector2(-bar_size.x * 0.5, -bar_size.y * 0.5)

	# 确保压在角色图上面
	z_index = 100

	_bind_actor()
	_refresh()

func _process(_delta: float) -> void:
	_update_follow_anchor()

func _update_follow_anchor() -> void:
	if _anchor == null:
		return
	global_position = _anchor.global_position

func _bind_actor() -> void:
	if _actor == null:
		push_error("ActorHpBar: actor not found, check actor_path.")
		return

	if _actor.has_signal("runtime_stats_changed"):
		if not _actor.runtime_stats_changed.is_connected(_refresh):
			_actor.runtime_stats_changed.connect(_refresh)
	else:
		push_error("ActorHpBar: actor has no signal 'runtime_stats_changed'.")

func _refresh() -> void:
	if _actor == null:
		return
	if not ("runtime_stats" in _actor):
		return

	var rs = _actor.runtime_stats
	if rs == null:
		return

	bar.min_value = 0
	bar.max_value = rs.max_hp
	bar.value = rs.hp
