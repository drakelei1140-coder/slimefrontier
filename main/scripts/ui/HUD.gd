extends Control
class_name HUD

@export var player_path: NodePath  # 可选：手动指定玩家

@onready var hp_bar: TextureProgressBar = $HPBar
@onready var hp_progress_bar: ProgressBar = $HP_ProgressBar
@onready var hp_text: Label = $HP_ProgressBar/HP_Text

var _player: Node = null
var _last_max_hp: float = 1.0

func _ready() -> void:
	# 监听场景树变化：用于“重生后自动绑定新 player”
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

	call_deferred("_try_bind_player")

func _try_bind_player() -> void:
	# 1) Inspector 指定优先
	if player_path != NodePath() and has_node(player_path):
		_set_player(get_node(player_path))
		return

	# 2) 否则找 group=player 的第一个
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		_set_player(p)
	else:
		_set_player(null) # 没找到就清空

func _set_player(p: Node) -> void:
	# 先解绑旧的
	if _player != null:
		if _player.has_signal("runtime_stats_changed"):
			if _player.runtime_stats_changed.is_connected(_refresh_hp_bar):
				_player.runtime_stats_changed.disconnect(_refresh_hp_bar)
		if _player.tree_exiting.is_connected(_on_player_tree_exiting):
			_player.tree_exiting.disconnect(_on_player_tree_exiting)

	_player = p

	# 绑定新的
	if _player != null:
		if _player.has_signal("runtime_stats_changed"):
			if not _player.runtime_stats_changed.is_connected(_refresh_hp_bar):
				_player.runtime_stats_changed.connect(_refresh_hp_bar)
		_player.tree_exiting.connect(_on_player_tree_exiting)

	_refresh_hp_bar()

func _on_player_tree_exiting() -> void:
	# 玩家即将消失：血条保持存在，但显示为空（0/上次最大血）
	_set_bars_value(0.0, _last_max_hp)

func _on_node_added(n: Node) -> void:
	# 重生新 player 出现：自动绑定
	if _player == null and n.is_in_group("player"):
		_set_player(n)

func _on_node_removed(n: Node) -> void:
	# 当前绑定的 player 被移除：立刻清空并等待下一次 node_added
	if n == _player:
		_set_player(null)

func _refresh_hp_bar() -> void:
	if _player == null:
		_set_bars_value(0.0, _last_max_hp)
		return
	if not ("runtime_stats" in _player):
		return

	var rs = _player.runtime_stats
	if rs == null:
		return

	_last_max_hp = max(1.0, float(rs.max_hp))
	_set_bars_value(float(rs.hp), _last_max_hp)

func _set_bars_value(hp: float, max_hp: float) -> void:
	# 旧 TextureProgressBar
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	hp_bar.value = clamp(hp, 0.0, max_hp)

	# 新 ProgressBar
	hp_progress_bar.min_value = 0
	hp_progress_bar.max_value = max_hp
	hp_progress_bar.value = clamp(hp, 0.0, max_hp)

	# 文本：hp/max
	hp_text.text = "%d/%d" % [int(round(hp_progress_bar.value)), int(round(max_hp))]
