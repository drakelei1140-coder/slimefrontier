extends Node2D
class_name VisualController

signal die_finished

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $BodySprite

var ghost_follow: PathFollow2D = null
var ghost_root: Node2D = null
var tail_pivot: Node2D = null

var _is_dying := false


func _ready() -> void:
	anim_tree.active = true
	anim_player.animation_finished.connect(_on_animation_finished)

	# --- 安全查找 GhostPath / PathFollow2D ---
	var ghost_path := get_node_or_null("GhostPath") as Path2D
	if ghost_path != null:
		# 不依赖名字：自动取 GhostPath 下第一个 PathFollow2D
		for c in ghost_path.get_children():
			if c is PathFollow2D:
				ghost_follow = c
				break

		if ghost_follow != null:
			ghost_root = ghost_follow.get_node_or_null("GhostRoot") as Node2D
			if ghost_root != null:
				tail_pivot = ghost_root.get_node_or_null("TailPivot") as Node2D

				# 初始隐藏 ghost
				ghost_root.visible = false
				ghost_root.modulate.a = 0.0


func set_move_dir(dir: Vector2) -> void:
	if _is_dying:
		return

	var moving := dir.length() > 0.1
	anim_tree.set("parameters/conditions/is_moving", moving)
	anim_tree.set("parameters/conditions/is_idle", not moving)

	if dir.x > 0.1:
		sprite.flip_h = true
	elif dir.x < -0.1:
		sprite.flip_h = false


func play_die() -> void:
	if _is_dying:
		return
	_is_dying = true

	# 关键：关 AnimationTree，避免它盖掉 die 动画
	anim_tree.active = false

	# 重置 ghost 路径/甩尾（如果节点存在才做）
	if ghost_follow != null:
		ghost_follow.progress_ratio = 0.0

	if ghost_root != null:
		ghost_root.visible = true
		ghost_root.modulate.a = 1.0

	if tail_pivot != null and tail_pivot.has_method("reset_sway"):
		tail_pivot.call("reset_sway")

	anim_player.play("die")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "die":
		die_finished.emit()
