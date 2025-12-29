extends Node2D
"""
Game（场景级控制器 / Scene Controller）
- 上帝视角管理脚本：不参与移动/战斗
- 负责：
  1) 管理玩家实例的生成 / 销毁（spawn / despawn）
  2) 管理出生点 SpawnPoint
  3) 向 UI（DebugPanel）暴露“查询当前玩家 / 调试生成玩家”等接口

注意：
- DebugPanel（调试面板）按钮的连接、disabled 状态更新，全部交给 DebugPanel.gd 管理
- Game 不再直接引用任何 Button，避免 UI 结构变化导致 Nil 报错
"""

# =========================
# Inspector 可配置：玩家预制体（PackedScene）
# =========================
@export var game_player_packed_scene: PackedScene
# 在 Inspector 里拖入：res://.../pureslime.tscn


# =========================
# 场景节点引用（onready）
# =========================
@onready var game_players_root_node: Node = $Entities/Players
@onready var game_player_spawn_point: Node2D = $SpawnPoint


# =========================
# 当前被 Game 管理的玩家实例（同一时间 0 或 1 个）
# =========================
var game_current_player_instance: Player = null


func _ready() -> void:
	# 启动时：
	# - 若场景中手动放了玩家：接管
	# - 否则：自动生成一个（方便调试；不想自动生成就注释掉 _game_spawn_player_instance()）
	game_current_player_instance = _game_find_existing_player_instance()

	if is_instance_valid(game_current_player_instance):
		# 监听玩家销毁：玩家 queue_free 后触发 tree_exited
		game_current_player_instance.tree_exited.connect(_on_game_player_tree_exited)
	else:
		_game_spawn_player_instance()


# =========================
# 对外接口（给 DebugPanel 调用）
# =========================
func game_get_current_player_instance() -> Player:
	# 防止被 DebugPanel 在 Game ready 之前调用导致 onready 未赋值
	if not is_node_ready():
		return null

	if is_instance_valid(game_current_player_instance):
		return game_current_player_instance

	# 兜底：如果引用丢了，尝试在容器里重新找
	game_current_player_instance = _game_find_existing_player_instance()
	return game_current_player_instance


func game_debug_respawn_player() -> void:
	# 给 DebugPanel 的“复活/重生”按钮用
	# 规则：有玩家时不生成（包括正在 die 动画还没 queue_free）
	if is_instance_valid(game_current_player_instance):
		return

	_game_spawn_player_instance()


# =========================
# 内部：生成 / 销毁监听
# =========================
func _game_spawn_player_instance() -> void:
	# 玩家实例化的唯一入口
	if game_player_packed_scene == null:
		push_error("game_player_packed_scene 没有设置：请在 Game 节点 Inspector 里拖入 pureslime.tscn（PackedScene）")
		return

	# 安全：容器/出生点检查（理论上 onready 已保证，但这里加一道避免改场景后踩坑）
	if game_players_root_node == null or not is_instance_valid(game_players_root_node):
		push_error("game_players_root_node 无效：请检查场景路径 Entities/Players 是否存在")
		return
	if game_player_spawn_point == null or not is_instance_valid(game_player_spawn_point):
		push_error("game_player_spawn_point 无效：请检查场景路径 SpawnPoint 是否存在")
		return

	game_current_player_instance = game_player_packed_scene.instantiate() as Player
	if game_current_player_instance == null:
		push_error("实例化失败或类型不是 Player：请确认 pureslime 根节点脚本 class_name Player")
		return

	# 给一个固定名字（可选，便于调试）
	game_current_player_instance.name = "pureslime"

	# 加入场景树
	game_players_root_node.add_child(game_current_player_instance)

	# 出生点位置
	game_current_player_instance.global_position = game_player_spawn_point.global_position

	# 监听销毁
	game_current_player_instance.tree_exited.connect(_on_game_player_tree_exited)


func _on_game_player_tree_exited() -> void:
	# 玩家被 queue_free 后触发：清理引用
	game_current_player_instance = null
	# 注意：按钮状态由 DebugPanel.gd 自己刷新，这里不再处理任何 UI


# =========================
# 内部：接管场景里已有玩家
# =========================
func _game_find_existing_player_instance() -> Player:
	# 注意：这个函数可能在 Game ready 前被调用（理论上不会，但防御一下）
	if game_players_root_node == null or not is_instance_valid(game_players_root_node):
		return null

	# 优先按固定名字找
	var player_by_name := game_players_root_node.get_node_or_null("pureslime") as Player
	if is_instance_valid(player_by_name):
		return player_by_name

	# 否则遍历容器子节点
	for child in game_players_root_node.get_children():
		if child is Player:
			return child as Player

	return null
