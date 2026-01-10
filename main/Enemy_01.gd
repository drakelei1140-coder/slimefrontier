extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const TARGET_REFRESH_INTERVAL = 0.5

# =========================
# 近战：旋转 AttackHitbox（已完成）
# =========================
@export var attack_cd: float = 3.0
@export var attack_auto_enabled: bool = true
@export var swing_duration: float = 1.0
@export var start_angle_offset: float = -PI / 3.0
@export var hitbox_radius: float = 50.0
@export var attack_damage: int = 2
@export var attack_stagger: float = 0.15
@export var attack_target_group: StringName = &"player"

@onready var hitbox_sprite: Sprite2D = $AttackHitbox/HitboxSprite
@export var hitbox_sprite_spin_rps: float = 3.0 # revolutions per second（每秒旋转圈数）

# ✅ 新增：敌人硬直持续时间（和角色一样默认 0.15s）
@export var stagger_duration: float = 0.15

# =========================
# 远程：发射投射物（新增）
# =========================
@export var enemy_projectile_auto_enabled: bool = false
@export var enemy_projectile_cd: float = 2.0

# 投射物场景（例如：enemy_wings_bullet.tscn）
@export var enemy_projectile_scene: PackedScene
# 分桶 key（用于 projectile_director/enemy/<bucket_key>）
@export var enemy_projectile_bucket_key: StringName = &"Enemy_01"

# 子弹从“怪物身体前一点点”生成：沿怪物->玩家方向的偏移（可在 Inspector 配）
@export var enemy_projectile_spawn_forward_offset: float = 16.0

# 子弹参数（由投射物脚本读取；director 会把字典传进去）
@export var enemy_projectile_move_speed: float = 500.0
@export var enemy_projectile_max_range: float = 600.0
@export var enemy_projectile_damage_amount: int = 1

# 远程攻击是否在近战挥舞期间禁用（避免两种攻击叠在一起）
@export var enemy_projectile_block_while_swinging: bool = true

# 可选：如果你在 Enemy_01 场景里放一个 Marker2D 叫 ProjectileAnchor，会用它作为发射基准点；
# 没有则回退用自身 global_position。
@onready var enemy_projectile_anchor: Node2D = get_node_or_null("ProjectileAnchor") as Node2D


var _attack_cd_left: float = 0.0
var _swing_active: bool = false
var _swing_elapsed: float = 0.0
var _swing_start_angle: float = 0.0
var _target_refresh_left: float = 0.0
var _target: Node2D = null
var _sprite: Sprite2D = null

# ✅ 新增：硬直计时防抖（避免多次点击导致旧计时回调生效）
var _stagger_token: int = 0

# ✅ 新增：远程攻击 CD
var _enemy_projectile_cd_left: float = 0.0

@onready var attack_hitbox: OneShotDamageDealer = $AttackHitbox
@onready var visual_controller: EnemyVisualController = $Visual/Enemy01Visual as EnemyVisualController


func _ready() -> void:
	_sprite = get_node_or_null("Visual/Enemy01Visual/WingsSprite") as Sprite2D

	attack_hitbox.set_active(false)
	attack_hitbox.damage_amount = attack_damage
	attack_hitbox.stagger_amount = attack_stagger
	attack_hitbox.target_group = attack_target_group

	var role_hurtbox: HurtboxEnemy = $Hurtbox as HurtboxEnemy
	if is_instance_valid(role_hurtbox):
		role_hurtbox.hurtbox_hit.connect(_on_role_hurtbox_hit)

	_attack_cd_left = attack_cd
	_enemy_projectile_cd_left = enemy_projectile_cd


func _on_role_hurtbox_hit(damage: int, stagger: float, _source: Node) -> void:
	# 如果 Enemy_01 也继承 ActorBase，那就直接：
	# role_apply_hit(damage, stagger)
	# 目前先打印，确保链路通
	print("Enemy hit! damage=", damage, " stagger=", stagger)


func _physics_process(delta: float) -> void:
	_update_attack(delta)
	_update_enemy_projectile_attack(delta)
	_update_facing(delta)

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _update_facing(delta: float) -> void:
	if _sprite == null:
		return

	_target_refresh_left -= delta
	if _target_refresh_left <= 0.0 or not is_instance_valid(_target):
		_target = _acquire_target()
		_target_refresh_left = TARGET_REFRESH_INTERVAL

	if _target == null:
		return

	# 规则：敌人在玩家右边 -> 朝左（flip_h=true）；敌人在玩家左边 -> 朝右（flip_h=false）
	_sprite.flip_h = global_position.x > _target.global_position.x


func _acquire_target() -> Node2D:
	var targets := get_tree().get_nodes_in_group("active_player")
	for target in targets:
		var node2d := target as Node2D
		if node2d != null and is_instance_valid(node2d):
			return node2d
	return null


func _update_attack(delta: float) -> void:
	if not attack_auto_enabled:
		return

	if _swing_active:
		_swing_elapsed += delta
		_update_attack_hitbox_position()

		if _swing_elapsed >= swing_duration:
			_end_swing()
		return

	_attack_cd_left = maxf(_attack_cd_left - delta, 0.0)
	if _attack_cd_left <= 0.0:
		_start_swing()


