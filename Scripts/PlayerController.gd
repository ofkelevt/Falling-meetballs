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
@export var air_friction: float = 2.0
@export var over_speed_friction: float = 40.0

var _pitch := 0.0
var _move_dir := Vector3.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity * 0.001)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity * 0.001, deg_to_rad(-80.0), deg_to_rad(80.0))
		if camera:
			camera.rotation.x = _pitch
			camera.rotation.y -= event.relative.x * mouse_sensitivity * 0.001

func _process(_dt: float) -> void:
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
	if(Input.is_action_just_pressed("jump")):
		print_debug("jumped")
	if Input.is_action_just_pressed("jump") and is_on_floor():
		# v0' = v0 / apex_time_scale
		velocity.y = jump_force / max(apex_time_scale, 0.001)

func _physics_process(dt: float) -> void:
	# Gravity adjustments
	if not is_on_floor():
		if velocity.y <= 0.0:
			velocity.y += fall_multiplier * ProjectSettings.get_setting("physics/3d/default_gravity") * dt * -1.0
		elif velocity.y > 0.0:
			var ascent_multiplier := 1.0 / (apex_time_scale * apex_time_scale)
			velocity.y += (ascent_multiplier - 1.0) * ProjectSettings.get_setting("physics/3d/default_gravity") * dt * -1.0
	if velocity.y < max_fall_speed:
		velocity.y = max_fall_speed

	# Horizontal friction or acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _move_dir == Vector3.ZERO:
		var fric := ground_friction if is_on_floor() else air_friction
		var to := horizontal.move_toward(Vector3.ZERO, fric * dt)
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
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		printt("hit", c.get_collider(), "normal", c.get_normal())
