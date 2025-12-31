# res://scripts/data/character_def.gd
extends Resource
class_name CharacterDef

@export var character_id: StringName
@export var name_zh_cn: String = ""

# M1-2 最小闭环字段
@export var hp: StatScalar = StatScalar.new()
@export var base_move_speed: StatScalar = StatScalar.new()
@export var move_speed_bonus_pct: StatScalar = StatScalar.new()
@export var defense: StatScalar = StatScalar.new()
