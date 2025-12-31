extends Control
class_name HUD

@export var player_path: NodePath  # 可选：如果你想手动拖拽，就用它；不用也行

@onready var hp_bar: TextureProgressBar = $HPBar

var _player: Node = null

func _ready() -> void:
	call_deferred("_bind_player")

func _bind_player() -> void:
	# 1) 优先：Inspector 指定
	if player_path != NodePath() and has_node(player_path):
		_player = get_node(player_path)
	else:
		# 2) 推荐：通过 group 找到 player
		_player = get_tree().get_first_node_in_group("player")

	if _player == null:
		push_error("HUD: player not found. Set player_path or add Player to group 'player'.")
		return

	# 监听 stats 变化
	if _player.has_signal("runtime_stats_changed"):
		# 避免重复连接（你可能会重进场景或重绑定）
		if not _player.runtime_stats_changed.is_connected(_refresh_hp_bar):
			_player.runtime_stats_changed.connect(_refresh_hp_bar)
	else:
		push_error("HUD: player has no signal 'runtime_stats_changed'.")
	
	_refresh_hp_bar()

func _refresh_hp_bar() -> void:
	if _player == null:
		return
	if not ("runtime_stats" in _player):
		return

	var rs = _player.runtime_stats
	if rs == null:
		return

	hp_bar.min_value = 0
	hp_bar.max_value = rs.max_hp
	hp_bar.value = rs.hp
