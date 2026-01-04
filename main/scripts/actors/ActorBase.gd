extends CharacterBody2D
class_name ActorBase
"""
ActorBase：角色/单位的“逻辑层基类”
- 负责：状态机、移动、冲刺（dash）、硬直（stagger）、死亡（dead）、无敌帧判定
- 不负责：具体动画播放细节（交给 VisualController）
- 输入由 Player（或 AI）每帧写入到 input_* 变量
"""

# =========================
# 角色操作状态（Role Operation State）
# =========================
enum RoleOperationState { IDLE, MOVE, DASH, STAGGER, DEAD }

# 当前角色进行中的操作状态
var role_current_operation_state = RoleOperationState.IDLE

# =========================
# 可配置参数（@export：在 Inspector 可调）
# =========================

# 角色基础移动速度（不含 BUFF / 装备加成）
@export var role_base_move_speed: float = 300.0

# ---- Dash（冲刺）参数：冲刺距离 ≈ dash_move_speed * dash_total_duration ----
@export var dash_move_speed: float = 800.0                 # 冲刺速度
@export var dash_total_duration: float = 0.18              # 冲刺总时长
@export var dash_invincible_duration: float = 0.18         # 无敌帧时长（冲刺开始后的前 N 秒）
@export var dash_cooldown_duration: float = 0.80           # 冲刺冷却时长

# ---- Stagger（硬直）参数 ----
@export var stagger_default_duration: float = 0.25         # 默认硬直时间

var dash_invincible_has_ended: bool = false

@export var hit_invincible_duration: float = 0.25


signal runtime_stats_changed

var runtime_stats: RuntimeStats = null

# =========================
# 输入（由外部每帧写入）
# =========================
# 当前帧的移动输入方向（长度可不为 1）
var input_move_direction: Vector2 = Vector2.ZERO

# 本帧是否触发冲刺输入（一次性事件：用完会清掉）
var input_dash_pressed_this_frame: bool = false

# =========================
# 速度修正（以后道具/BUFF 会用到）
# =========================
var role_move_speed_multiplier: float = 1.0               # 乘法加成
var role_move_speed_addition: float = 0.0                 # 加法加成

# =========================
# Dash 运行时状态
# =========================
var dash_elapsed_time_since_start: float = 0.0            # 冲刺开始到现在经过的时间
var dash_move_direction: Vector2 = Vector2.RIGHT          # 冲刺方向（归一化）
var dash_remaining_cooldown_time: float = 0.0             # 冲刺剩余冷却时间

# =========================
# Stagger 运行时状态
# =========================
var stagger_remaining_time: float = 0.0                   # 当前硬直剩余时间
var _hit_invincible_remaining_time: float = 0.0           # 受击冷却剩余时间

# =========================
# 面向与方向记忆
# =========================
# 当前角色面向方向：用于“待机也能冲刺时”的默认冲刺方向
var role_current_facing_direction: Vector2 = Vector2.RIGHT

# 最近一次有效移动方向（可用于别的逻辑，这里保留）
var role_last_nonzero_move_direction: Vector2 = Vector2.RIGHT

# =========================
# 生命值（占位：后续你会接属性系统/配表）
# =========================
var role_current_hp: int = 1

# =========================
# 表现层引用（由 Player 在 _ready 赋值）
# =========================
var role_visual_controller: Node = null


func _ready() -> void:
	# 初始进入 IDLE
	_enter_role_operation_state(RoleOperationState.IDLE)
	
		# 参数保护：无敌帧不能超过 dash 总时长
	if dash_invincible_duration > dash_total_duration:
		push_warning("dash_invincible_duration(%.3f) > dash_total_duration(%.3f). Clamped to dash_total_duration." % [dash_invincible_duration, dash_total_duration])
		dash_invincible_duration = dash_total_duration

	_enter_role_operation_state(RoleOperationState.IDLE)


func role_init_runtime_stats(character_def: CharacterDef, level: int) -> void:
	runtime_stats = RuntimeStats.new()
	runtime_stats.stats_changed.connect(_on_runtime_stats_changed)
	runtime_stats.init_from_character_def(character_def, level)

	# 同步占位字段（避免开局还是 1）
	role_current_hp = runtime_stats.hp

	#role_current_hp = runtime_stats.hp
	#role_base_move_speed = runtime_stats.move_speed

	emit_signal("runtime_stats_changed")



