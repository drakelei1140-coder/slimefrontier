extends Node2D
class_name EnemyWingsBullet

@export var projectile_move_speed: float = 500.0
@export var projectile_max_range: float = 600.0
@export var projectile_damage_amount: int = 1

@onready var bullet_sprite: Sprite2D = $BulletSprite
@onready var bullet_anim: AnimationPlayer = $AnimationPlayer
@onready var damage_area: Area2D = $Hitbox

var _move_dir: Vector2 = Vector2.RIGHT
var _spawn_global_pos: Vector2
var _is_exploding: bool = false


# director 会调用：projectile_init(move_dir, config)
func projectile_init(move_dir: Vector2, projectile_config: Dictionary) -> void:
	_move_dir = move_dir.normalized()

	if projectile_config.has("projectile_move_speed"):
		projectile_move_speed = float(projectile_config["projectile_move_speed"])
	if projectile_config.has("projectile_max_range"):
		projectile_max_range = float(projectile_config["projectile_max_range"])
	if projectile_config.has("projectile_damage_amount"):
		projectile_damage_amount = int(projectile_config["projectile_damage_amount"])


func _ready() -> void:
	_spawn_global_pos = global_position

	# 自动播放 fly
	if bullet_anim != null and bullet_anim.has_animation("fly"):
		bullet_anim.play("fly")

	# 监听命中（兼容：玩家是 CharacterBody2D / 或玩家用 Area2D Hurtbox）
	if damage_area != null:
		damage_area.body_entered.connect(_on_damage_area_body_entered)
		damage_area.area_entered.connect(_on_damage_area_area_entered)


func _physics_process(delta: float) -> void:
	if _is_exploding:
		return

	# 移动
	global_position += _move_dir * projectile_move_speed * delta
	rotation = _move_dir.angle()

	# 射程：超过就直接消失（不爆炸）
	if global_position.distance_to(_spawn_global_pos) >= projectile_max_range:
		queue_free()


func _on_damage_area_body_entered(body: Node) -> void:
	if _is_exploding or body == null:
		return
	if not body.is_in_group("player"):
		return

	_apply_damage_to_player(body)
	_trigger_explode()


func _on_damage_area_area_entered(area: Area2D) -> void:
	if _is_exploding or area == null:
		return

	# 尝试从 area 往上找“属于 player 组”的节点
	var n: Node = area
	var safety := 0
	while n != null and safety < 6:
		if n.is_in_group("player"):
			_apply_damage_to_player(n)
			_trigger_explode()
			return
		n = n.get_parent()
		safety += 1


func _apply_damage_to_player(player_node: Node) -> void:
	# 尽量对接你已有 ActorBase/Player 的扣血入口（不强依赖具体名字）
	if player_node.has_method("role_apply_damage"):
		player_node.call("role_apply_damage", projectile_damage_amount, global_position)
	elif player_node.has_method("role_take_damage"):
		player_node.call("role_take_damage", projectile_damage_amount, global_position)
	elif player_node.has_method("take_damage"):
		player_node.call("take_damage", projectile_damage_amount)
	elif player_node.has_method("apply_damage"):
		player_node.call("apply_damage", projectile_damage_amount)


func _trigger_explode() -> void:
	_is_exploding = true

	# 关闭判定，防止爆炸动画期间重复命中
	if damage_area != null:
		damage_area.set_deferred("monitoring", false)
		damage_area.set_deferred("monitorable", false)

	# 播放 explode，播完销毁
	if bullet_anim != null and bullet_anim.has_animation("explode"):
		bullet_anim.play("explode")
		bullet_anim.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == &"explode":
		queue_free()
