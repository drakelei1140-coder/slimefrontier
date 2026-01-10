extends Node2D
class_name EnemyVisualController

signal die_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_dead: bool = false

# ✅ 新增：硬直兜底计时（秒）
@export var stagger_fallback_duration: float = 0.15
var _stagger_token: int = 0


func _ready() -> void:
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_finished)


func apply_state(state: String) -> void:
	if animation_player == null or not is_instance_valid(animation_player):
		return
	if is_dead:
		return

	if state == "die":
		is_dead = true
		animation_player.play("die")
		return

	if not animation_player.has_animation(state):
		return

	animation_player.play(state)

	# ✅ 关键：stagger 即使 loop，也强制在 0.15s 后回 walk
	if state == "stagger":
		_stagger_token += 1
		var my := _stagger_token
		_call_end_stagger_later(my)


func _call_end_stagger_later(my_token: int) -> void:
	# 用 timer 而不是依赖 animation_finished
	var t := get_tree().create_timer(stagger_fallback_duration)
	t.timeout.connect(func() -> void:
		if is_dead:
			return
		if my_token != _stagger_token:
			return
		# 如果此时正在 attack，就不抢状态（避免打断攻击）
		if animation_player.current_animation == "attack":
			return
		if animation_player.has_animation("walk"):
			animation_player.play("walk")
	)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"die":
		die_finished.emit()
		return

	if is_dead:
		return

	if anim_name == &"attack" or anim_name == &"stagger":
		if animation_player.has_animation("walk"):
			animation_player.play("walk")