func _on_runtime_stats_changed() -> void:
	emit_signal("runtime_stats_changed")

func _physics_process(delta: float) -> void:
	# -------------------------
	# 1) 冲刺冷却倒计时（每帧递减）
	# -------------------------
	if dash_remaining_cooldown_time > 0.0:
		dash_remaining_cooldown_time = maxf(dash_remaining_cooldown_time - delta, 0.0)

	_update_hit_invincible(delta)

	# -------------------------
	# 2) 更新面向/方向记忆（用于 idle dash 的方向）
	# -------------------------
	if input_move_direction.length() > 0.1:
		var dir := input_move_direction.normalized()
		role_current_facing_direction = dir
		role_last_nonzero_move_direction = dir

	# -------------------------
	# 3) 主状态机分发
	# -------------------------
	match role_current_operation_state:
		RoleOperationState.IDLE:
			_update_state_idle(delta)
		RoleOperationState.MOVE:
			_update_state_move(delta)
		RoleOperationState.DASH:
			_update_state_dash(delta)
		RoleOperationState.STAGGER:
			_update_state_stagger(delta)
		RoleOperationState.DEAD:
			_update_state_dead(delta)

	# -------------------------
	# 4) 清理“一次性输入事件”
	# -------------------------
	input_dash_pressed_this_frame = false


# =========================================================
# 状态更新：IDLE
# =========================================================
func _update_state_idle(_delta: float) -> void:
	# ✅ 待机也允许冲刺
	if input_dash_pressed_this_frame and dash_remaining_cooldown_time <= 0.0:
		_change_role_operation_state(RoleOperationState.DASH)
		return

	# 有移动输入 -> MOVE
	if input_move_direction.length() > 0.1:
		_change_role_operation_state(RoleOperationState.MOVE)
		return

	# 停住（但仍 move_and_slide 让碰撞稳定）
	velocity = Vector2.ZERO
	move_and_slide()

	# 表现层：idle（传 0 向量即可）
	visual_set_move_direction(Vector2.ZERO)


# =========================================================
# 状态更新：MOVE
# =========================================================
func _update_state_move(_delta: float) -> void:
	# MOVE 期间也允许冲刺
	if input_dash_pressed_this_frame and dash_remaining_cooldown_time <= 0.0:
		_change_role_operation_state(RoleOperationState.DASH)
		return

	# 无输入 -> IDLE
	if input_move_direction.length() <= 0.1:
		_change_role_operation_state(RoleOperationState.IDLE)
		return

	# 移动速度（含加成）
	var move_speed := get_role_current_move_speed()
	velocity = input_move_direction.normalized() * move_speed
	move_and_slide()

	# 表现层：walk + 翻转
	visual_set_move_direction(input_move_direction)


# =========================================================
# 状态更新：DASH
# =========================================================
func _update_state_dash(delta: float) -> void:
	# 累计 dash 时间
	dash_elapsed_time_since_start += delta

	# ✅ 稳定检测：无敌帧是否已经结束（只会触发一次）
	if not dash_invincible_has_ended \
		and dash_elapsed_time_since_start >= dash_invincible_duration:
		dash_invincible_has_ended = true
		role_on_invincibility_ended()

	# 冲刺移动
	velocity = dash_move_direction * dash_move_speed
	move_and_slide()

	# 表现层：保持方向
	visual_set_move_direction(dash_move_direction)

	# Dash 结束：关残影 -> 回到 MOVE / IDLE
	if dash_elapsed_time_since_start >= dash_total_duration:
		visual_stop_dash_afterimage()

		if input_move_direction.length() > 0.1:
			_change_role_operation_state(RoleOperationState.MOVE)
		else:
			_change_role_operation_state(RoleOperationState.IDLE)


# =========================================================
# 状态更新：STAGGER（硬直）
# =========================================================
func _update_state_stagger(delta: float) -> void:
	stagger_remaining_time -= delta

	# 硬直期间不移动
	velocity = Vector2.ZERO
	move_and_slide()

	# 表现层：通常停住/受击动作（当前先让它 idle）
	visual_set_move_direction(Vector2.ZERO)

	# 硬直结束：按输入决定回 MOVE/IDLE
	if stagger_remaining_time <= 0.0:
		if input_move_direction.length() > 0.1:
			_change_role_operation_state(RoleOperationState.MOVE)
		else:
			_change_role_operation_state(RoleOperationState.IDLE)


