extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var attack_cd: float = 3.0
@export var swing_duration: float = 1.0
@export var start_angle_offset: float = -PI / 3.0
@export var hitbox_radius: float = 40.0
@export var attack_damage: int = 2
@export var attack_stagger: float = 0.15
@export var attack_target_group: StringName = &"player"

var _attack_cd_left: float = 0.0
var _swing_active: bool = false
var _swing_elapsed: float = 0.0
var _swing_start_angle: float = 0.0

@onready var attack_hitbox: OneShotDamageDealer = $AttackHitbox

func _ready() -> void:
	attack_hitbox.set_active(false)
	attack_hitbox.damage_amount = attack_damage
	attack_hitbox.stagger_amount = attack_stagger
	attack_hitbox.target_group = attack_target_group

	var role_hurtbox: HurtboxEnemy = $Hurtbox as HurtboxEnemy
	if is_instance_valid(role_hurtbox):
		role_hurtbox.hurtbox_hit.connect(_on_role_hurtbox_hit)


func _on_role_hurtbox_hit(damage: int, stagger: float, _source: Node) -> void:
	# 如果 Enemy_01 也继承 ActorBase，那就直接：
	# role_apply_hit(damage, stagger)
	# 否则先打印验证链路通不通：
	print("Enemy hit! damage=", damage, " stagger=", stagger)

func _physics_process(delta: float) -> void:
	_update_attack(delta)

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _update_attack(delta: float) -> void:
	if _swing_active:
		_swing_elapsed += delta
		_update_attack_hitbox_position()

		if _swing_elapsed >= swing_duration:
			_end_swing()
		return

	_attack_cd_left = maxf(_attack_cd_left - delta, 0.0)
	if _attack_cd_left <= 0.0:
		_start_swing()


func _start_swing() -> void:
	_swing_active = true
	_swing_elapsed = 0.0

	var dir_to_player := _get_direction_to_target()
	_swing_start_angle = dir_to_player.angle() + start_angle_offset

	attack_hitbox.begin_attack()
	attack_hitbox.set_active(true)
	_update_attack_hitbox_position()


func _end_swing() -> void:
	_swing_active = false
	_swing_elapsed = 0.0
	_attack_cd_left = attack_cd
	attack_hitbox.set_active(false)
	attack_hitbox.position = Vector2.ZERO


func _update_attack_hitbox_position() -> void:
	var duration := maxf(swing_duration, 0.001)
	var angle := _swing_start_angle + (_swing_elapsed / duration) * TAU
	attack_hitbox.position = Vector2(cos(angle), sin(angle)) * hitbox_radius


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
