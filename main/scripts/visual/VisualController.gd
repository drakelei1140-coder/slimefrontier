extends Node2D
class_name VisualController
"""
VisualController：表现层控制器
- 负责：AnimationTree 的 idle/walk 切换、朝向翻转、死亡动画播放、dash残像生成
- 不负责：角色逻辑（状态机、无敌帧、CD 等都在 ActorBase）
"""
@export var visual_default_body_texture: Texture2D

signal die_finished

@onready var visual_animation_tree: AnimationTree = $AnimationTree
@onready var visual_animation_player: AnimationPlayer = $AnimationPlayer
@onready var visual_body_sprite: Sprite2D = $BodySprite


# Ghost 相关（死亡动画用）
var ghost_follow_pathfollow: PathFollow2D = null
var ghost_root_node: Node2D = null
var ghost_tail_pivot_node: Node2D = null

var visual_is_playing_die: bool = false
var visual_is_playing_stagger: bool = false

# =========================
# Dash Afterimage（冲刺残像）参数
# =========================
@export var dash_afterimage_enabled: bool = true
@export var dash_afterimage_spawn_interval: float = 0.05
@export var dash_afterimage_lifetime: float = 0.20
@export var dash_afterimage_max_count: int = 5
@export var dash_afterimage_alpha_start: float = 0.70
@export var dash_afterimage_alpha_end: float = 0.15
@export var dash_afterimage_scale: float = 1.0

# 贴图默认朝向：
# true  = 贴图默认朝右
# false = 贴图默认朝左（很多日系横版素材是这个）
@export var visual_sprite_default_faces_right: bool = true

var dash_afterimage_timer: float = 0.0
var dash_afterimage_active: bool = false
var dash_afterimage_root: Node2D = null


func _ready() -> void:
	visual_animation_tree.active = true
	visual_animation_player.animation_finished.connect(_on_animation_finished)

	_resolve_ghost_nodes()
	_resolve_afterimage_root()

	# 初始隐藏 ghost
	if ghost_root_node != null:
		ghost_root_node.visible = false
		var m := ghost_root_node.modulate
		m.a = 0.0
		ghost_root_node.modulate = m

	# 如果运行时 BodySprite.texture 为空，用默认贴图兜底
	if visual_body_sprite.texture == null and visual_default_body_texture != null:
		visual_body_sprite.texture = visual_default_body_texture

func _process(delta: float) -> void:
	# 冲刺残像运行：active 时按间隔生成
	if not dash_afterimage_active:
		return
	if not dash_afterimage_enabled:
		return
	if dash_afterimage_root == null:
		return
	if visual_body_sprite == null or visual_body_sprite.texture == null:
		return

	dash_afterimage_timer += delta
	if dash_afterimage_timer >= dash_afterimage_spawn_interval:
		dash_afterimage_timer = 0.0
		_spawn_dash_afterimage()


# =========================================================
# 对外接口：根据移动方向切换动画 + 翻转朝向
# =========================================================
func visual_set_move_direction(dir: Vector2) -> void:
	# 死亡表现中，不再让 idle/walk 覆盖 die
	if visual_is_playing_die:
		return

	var moving := dir.length() > 0.1

	# 你的 AnimationTree 里需要有：
	# parameters/conditions/is_moving
	# parameters/conditions/is_idle
	visual_animation_tree.set("parameters/conditions/is_moving", moving)
	visual_animation_tree.set("parameters/conditions/is_idle", not moving)

	# 朝向：只用 X 翻转（避免上下移动乱翻）
	if dir.x > 0.1:
		# 想让角色面向右
		visual_body_sprite.flip_h = not visual_sprite_default_faces_right
	elif dir.x < -0.1:
		# 想让角色面向左
		visual_body_sprite.flip_h = visual_sprite_default_faces_right


# =========================================================
# 对外接口：播放死亡动画（AnimationPlayer：die）
# =========================================================
func visual_play_die_animation() -> void:
	if visual_is_playing_die:
		return
	visual_is_playing_die = true

	# 死亡时关残像（避免残像继续生成）
	visual_stop_dash_afterimage()

	# 关键：关闭 AnimationTree，避免它覆盖 die
	visual_animation_tree.active = false

	# 重置 ghost 轨道起点（如果存在）
	if ghost_follow_pathfollow != null:
		ghost_follow_pathfollow.progress_ratio = 0.0

	# 显示 ghost
	if ghost_root_node != null:
		ghost_root_node.visible = true
		var m := ghost_root_node.modulate
		m.a = 1.0
		ghost_root_node.modulate = m

	# 重置尾巴（如果你挂了 tail_pivot.gd 并实现了 reset_*）
	if ghost_tail_pivot_node != null and ghost_tail_pivot_node.has_method("reset_tail_sway_state"):
		ghost_tail_pivot_node.call("reset_tail_sway_state")

	# 播 die 动画（你说你已有 die 动画）
	visual_animation_player.play("die")

#func visual_play_stagger_animation() -> void:
	#if visual_is_playing_die:
		#return
	#if visual_is_playing_stagger:
		#return
	#if visual_animation_player == null or not is_instance_valid(visual_animation_player):
		#return
	#if not visual_animation_player.has_animation("stagger"):
		#return
#
	#visual_is_playing_stagger = true