# =========================================================
# 状态更新：DEAD
# =========================================================
func _update_state_dead(_delta: float) -> void:
	# 死亡后不再移动
	velocity = Vector2.ZERO
	move_and_slide()


# =========================================================
# 状态切换：统一入口
# =========================================================
func _change_role_operation_state(new_state) -> void:
	if role_current_operation_state == new_state:
		return

	_exit_role_operation_state(role_current_operation_state)
	role_current_operation_state = new_state
	_enter_role_operation_state(role_current_operation_state)


func _enter_role_operation_state(state_to_enter) -> void:
	match state_to_enter:
		RoleOperationState.DASH:
			_enter_dash_state()
		RoleOperationState.STAGGER:
			_enter_stagger_state()
		RoleOperationState.DEAD:
			_enter_dead_state()
		_:
			pass


func _exit_role_operation_state(_state_to_exit) -> void:
	# 当前版本不需要 exit 行为，留接口以后扩展（例如退出dash时的收尾动作）
	pass


# =========================================================
# 进入 DASH：初始化方向/计时/CD，并开残像
# =========================================================
func _enter_dash_state() -> void:
	dash_elapsed_time_since_start = 0.0

	# Dash 方向：
	# - 如果当前有输入，用输入方向
	# - 否则用角色当前面向（待机冲刺）
	if input_move_direction.length() > 0.1:
		dash_move_direction = input_move_direction.normalized()
	else:
		dash_move_direction = role_current_facing_direction.normalized()

	# 进入 dash 即开始冷却
	dash_remaining_cooldown_time = dash_cooldown_duration

	# 表现：开冲刺残影
	visual_start_dash_afterimage()
	dash_invincible_has_ended = false

func _dash_force_terminate_and_restart_cooldown() -> void:
	# 1) 立刻关残影（解决“残影一直生成”）
	visual_stop_dash_afterimage()

	# 2) 强制把 dash 视为结束（清理计时器，避免你以后加别的 dash 逻辑时残留）
	dash_elapsed_time_since_start = 0.0

	# 3) 冷却时间重置为完整 CD（你要的“进入新的 CD 时间”）
	dash_remaining_cooldown_time = dash_cooldown_duration


func _enter_stagger_state() -> void:
	# 兜底：无论从哪里进入硬直，都确保残影关掉
	visual_stop_dash_afterimage()

	velocity = Vector2.ZERO
	move_and_slide()

	# 如果你已经在 VisualController.gd 实现了 visual_play_stagger_animation，就在这里调用
	if is_instance_valid(role_visual_controller) and role_visual_controller.has_method("visual_play_stagger_animation"):
		role_visual_controller.call("visual_play_stagger_animation")


func _enter_dead_state() -> void:
	# 死亡时确保残影关掉
	visual_stop_dash_afterimage()

	velocity = Vector2.ZERO
	move_and_slide()

	# 表现层播放死亡动画
	if is_instance_valid(role_visual_controller) and role_visual_controller.has_method("visual_play_die_animation"):
		role_visual_controller.call("visual_play_die_animation")


# =========================================================
# 对外接口：移动速度
# =========================================================
func get_role_current_move_speed() -> float:
	var base_speed := role_base_move_speed
	if runtime_stats != null:
		base_speed = runtime_stats.move_speed
	return base_speed * role_move_speed_multiplier + role_move_speed_addition


# =========================================================
# 对外接口：无敌判定（Dash 无敌帧）
# =========================================================
func role_is_currently_invincible() -> bool:
	var dash_invincible_active: bool = (
		role_current_operation_state == RoleOperationState.DASH
		and dash_elapsed_time_since_start <= dash_invincible_duration
	)
	return dash_invincible_active or _is_hit_invincible_active()

# =========================================================
# Dash 无敌帧结束后的“重叠补算受击”
# =========================================================
func role_on_invincibility_ended() -> void:
	# 延迟到物理帧之后，确保 overlaps 数据是最新的
	call_deferred("_role_apply_overlap_hit_if_needed")


