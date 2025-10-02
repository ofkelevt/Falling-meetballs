extends Camera3D

@export var move_speed: float = 10.0
@export var mouse_sensitivity: float = 0.002

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -1.5, 1.5) # prevent flipping
		rotation = Vector3(pitch, yaw, 0)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	if Input.is_action_pressed("jump"):
		dir += transform.basis.y
	if Input.is_action_pressed("down"):
		dir -= transform.basis.y
	
	if dir != Vector3.ZERO:
		dir = dir.normalized()
		global_position += dir * move_speed * delta
