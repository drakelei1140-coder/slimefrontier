extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

func _ready() -> void:
	var role_hurtbox: HurtboxEnemy = $Hurtbox as HurtboxEnemy
	if is_instance_valid(role_hurtbox):
		role_hurtbox.hurtbox_hit.connect(_on_role_hurtbox_hit)


func _on_role_hurtbox_hit(damage: int, stagger: float, _source: Node) -> void:
	# 如果 Enemy_01 也继承 ActorBase，那就直接：
	# role_apply_hit(damage, stagger)
	# 否则先打印验证链路通不通：
	print("Enemy hit! damage=", damage, " stagger=", stagger)

func _physics_process(delta: float) -> void:
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