func _role_apply_overlap_hit_if_needed() -> void:
	# 如果又进入无敌、或已经死亡，就不处理
	if role_current_operation_state == RoleOperationState.DEAD:
		return
	if role_is_currently_invincible():
		return

	var role_hurtbox := get_node_or_null("Hurtbox") as HurtboxPlayer
	if role_hurtbox == null:
		return

	var hitbox := role_hurtbox.hurtbox_get_any_overlapping_enemy_hitbox()
	if hitbox == null:
		return

	role_apply_hit(
		hitbox.hitbox_get_damage(),
		hitbox.hitbox_get_stagger()
	)



# =========================================================
# 对外接口：受击入口（敌人/子弹统一调用这里）
# =========================================================
func role_apply_hit(damage: int, stagger_duration: float = -1.0) -> void:
	# 已死不处理
	if role_current_operation_state == RoleOperationState.DEAD:
		return

	# 无敌帧：直接忽略伤害和硬直
	if role_is_currently_invincible():
		return

	# -------------------------
	# 扣血（接入 RuntimeStats）
	# -------------------------
	var _applied_damage: int = damage

	if runtime_stats != null:
		_applied_damage = runtime_stats.apply_damage(damage)
		# 如果你还保留 role_current_hp 用于旧 UI/调试，这里同步一下（可选）
		role_current_hp = runtime_stats.hp
	else:
		# 兼容旧逻辑
		role_current_hp -= damage

	# 死亡优先
	if (runtime_stats != null and runtime_stats.is_dead()) or (runtime_stats == null and role_current_hp <= 0):
		role_die()
		return

	# 硬直时间：不传就用默认
	var final_stagger := stagger_duration
	if final_stagger < 0.0:
		final_stagger = stagger_default_duration

	# 刷新硬直（不叠加，只刷新剩余时间）
	if final_stagger > 0.0:
		# 如果当前正在 DASH（且能进到这里说明已经不是无敌帧），那么硬直会打断 dash
		if role_current_operation_state == RoleOperationState.DASH:
			_dash_force_terminate_and_restart_cooldown()

		stagger_remaining_time = maxf(final_stagger, 0.0)
		_change_role_operation_state(RoleOperationState.STAGGER)

	_start_hit_invincible()

func apply_damage(damage_amount: int, _source: Node = null) -> void:
	role_apply_hit(damage_amount, 0.0)


# =========================================================
# 对外接口：死亡
# =========================================================
func role_die() -> void:
	if role_current_operation_state == RoleOperationState.DEAD:
		return
	_change_role_operation_state(RoleOperationState.DEAD)


# =========================================================
# 表现层调用封装（避免到处写 has_method）
# =========================================================
func visual_set_move_direction(direction: Vector2) -> void:
	if is_instance_valid(role_visual_controller) and role_visual_controller.has_method("visual_set_move_direction"):
		role_visual_controller.call("visual_set_move_direction", direction)


func visual_start_dash_afterimage() -> void:
	if is_instance_valid(role_visual_controller) and role_visual_controller.has_method("visual_start_dash_afterimage"):
		role_visual_controller.call("visual_start_dash_afterimage")


func visual_stop_dash_afterimage() -> void:
	if is_instance_valid(role_visual_controller) and role_visual_controller.has_method("visual_stop_dash_afterimage"):
		role_visual_controller.call("visual_stop_dash_afterimage")

func visual_play_stagger_animation() -> void:
	if is_instance_valid(role_visual_controller) and role_visual_controller.has_method("visual_play_stagger_animation"):
		role_visual_controller.call("visual_play_stagger_animation")

func role_get_move_speed() -> float:
	if runtime_stats != null:
		return runtime_stats.move_speed
	return 0.0


func _is_hit_invincible_active() -> bool:
	return _hit_invincible_remaining_time > 0.0


func _start_hit_invincible() -> void:
	if hit_invincible_duration <= 0.0:
		return
	_hit_invincible_remaining_time = hit_invincible_duration


func _update_hit_invincible(delta: float) -> void:
	if _hit_invincible_remaining_time <= 0.0:
		return
	_hit_invincible_remaining_time = maxf(_hit_invincible_remaining_time - delta, 0.0)