func trigger_attack() -> void:
	if _swing_active:
		return
	_start_swing()


# ✅ 新增：供按钮调用的硬直入口（stagger_duration 后自动回 walk）
func trigger_stagger() -> void:
	_stagger_token += 1
	var my := _stagger_token

	if is_instance_valid(visual_controller):
		visual_controller.apply_state("stagger")

	await get_tree().create_timer(stagger_duration).timeout

	# 如果这期间又触发了新的硬直，旧回调不生效
	if my != _stagger_token:
		return

	if not is_instance_valid(visual_controller):
		return

	# 硬直结束恢复：攻击中则回 attack，否则回 walk
	if _swing_active:
		visual_controller.apply_state("attack")
	else:
		visual_controller.apply_state("walk")


func _start_swing() -> void:
	_swing_active = true
	_swing_elapsed = 0.0

	var dir_to_player := _get_direction_to_target()
	_swing_start_angle = dir_to_player.angle() + start_angle_offset

	if is_instance_valid(visual_controller):
		visual_controller.apply_state("attack")

	attack_hitbox.begin_attack()
	attack_hitbox.set_active(true)
	_update_attack_hitbox_position()


func _end_swing() -> void:
	_swing_active = false
	_swing_elapsed = 0.0
	_attack_cd_left = attack_cd
	attack_hitbox.set_active(false)
	attack_hitbox.position = Vector2.ZERO
	if is_instance_valid(hitbox_sprite):
		hitbox_sprite.rotation = 0.0


func _update_attack_hitbox_position() -> void:
	var duration := maxf(swing_duration, 0.001)
	var angle := _swing_start_angle + (_swing_elapsed / duration) * TAU
	attack_hitbox.position = Vector2(cos(angle), sin(angle)) * hitbox_radius
	# ✅ HitboxSprite 自身顺时针自转：每秒 hitbox_sprite_spin_rps 圈
	if is_instance_valid(hitbox_sprite):
		hitbox_sprite.rotation = _swing_elapsed * TAU * hitbox_sprite_spin_rps


# =========================
# 远程：投射物攻击（新增）
# =========================
func _update_enemy_projectile_attack(delta: float) -> void:
	if not enemy_projectile_auto_enabled:
		return

	if enemy_projectile_block_while_swinging and _swing_active:
		return

	_enemy_projectile_cd_left = maxf(_enemy_projectile_cd_left - delta, 0.0)
	if _enemy_projectile_cd_left <= 0.0:
		enemy_fire_projectile_at_active_player()


# ✅ 对外入口：手动触发一次发射（给 TestDirector / AI 用）
func trigger_projectile_attack() -> void:
	enemy_fire_projectile_at_active_player()


func enemy_fire_projectile_at_active_player() -> void:
	if enemy_projectile_scene == null:
		return

	# 优先使用缓存目标，否则重新获取
	var player_node: Node2D = null
	if is_instance_valid(_target):
		player_node = _target
	else:
		player_node = _acquire_target()

	if player_node == null:
		return

	var from_pos := _get_enemy_projectile_origin_global_pos()
	var to_pos := player_node.global_position
	var fire_dir := (to_pos - from_pos).normalized()
	if fire_dir.length() <= 0.001:
		fire_dir = Vector2.RIGHT

	# 子弹生成点：沿“怪物->玩家”方向向前偏移（可配）
	var spawn_pos := from_pos + fire_dir * enemy_projectile_spawn_forward_offset

	var config := {
		"projectile_move_speed": enemy_projectile_move_speed,
		"projectile_max_range": enemy_projectile_max_range,
		"projectile_damage_amount": enemy_projectile_damage_amount
	}

	# 方案B：通过 group 查找 projectile_director
	var director := get_tree().get_first_node_in_group("projectile_director")
	if director != null and director.has_method("projectile_spawn_enemy"):
		director.call(
			"projectile_spawn_enemy",
			enemy_projectile_bucket_key,
			enemy_projectile_scene,
			spawn_pos,
			fire_dir,
			config
		)
	else:
		# 兜底：没有 director 就直接丢到 current_scene
		var projectile_node := enemy_projectile_scene.instantiate()
		if projectile_node != null:
			get_tree().current_scene.add_child(projectile_node)
			if projectile_node is Node2D:
				(projectile_node as Node2D).global_position = spawn_pos
			if projectile_node.has_method("projectile_init"):
				projectile_node.call("projectile_init", fire_dir, config)

	_enemy_projectile_cd_left = enemy_projectile_cd


func _get_enemy_projectile_origin_global_pos() -> Vector2:
	if is_instance_valid(enemy_projectile_anchor):
		return enemy_projectile_anchor.global_position
	return global_position


func _get_direction_to_target() -> Vector2:
	var targets := get_tree().get_nodes_in_group(attack_target_group)
	for target in targets:
		var node2d := target as Node2D
		if node2d == null:
			continue

		var to_target := node2d.global_position - global_position
		if to_target.length() > 0.001:
			return to_target.normalized()
	return Vector2.RIGHT
