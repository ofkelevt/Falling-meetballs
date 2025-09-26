extends RigidBody3D

@export var gravity_strength: float = 0.2

func _ready() -> void:
	# Disable default gravity so we can apply it manually
	gravity_scale = 0.0
	# Prevent collision responses
	freeze = true

func _physics_process(delta: float) -> void:
	# Apply gravity manually
	var gravity_vec = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	var gravity_val = ProjectSettings.get_setting("physics/3d/default_gravity")
	var move = gravity_vec * gravity_val * gravity_strength * delta
	global_position += move