#
	## 避免 AnimationTree 覆盖 AnimationPlayer 的 stagger
	#var visual_cached_tree_active := visual_animation_tree.active
	#visual_animation_tree.active = false
#
	#visual_animation_player.play("stagger")
#
	## 等待 stagger 播完（0.05s）
	#while true:
		#var finished_name: StringName = await visual_animation_player.animation_finished
		#if finished_name == &"stagger":
			#break
#
	## 若期间没进入死亡，恢复 AnimationTree
	#if not visual_is_playing_die:
		#visual_animation_tree.active = visual_cached_tree_active
#
	#visual_is_playing_stagger = false

func visual_play_stagger_animation() -> void:
	if visual_is_playing_die:
		return
	if visual_is_playing_stagger:
		return
	if visual_animation_player == null or not is_instance_valid(visual_animation_player):
		return

	# 1) 根据朝向选动画名
	# 面向左：flip_h == visual_sprite_default_faces_right（你之前的转向规则就是这么写的）
	var visual_is_facing_left: bool = (visual_body_sprite.flip_h == visual_sprite_default_faces_right)
	var visual_stagger_anim_name: StringName = &"stagger_left" if visual_is_facing_left else &"stagger"

	# 2) 确认动画存在
	if not visual_animation_player.has_animation(visual_stagger_anim_name):
		# 兜底：没有 stagger_left 时就退回 stagger，避免直接失效
		if visual_stagger_anim_name != &"stagger" and visual_animation_player.has_animation("stagger"):
			visual_stagger_anim_name = &"stagger"
		else:
			return

	visual_is_playing_stagger = true

	# 3) 避免 AnimationTree 覆盖 AnimationPlayer 的 stagger
	var visual_cached_tree_active: bool = visual_animation_tree.active
	visual_animation_tree.active = false

	# 4) 播放
	visual_animation_player.play(visual_stagger_anim_name)

	# 5) 等“当前播放的那一个”播完
	while true:
		var finished_name: StringName = await visual_animation_player.animation_finished
		if finished_name == visual_stagger_anim_name:
			break

	# 6) 恢复 AnimationTree（若期间没进入死亡）
	if not visual_is_playing_die:
		visual_animation_tree.active = visual_cached_tree_active

	visual_is_playing_stagger = false


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"die":
		die_finished.emit()


# =========================================================
# 对外接口：Dash 残像开关
# =========================================================
func visual_start_dash_afterimage() -> void:
	if not dash_afterimage_enabled:
		return
	dash_afterimage_active = true
	dash_afterimage_timer = 0.0
	_spawn_dash_afterimage() # 立刻来一个，视觉更明显


func visual_stop_dash_afterimage() -> void:
	dash_afterimage_active = false
	dash_afterimage_timer = 0.0


# =========================================================
# Dash 残像生成（关键：top_level 固定世界坐标，不跟随父节点飘）
# =========================================================
func _spawn_dash_afterimage() -> void:
	# 维持最大数量：删最老的
	while dash_afterimage_root.get_child_count() >= dash_afterimage_max_count:
		dash_afterimage_root.get_child(0).queue_free()

	var s := Sprite2D.new()
	s.texture = visual_body_sprite.texture
	s.flip_h = visual_body_sprite.flip_h
	s.scale = visual_body_sprite.scale * dash_afterimage_scale

	# ✅ 关键：不继承父节点变换，避免“残影方向/位置不固定”
	s.top_level = true
	s.global_transform = visual_body_sprite.global_transform

	# 透明度梯度：越老越透明
	var idx := dash_afterimage_root.get_child_count()
	var t := float(idx) / maxf(float(dash_afterimage_max_count - 1), 1.0)
	var alpha := lerpf(dash_afterimage_alpha_start, dash_afterimage_alpha_end, t)
	s.modulate = Color(1, 1, 1, alpha)

	dash_afterimage_root.add_child(s)

	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, dash_afterimage_lifetime)
	tw.tween_callback(Callable(s, "queue_free"))


# =========================================================
# 内部：查找 Afterimages 根节点（推荐放在 pureslime 根下）
# =========================================================
func _resolve_afterimage_root() -> void:
	# VisualController 挂在：pureslime/Visual/PureSlimeVisual
	# 所以 get_parent() 是 Visual，再上一级是 pureslime
	var visual_node := get_parent()
	var role_root := visual_node.get_parent() if visual_node != null else null

	if role_root != null:
		dash_afterimage_root = role_root.get_node_or_null("Afterimages") as Node2D


# =========================================================
# 内部：查找 Ghost 链路
# =========================================================
func _resolve_ghost_nodes() -> void:
	# 结构：GhostPath(Path2D) -> (任意 PathFollow2D) -> GhostRoot -> TailPivot
	var ghost_path := get_node_or_null("GhostPath") as Path2D
	if ghost_path == null:
		return

	for c in ghost_path.get_children():
		if c is PathFollow2D:
			ghost_follow_pathfollow = c
			break

	if ghost_follow_pathfollow == null:
		return

	ghost_root_node = ghost_follow_pathfollow.get_node_or_null("GhostRoot") as Node2D
	if ghost_root_node == null:
		return

	ghost_tail_pivot_node = ghost_root_node.get_node_or_null("TailPivot") as Node2D
