extends Area2D
class_name HurtboxPlayer

signal hurtbox_hit(damage: int, stagger: float, source: Node)

@export var hurtbox_enabled: bool = true
@export var hurtbox_team: int = 0 # PLAYER
@export var hurtbox_damage_multiplier: float = 1.0

var overlapping_enemy_hitboxes: Array[Hitbox] = []

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	area_entered.connect(_on_hurtbox_area_entered)
	_hurtbox_apply_enabled_state()

func _on_area_entered(area: Area2D) -> void:
	var hitbox := area as Hitbox
	if hitbox == null:
		return
	if hitbox.hitbox_get_team() == 0:
		return

	if not overlapping_enemy_hitboxes.has(hitbox):
		overlapping_enemy_hitboxes.append(hitbox)
		
func _on_area_exited(area: Area2D) -> void:
	var hitbox := area as Hitbox
	if hitbox == null:
		return
	overlapping_enemy_hitboxes.erase(hitbox)

func hurtbox_get_any_overlapping_enemy_hitbox() -> Hitbox:
	if overlapping_enemy_hitboxes.is_empty():
		return null
	return overlapping_enemy_hitboxes[0]

func hurtbox_set_enabled(value: bool) -> void:
	hurtbox_enabled = value
	_hurtbox_apply_enabled_state()


func _hurtbox_apply_enabled_state() -> void:
	monitoring = hurtbox_enabled
	monitorable = hurtbox_enabled


func _on_hurtbox_area_entered(area: Area2D) -> void:

	if not hurtbox_enabled:
		return

	# 优先强类型（Hitbox.gd）
	var hitbox_node: Hitbox = area as Hitbox
	if hitbox_node == null:
		# 兜底：允许只靠 group 的旧实现（但必须有 getter 方法）
		if not area.is_in_group("Hitbox"):
			return
		if not area.has_method("hitbox_get_damage"):
			return

		var damage_fallback: int = int(area.call("hitbox_get_damage"))
		var stagger_fallback: float = float(area.call("hitbox_get_stagger"))
		var team_fallback: int = int(area.call("hitbox_get_team"))

		if team_fallback == hurtbox_team:
			return

		damage_fallback = int(round(float(damage_fallback) * hurtbox_damage_multiplier))
		hurtbox_hit.emit(damage_fallback, stagger_fallback, area)
		return

	# 阵营过滤（避免友伤）
	if hitbox_node.hitbox_get_team() == hurtbox_team:
		return

	var damage: int = hitbox_node.hitbox_get_damage()
	var stagger: float = hitbox_node.hitbox_get_stagger()

	damage = int(round(float(damage) * hurtbox_damage_multiplier))
	hurtbox_hit.emit(damage, stagger, hitbox_node)
