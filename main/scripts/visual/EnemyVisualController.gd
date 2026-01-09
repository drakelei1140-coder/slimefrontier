extends Node2D
class_name EnemyVisualController

signal die_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_dead: bool = false


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


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"die":
		die_finished.emit()
		return

	if is_dead:
		return

	if anim_name == &"attack" or anim_name == &"stagger":
		if animation_player.has_animation("walk"):
			animation_player.play("walk")
