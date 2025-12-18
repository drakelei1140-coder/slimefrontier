extends Node2D

@export var tail_pivot_path: NodePath
@export var bones: Array[NodePath] = []   # TailBone0..TailBone3
@export var tip_multiplier: float = 2.0   # 尾端放大倍数（越大越明显）
@export var response: float = 24.0
@export var damping: float = 18.0

var _pivot: Node2D
var _ang_vel: Array[float] = []

func _ready() -> void:
	_pivot = get_node_or_null(tail_pivot_path) as Node2D
	_ang_vel.resize(bones.size())
	for i in _ang_vel.size():
		_ang_vel[i] = 0.0

func reset_bend() -> void:
	for i in _ang_vel.size():
		_ang_vel[i] = 0.0
	for p in bones:
		var b := get_node_or_null(p) as Bone2D
		if b != null:
			b.rotation = 0.0

func _process(delta: float) -> void:
	if _pivot == null or bones.is_empty():
		return

	var dt := maxf(delta, 0.0001)
	var base := _pivot.rotation  # 直接复用 TailPivot 已经算好的甩动结果

	var n := bones.size()
	for i in range(n):
		var b := get_node_or_null(bones[i]) as Bone2D
		if b == null:
			continue

		var t := float(i) / maxf(float(n - 1), 1.0)
		var target := base * lerpf(0.2, tip_multiplier, t)

		var a := (target - b.rotation) * response - _ang_vel[i] * damping
		_ang_vel[i] += a * dt
		b.rotation += _ang_vel[i] * dt
