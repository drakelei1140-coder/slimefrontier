# res://scripts/stats/runtime_stats.gd
extends RefCounted
class_name RuntimeStats

signal stats_changed

var level: int = 1

var max_hp: int = 1
var hp: int = 1

var move_speed: float = 0.0
var defense: float = 0.0

func init_from_character_def(character_def: CharacterDef, p_level: int) -> void:
	level = max(1, p_level)

	var hp_f := character_def.hp.eval(level)
	max_hp = max(1, int(round(hp_f)))
	# ✅ 开局满血（不要 clamp 旧值）
	hp = max_hp

	var base_ms := character_def.base_move_speed.eval(level)
	var bonus_pct := character_def.move_speed_bonus_pct.eval(level)
	move_speed = base_ms * (1.0 + bonus_pct)

	defense = character_def.defense.eval(level)

	emit_signal("stats_changed")

func set_hp_full() -> void:
	hp = max_hp
	emit_signal("stats_changed")

func apply_damage(raw_damage: float) -> int:
	var final_damage := _calc_final_damage(raw_damage)
	if final_damage <= 0:
		return 0

	hp = max(0, hp - final_damage)
	emit_signal("stats_changed")
	return final_damage

func is_dead() -> bool:
	return hp <= 0

func _calc_final_damage(raw_damage: float) -> int:
	if raw_damage <= 0.0:
		return 0
	var d := int(floor(raw_damage - defense))
	return max(1, d)
