extends Area2D
class_name HurtboxEnemy

signal hurtbox_hit(damage: int, stagger: float, source: Node)

@export var hurtbox_enabled: bool = true
@export var hurtbox_team: int = 1 # ENEMY
@export var hurtbox_damage_multiplier: float = 1.0


func _ready() -> void:
	area_entered.connect(_on_hurtbox_area_entered)
	_hurtbox_apply_enabled_state()


func hurtbox_set_enabled(value: bool) -> void:
	hurtbox_enabled = value
	_hurtbox_apply_enabled_state()


func _hurtbox_apply_enabled_state() -> void:
	monitoring = hurtbox_enabled
	monitorable = hurtbox_enabled


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not hurtbox_enabled:
		return

	var hitbox_node: Hitbox = area as Hitbox
	if hitbox_node == null:
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

	if hitbox_node.hitbox_get_team() == hurtbox_team:
		return

	var damage: int = hitbox_node.hitbox_get_damage()
	var stagger: float = hitbox_node.hitbox_get_stagger()

	damage = int(round(float(damage) * hurtbox_damage_multiplier))
	hurtbox_hit.emit(damage, stagger, hitbox_node)
