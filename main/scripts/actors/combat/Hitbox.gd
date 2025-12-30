extends Area2D
class_name Hitbox

# =========================
# Inspector 可调参数（基础值）
# =========================
@export var hitbox_enabled: bool = true

@export var hitbox_damage: int = 1
@export var hitbox_stagger: float = 0.05

# 阵营：0=PLAYER, 1=ENEMY（你已同意这个方案）
@export var hitbox_team: int = 0

# 预留：击退/穿透/范围缩放（未来装备/升级改这些即可）
@export var hitbox_knockback: float = 0.0
@export var hitbox_pierce_count: int = 0 # -1 = 无限穿透（按你之前的原则）
@export var hitbox_shape_scale: float = 1.0


func _ready() -> void:
	add_to_group("Hitbox")
	_hitbox_apply_enabled_state()


func hitbox_set_enabled(value: bool) -> void:
	hitbox_enabled = value
	_hitbox_apply_enabled_state()


func _hitbox_apply_enabled_state() -> void:
	# Area2D 的开关：禁用后不会触发 Hurtbox 的 area_entered
	monitoring = hitbox_enabled
	monitorable = hitbox_enabled


# =========================
# Hurtbox 读取用：强类型 getter（避免 get Variant）
# =========================
func hitbox_get_damage() -> int:
	return hitbox_damage

func hitbox_get_stagger() -> float:
	return hitbox_stagger

func hitbox_get_team() -> int:
	return hitbox_team

func hitbox_get_knockback() -> float:
	return hitbox_knockback

func hitbox_get_pierce_count() -> int:
	return hitbox_pierce_count

func hitbox_get_shape_scale() -> float:
	return hitbox_shape_scale
