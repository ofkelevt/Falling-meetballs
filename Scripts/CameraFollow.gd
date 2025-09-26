extends Node3D

@export var target: Node3D
@export var offset: Vector3 = Vector3.ZERO

func _process(_dt: float) -> void:
	if target:
		global_position = target.global_position + offset
