extends Node2D
class_name ProjectileDirector

@onready var projectile_player_root: Node2D = $player
@onready var projectile_player_weapon_root: Node2D = $player/weapon
@onready var projectile_player_skill_root: Node2D = $player/skill
@onready var projectile_enemy_root: Node2D = $enemy


func projectile_spawn_player_weapon(
	weapon_key: StringName,
	projectile_scene: PackedScene,
	spawn_global_pos: Vector2,
	move_dir: Vector2,
	projectile_config: Dictionary
) -> Node:
	return _projectile_spawn_into_bucket(projectile_player_weapon_root, weapon_key, projectile_scene, spawn_global_pos, move_dir, projectile_config)


func projectile_spawn_player_skill(
	skill_key: StringName,
	projectile_scene: PackedScene,
	spawn_global_pos: Vector2,
	move_dir: Vector2,
	projectile_config: Dictionary
) -> Node:
	return _projectile_spawn_into_bucket(projectile_player_skill_root, skill_key, projectile_scene, spawn_global_pos, move_dir, projectile_config)


func projectile_spawn_enemy(
	enemy_key: StringName,
	projectile_scene: PackedScene,
	spawn_global_pos: Vector2,
	move_dir: Vector2,
	projectile_config: Dictionary
) -> Node:
	return _projectile_spawn_into_bucket(projectile_enemy_root, enemy_key, projectile_scene, spawn_global_pos, move_dir, projectile_config)


func _projectile_spawn_into_bucket(
	parent_root: Node2D,
	bucket_key: StringName,
	projectile_scene: PackedScene,
	spawn_global_pos: Vector2,
	move_dir: Vector2,
	projectile_config: Dictionary
) -> Node:
	if parent_root == null:
		return null
	if projectile_scene == null:
		return null

	var bucket_node := _projectile_get_or_create_bucket(parent_root, bucket_key)
	var projectile_node := projectile_scene.instantiate()
	if projectile_node == null:
		return null

	bucket_node.add_child(projectile_node)

	# 统一用 global_position 放置（避免父节点 transform 影响）
	if projectile_node is Node2D:
		(projectile_node as Node2D).global_position = spawn_global_pos

	# 给投射物“方向/初始化”
	if projectile_node.has_method("projectile_init"):
		projectile_node.call("projectile_init", move_dir, projectile_config)

	# 同步常用字段（可选：如果你的投射物脚本有这些变量）
	_projectile_apply_common_config(projectile_node, projectile_config)

	return projectile_node


func _projectile_get_or_create_bucket(parent_root: Node2D, bucket_key: StringName) -> Node2D:
	var key_text := String(bucket_key)
	if key_text.is_empty():
		key_text = "default"

	var existing := parent_root.get_node_or_null(key_text)
	if existing != null and existing is Node2D:
		return existing as Node2D

	var bucket := Node2D.new()
	bucket.name = key_text
	parent_root.add_child(bucket)
	return bucket


func _projectile_apply_common_config(projectile_node: Node, projectile_config: Dictionary) -> void:
	# 这里不强依赖字段存在；存在就赋值
	if projectile_config.has("projectile_move_speed") and ("projectile_move_speed" in projectile_node):
		projectile_node.projectile_move_speed = float(projectile_config["projectile_move_speed"])

	if projectile_config.has("projectile_max_range") and ("projectile_max_range" in projectile_node):
		projectile_node.projectile_max_range = float(projectile_config["projectile_max_range"])

	if projectile_config.has("projectile_damage_amount") and ("projectile_damage_amount" in projectile_node):
		projectile_node.projectile_damage_amount = int(projectile_config["projectile_damage_amount"])
