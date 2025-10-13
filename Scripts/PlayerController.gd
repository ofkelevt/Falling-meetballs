extends CharacterBody3D

@export var mouse_sensitivity: float = 2.0
@export var camera: Camera3D
@export var fall_multiplier: float = 2.5
@export var max_fall_speed: float = -20.0
@export var apex_time_scale: float = 0.7
@export var jump_force: float = 15.0

@export var ground_accel: float = 5.0
@export var air_accel: float = 2.0 
@export var max_speed: float = 8.0
@export var ground_friction: float = 20.0
@export var air_drag: float = 2.0
@export var over_speed_friction: float = 40.0
@export var weapons: Array[Node3D]
@export var weapon_switch_cooldown: float = 2.0
@onready var cooldown_cur:float = 0
@export var extend_speed: float = 2.0  # units/sec
@export var rope : MeshInstance3D
var switch_lock : bool = false
var cur_weapon: int = 1
var _pitch := 0.0
var _move_dir := Vector3.ZERO
var _jumped = false;
var collision 
var inDash = 0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	collision = $CollisionShape3D
	for i in range(1,len(weapons)):
		weapons[i].visible = false
	weapons[0].visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity * 0.001)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity * 0.001, deg_to_rad(-80.0), deg_to_rad(80.0))
		if camera:
			camera.rotation.x = _pitch
			camera.rotation.y -= event.relative.x * mouse_sensitivity * 0.001
func _process(dt: float) -> void:
	cooldown_cur -= dt
	switch_lock = not rope.isIdleOrReturning()
	# WASD relative to camera yaw
	var f := (camera.global_transform.basis.z * -1.0) if camera else -global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var r := (camera.global_transform.basis.x) if camera else global_transform.basis.x
	r.y = 0.0
	r = r.normalized()

	var forward := (int(Input.is_action_pressed("move_forward")) - int(Input.is_action_pressed("move_back"))) as float
	var right := (int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))) as float
	_move_dir = (f * forward + r * right)
	if _move_dir.length() > 1.0:
		_move_dir = _move_dir.normalized()

	# Align body yaw to camera yaw
	if camera:
		var yaw := camera.global_transform.basis.get_euler().y
		rotation.y = yaw
	if Input.is_action_just_pressed("jump") and is_on_floor():
		# v0' = v0 / apex_time_scale
		velocity.y = jump_force / max(apex_time_scale, 0.001)
		_jumped = true;
	if collision.position != Vector3.ZERO:
		print_debug("bug")
func select_weapon(num: int):
	if cooldown_cur < 0:
		cooldown_cur = weapon_switch_cooldown
		for i in range(len(weapons)):
			if i != num:
				weapons[i].visible = false
			else: weapons[i].visible = true
		cur_weapon = num if num != cur_weapon else -1
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and not switch_lock:
		var kc = event.keycode
		for i in range(len(weapons)):
			if kc == KEY_1 + i:
				select_weapon(i)
			# add as many as you need
func _physics_process(dt: float) -> void:
	if inDash > 0:
		move_and_slide()
		inDash -= 1
		return
	# Gravity adjustments
	if not is_on_floor():
		if velocity.y <= 0:
			velocity.y -= fall_multiplier * ProjectSettings.get_setting("physics/3d/default_gravity") * dt
		else:
			var ascent_multiplier := 1.0 / (apex_time_scale * apex_time_scale)
			velocity.y += (ascent_multiplier - 1.0) * ProjectSettings.get_setting("physics/3d/default_gravity") * dt * -1.0
	if velocity.y < max_fall_speed:
		velocity.y = max_fall_speed
	if is_on_floor() and not _jumped:
		velocity.y = - ProjectSettings.get_setting("physics/3d/default_gravity") #importent to match the meetball gravity strencth 
	_jumped = false
	# Horizontal friction or acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if not is_on_floor():
		var to := horizontal.move_toward(Vector3.ZERO, air_drag * dt)
		velocity.x = to.x
		velocity.z = to.z
	if _move_dir == Vector3.ZERO and is_on_floor():
		var to := horizontal.move_toward(Vector3.ZERO, ground_friction * dt)
		velocity.x = to.x
		velocity.z = to.z
	else:
		var accel := ground_accel if is_on_floor() else air_accel
		velocity += _move_dir * accel * dt

	# Soft cap
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > max_speed:
		var to2 := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, over_speed_friction * dt)
		velocity.x = to2.x
		velocity.z = to2.y

	move_and_slide()
