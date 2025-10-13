extends Node3D

@export var sword: MeshInstance3D
@export var blade_surfaces: Array[int] = [0]
@export var charge_time_max: float = 2.0
@export var base_color: Color = Color.WHITE
@export var charged_color: Color = Color.RED
# Animation tuning
@export var charge_spin: float = 13.0
@export var slash_time: float = 0.18
@export var back_time: float  = 0.22
@onready var hold_time: float  = cooldown - back_time - slash_time
@export var slash_delta_x: float = -90.0
@export var slash_delta_z: float = 30
# Dash targets and tuning
@export var player: Node3D					 # set to your player node
@export var dash_speed_min: float = 8.0		# for CharacterBody3D
@export var dash_speed_max: float = 22.0
@export var inDashFrames: int = 5
@export var cooldown: float = 2 
@onready var cooldown_cur: float = 0
@onready var hitbox: Area3D = $HitBox
@onready var cast: ShapeCast3D = $ShapeCast
var _slashing := false
var _hit_once := {}  # track bodies hit this swing
var _charge := 0.0
var _blade_mats: Array[StandardMaterial3D] = []
var _orig_rot_sword: Vector3                # degrees
var _tween: Tween
var _anim_lock := false

func _ready() -> void:
	for i in blade_surfaces:
		var src_mat := sword.mesh.surface_get_material(i)
		var mat := src_mat.duplicate() if (src_mat is StandardMaterial3D) else StandardMaterial3D.new()
		if src_mat is StandardMaterial3D:
			base_color = src_mat.albedo_color
		sword.set_surface_override_material(i, mat)
		_blade_mats.append(mat)
		_orig_rot_sword = rotation_degrees
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _process(delta: float) -> void:
	cooldown_cur -= delta if cooldown_cur > 0 else 0.0
	if Input.is_action_pressed("right click") and visible and cooldown_cur <= 0:
		_charge = clamp(_charge + delta, 0.0, charge_time_max)
		if not _anim_lock:
			var r := _orig_rot_sword
			r.x += charge_spin * _charge / charge_time_max
			rotation_degrees = r
	else:
		_charge = clamp(_charge - 2.0 * delta, 0.0, charge_time_max)
	_update_blade_color()

	# Dash on release
	if Input.is_action_just_released("right click") and visible and _charge > 0.0:
		_do_dash(_charge / charge_time_max)
		_play_release_anim()
		_charge = 0.0

func _update_blade_color() -> void:
	var t := (_charge / charge_time_max)
	var col := base_color.lerp(charged_color, t)
	for mat in _blade_mats:
		mat.albedo_color = col

func _do_dash(t: float) -> void:
	if player == null:
		return
	cooldown_cur = cooldown
	player.inDash = inDashFrames
	# forward = -Z of the player’s basis
	var dir := (-player.global_transform.basis.z).normalized()
	t = clamp(t, 0.0, 1.0)

	if player is CharacterBody3D:
		var p := player as CharacterBody3D
		var add_speed :float = lerp(dash_speed_min, dash_speed_max, t)
		p.velocity = dir * add_speed
func _play_release_anim() -> void:
	_anim_lock = true
	# stop any previous tween
	if _tween and _tween.is_running():
		_tween.kill()
	# compute absolute targets from ORIGINAL rotation
	var target_slash := _orig_rot_sword + Vector3(slash_delta_x, 0.0, slash_delta_z)
	_slashing = true
	_hit_once.clear()
	hitbox.monitoring = true
	cast.enabled = true
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# snap to current orientation first to avoid pops, then tween to slash
	# ensure we start from whatever current rot is, but move toward absolute target
	_tween.tween_property(self, "rotation_degrees", target_slash, slash_time)
	_tween.tween_interval(hold_time)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation_degrees", _orig_rot_sword, back_time)
	_tween.finished.connect(func():
		# enforce exact original orientation and clear lock
			rotation_degrees = _orig_rot_sword
			_anim_lock = false
			hitbox.monitoring = false
			cast.enabled = false
			_slashing = false)

func _physics_process(_dt: float) -> void:
	if _slashing:
		# Sweep between frames to prevent tunneling.
		# Cast from previous to current position of the hitbox.
		var from := cast.global_transform
		# refresh transform before computing displacement
		cast.force_shapecast_update()
		var to := cast.global_transform
		var disp := to.origin - from.origin
		cast.target_position = disp
		cast.force_shapecast_update()
		if cast.is_colliding():
			for i in cast.get_collision_count():
				var b := cast.get_collider(i)
				_register_hit(b)

func _on_hitbox_body_entered(body: Node) -> void:
	_register_hit(body)

func _register_hit(body: Node) -> void:
	if body == null: return
	if body in _hit_once: return
	_hit_once[body] = true
	if body.has_method("apply_damage"):
		body.apply_damage()
	print_debug("hit")
