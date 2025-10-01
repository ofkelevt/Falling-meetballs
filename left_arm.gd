# LeftArmExtend.gd
extends Node3D

@export var extend_speed: float = 2.0  # units/sec

@onready var left_cable: Node3D     = $"left cable"
@onready var left_arm_down: Node3D  = $"left arm down"
var active: int = -1
var def_scale: float
func _ready() -> void:
	def_scale = left_cable.scale.y
func _process(_delta: float) -> void:
	if(Input.is_action_just_pressed("grapling Hook")):
		active = -active
func _physics_process(dt: float) -> void:
	# move "left arm down" along the left arm's +Y direction
	if(left_cable.scale.y > def_scale || active == 1):
		var dir: Vector3 = left_cable.global_transform.basis.y.normalized()
		left_arm_down.global_position -= dir * extend_speed * dt * active

		# grow "left cable" along its local Y (height/length)
		var s := left_cable.scale
		s.y += (extend_speed * dt) * 0.5 * active
		left_cable.scale = s
