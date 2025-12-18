extends Node2D

@export var player_scene: PackedScene  # 拖入 res://.../pureslime.tscn

@onready var players_root: Node = $Entities/Players
@onready var spawn_point: Node2D = $SpawnPoint

var btn_respawn: Button
var btn_die: Button

var player: Player = null


func _ready() -> void:
	# 1) 找按钮（兼容两种UI层级）
	btn_respawn = _find_button([
		"UI/DebugRoot/DebugPanel/slimeResurrection",
	])
	btn_die = _find_button([
		"UI/DebugRoot/DebugPanel/slimeDie",
	])

	if btn_respawn == null or btn_die == null:
		push_error("找不到按钮：请检查 slimeResurrection / slimeDie 的节点路径")
		return

	# 2) 绑定按钮事件
	btn_respawn.pressed.connect(_on_respawn_pressed)
	btn_die.pressed.connect(_on_die_pressed)

	# 3) 启动时：如果场景里已经有玩家（你手动放的），就抓引用
	#    否则自动生成一个（推荐用于你现在的调试流程）
	player = _find_existing_player()
	if is_instance_valid(player):
		player.tree_exited.connect(_on_player_exited)
	else:
		_spawn_player()  # 如果你希望开局没有角色，把这行注释掉

	_update_buttons()


func _on_die_pressed() -> void:
	# 规则5：没角色时点【死亡】无效
	if not is_instance_valid(player):
		return

	player.die()
	_update_buttons()


func _on_respawn_pressed() -> void:
	# 规则4：有角色时点【重生】无效（包括正在DYING但还没消失）
	if is_instance_valid(player):
		return

	_spawn_player()
	_update_buttons()


func _spawn_player() -> void:
	if player_scene == null:
		push_error("player_scene 没有设置：请在 Game 节点 Inspector 里拖入 pureslime.tscn（PackedScene）")
		return

	player = player_scene.instantiate() as Player
	if player == null:
		push_error("实例化失败或类型不是 Player：请确认 pureslime 根节点脚本 extends Player")
		return

	player.name = "pureslime"
	players_root.add_child(player)
	player.global_position = spawn_point.global_position
	player.tree_exited.connect(_on_player_exited)


func _on_player_exited() -> void:
	player = null
	_update_buttons()


func _update_buttons() -> void:
	var has_player := is_instance_valid(player)
	btn_respawn.disabled = has_player
	btn_die.disabled = not has_player


func _find_existing_player() -> Player:
	# 你可以按名字找（如果你坚持固定叫 pureslime）
	var p := players_root.get_node_or_null("pureslime") as Player
	if is_instance_valid(p):
		return p

	# 更稳：找 Players 节点下任意一个 Player（以后多角色也不怕）
	for c in players_root.get_children():
		if c is Player:
			return c as Player

	return null


func _find_button(paths: Array[String]) -> Button:
	for p in paths:
		var n := get_node_or_null(p)
		if n is Button:
			return n as Button
	return null
