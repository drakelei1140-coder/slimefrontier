# res://scripts/data/stat_scalar.gd
extends Resource
class_name StatScalar

@export var base: float = 0.0
@export var per_level: float = 0.0

static func from_cell(value) -> StatScalar:
	var s := StatScalar.new()
	if value == null:
		return s

	# Godot 里 json 读出来可能是 float/int 或 string
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		s.base = float(value)
		s.per_level = 0.0
		return s

	var text := str(value).strip_edges()
	if text == "":
		return s

	var parts := text.split(";", false)
	if parts.size() == 1:
		s.base = float(parts[0])
		s.per_level = 0.0
	else:
		s.base = float(parts[0])
		s.per_level = float(parts[1])
	return s

func eval(level: int) -> float:
	return base + per_level * max(0, level - 1)
