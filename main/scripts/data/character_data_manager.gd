# res://main/scripts/data/character_data_manager.gd
extends Node
class_name CharacterDataManager

@export var character_db_json_path: String = "res://main/scripts/data/character_base.json"

var _character_defs: Dictionary = {} # StringName -> CharacterDef

func _ready() -> void:
	_load_character_db()

func _load_character_db() -> void:
	_character_defs.clear()

	if not FileAccess.file_exists(character_db_json_path):
		push_error("CharacterDataManager: json not found: %s" % character_db_json_path)
		return

	var fa := FileAccess.open(character_db_json_path, FileAccess.READ)
	var text := fa.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CharacterDataManager: invalid json format: %s" % character_db_json_path)
		return

	for k in parsed.keys():
		var row = parsed[k]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var def := _build_character_def_from_row(row)

		# 兼容：如果 row 里没写 CharacterId/character_id，就用顶层 key 当 id
		if def.character_id == StringName():
			def.character_id = StringName(str(k))

		_character_defs[def.character_id] = def

func get_character_def(character_id: StringName) -> CharacterDef:
	if _character_defs.has(character_id):
		return _character_defs[character_id]
	push_error("CharacterDataManager: character_id not found: %s" % str(character_id))
	return null

func _build_character_def_from_row(row: Dictionary) -> CharacterDef:
	var def := CharacterDef.new()

	# --- 兼容 A/B 两套字段 ---
	var cid = row.get("CharacterId", row.get("character_id", ""))
	def.character_id = StringName(str(cid))

	def.name_zh_cn = str(row.get("Name_zhCN", row.get("name_zhCN", "")))

	# M1-2 最小闭环字段（B版是 Hp / BaseMoveSpeed / MoveSpeedBonusPct / Defense）
	def.hp = StatScalar.from_cell(row.get("Hp", row.get("hp")))
	def.base_move_speed = StatScalar.from_cell(row.get("BaseMoveSpeed", row.get("base_move_speed")))
	def.move_speed_bonus_pct = StatScalar.from_cell(row.get("MoveSpeedBonusPct", row.get("move_speed_bonus_pct")))
	def.defense = StatScalar.from_cell(row.get("Defense", row.get("defense")))

	return def
