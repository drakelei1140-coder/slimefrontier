extends Node
class_name DebugPanel

# 由你在 Inspector 拖拽绑定 Game 节点
@export var ui_debug_game_node_path: NodePath
@export var enemy01_test_director_path: NodePath

@onready var ui_debug_game_node: Node = get_node_or_null(ui_debug_game_node_path)
@onready var enemy01_test_director: Node = get_node_or_null(enemy01_test_director_path)

@onready var ui_debug_button_respawn: Button = $slimeResurrection
@onready var ui_debug_button_die: Button = $slimeDie
@onready var ui_debug_button_stagger: Button = $slimeStagger
@onready var ui_debug_button_spawn_enemy: Button = $BtnSpawnEnemy
@onready var ui_debug_button_kill_enemy: Button = $BtnKillEnemy
@onready var ui_debug_button_stagger_enemy: Button = $BtnStaggerEnemy


func _ready() -> void:
	# 1) 校验 Game 引用
	if ui_debug_game_node == null or not is_instance_valid(ui_debug_game_node):
		push_error("DebugPanel：ui_debug_game_node_path 未绑定或无效，请在 Inspector 把 Game 节点拖进来")
		return

	# 2) 绑定按钮事件（UI -> DebugPanel）
	# 防御：避免重复 connect（偶尔你热重载/重进场景时更稳）
	if not ui_debug_button_respawn.pressed.is_connected(_on_ui_debug_respawn_pressed):
		ui_debug_button_respawn.pressed.connect(_on_ui_debug_respawn_pressed)
	if not ui_debug_button_die.pressed.is_connected(_on_ui_debug_die_pressed):
		ui_debug_button_die.pressed.connect(_on_ui_debug_die_pressed)
	if not ui_debug_button_stagger.pressed.is_connected(_on_ui_debug_stagger_pressed):
		ui_debug_button_stagger.pressed.connect(_on_ui_debug_stagger_pressed)

	# 3) 初始刷新一次可用状态：延后到本帧 ready 链结束后再做
	call_deferred("_ui_debug_refresh_buttons_enabled_state")

	if enemy01_test_director == null or not is_instance_valid(enemy01_test_director):
		push_error("DebugPanel：enemy01_test_director_path 未绑定或无效，请在 Inspector 把 Enemy01TestDirector 节点拖进来")
		return

	if not ui_debug_button_spawn_enemy.pressed.is_connected(_on_ui_debug_spawn_enemy_pressed):
		ui_debug_button_spawn_enemy.pressed.connect(_on_ui_debug_spawn_enemy_pressed)
	if not ui_debug_button_kill_enemy.pressed.is_connected(_on_ui_debug_kill_enemy_pressed):
		ui_debug_button_kill_enemy.pressed.connect(_on_ui_debug_kill_enemy_pressed)
	if not ui_debug_button_stagger_enemy.pressed.is_connected(_on_ui_debug_stagger_enemy_pressed):
		ui_debug_button_stagger_enemy.pressed.connect(_on_ui_debug_stagger_enemy_pressed)

	if enemy01_test_director.has_method("register_debug_buttons"):
		enemy01_test_director.call(
			"register_debug_buttons",
			ui_debug_button_spawn_enemy,
			ui_debug_button_kill_enemy,
			ui_debug_button_stagger_enemy
		)


func _process(_delta: float) -> void:
	# Debug 面板：每帧刷新按钮禁用状态（按钮少，开销可忽略）
	_ui_debug_refresh_buttons_enabled_state()


func _ui_debug_get_current_player_instance() -> Player:
	if ui_debug_game_node == null or not is_instance_valid(ui_debug_game_node):
		return null

	# Game 还没 ready 时，不要调用它的方法（避免 onready 变量还没赋值）
	if not ui_debug_game_node.is_node_ready():
		return null

	if ui_debug_game_node.has_method("game_get_current_player_instance"):
		return ui_debug_game_node.call("game_get_current_player_instance") as Player

	return null


func _ui_debug_is_player_dead_or_dying(player: Player) -> bool:
	if not is_instance_valid(player):
		return true

	# 从 player 上取 role_visual_controller（get 返回 Variant，所以要显式类型 + as）
	var visual_controller: Node = player.get("role_visual_controller") as Node
	if not is_instance_valid(visual_controller):
		return false

	# 读取 visual_is_playing_die（同样是 Variant -> 显式转 bool）
	# 注意：如果变量不存在，get 会返回 null，这里会保持 false
	var is_playing_die: bool = false
	if visual_controller.get("visual_is_playing_die") != null:
		is_playing_die = bool(visual_controller.get("visual_is_playing_die"))

	return is_playing_die


func _ui_debug_refresh_buttons_enabled_state() -> void:
	var player := _ui_debug_get_current_player_instance()
	var has_player := is_instance_valid(player)
	var is_dead_or_dying := false
	if has_player:
		is_dead_or_dying = _ui_debug_is_player_dead_or_dying(player)

	# 复活：只有“没有玩家”时可点
	ui_debug_button_respawn.disabled = has_player

	# 死亡：只有“有玩家且没在死亡流程”时可点（你也可以允许 dying 时仍可点，但这里更符合直觉）
	ui_debug_button_die.disabled = (not has_player) or is_dead_or_dying

	# 硬直：只有“有玩家且没在死亡流程”时可点（符合你规则3+4）
	ui_debug_button_stagger.disabled = (not has_player) or is_dead_or_dying


func _on_ui_debug_respawn_pressed() -> void:
	if ui_debug_game_node == null or not is_instance_valid(ui_debug_game_node):
		return
	if not ui_debug_game_node.is_node_ready():
		return

	if ui_debug_game_node.has_method("game_debug_respawn_player"):
		ui_debug_game_node.call("game_debug_respawn_player")


func _on_ui_debug_die_pressed() -> void:
	var player := _ui_debug_get_current_player_instance()
	if not is_instance_valid(player):
		return
	if _ui_debug_is_player_dead_or_dying(player):
		return

	player.role_die()


func _on_ui_debug_stagger_pressed() -> void:
	var player := _ui_debug_get_current_player_instance()
	if not is_instance_valid(player):
		return
	if _ui_debug_is_player_dead_or_dying(player):
		return

	# 触发“0伤害 + 0.05s 硬直”
	# 规则2：dash 无敌帧期间不会触发（role_apply_hit 内部会挡）
	# 规则3：DEAD 期间不会触发（role_apply_hit 内部会挡）
	player.role_apply_hit(0, 0.05)


func _on_ui_debug_spawn_enemy_pressed() -> void:
	if enemy01_test_director == null or not is_instance_valid(enemy01_test_director):
		return
	if enemy01_test_director.has_method("spawn_enemy"):
		enemy01_test_director.call("spawn_enemy")


func _on_ui_debug_kill_enemy_pressed() -> void:
	if enemy01_test_director == null or not is_instance_valid(enemy01_test_director):
		return
	if enemy01_test_director.has_method("kill_enemy"):
		enemy01_test_director.call("kill_enemy")


func _on_ui_debug_stagger_enemy_pressed() -> void:
	if enemy01_test_director == null or not is_instance_valid(enemy01_test_director):
		return
	if enemy01_test_director.has_method("stagger_enemy"):
		enemy01_test_director.call("stagger_enemy")
