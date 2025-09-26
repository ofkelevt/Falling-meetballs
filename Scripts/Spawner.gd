extends Node3D   # use Node2D if 2D

@export var spawned_scene: PackedScene
@export var spawn_rate: float = 1.0
@export var positions: Array[Vector3] = []
@export var relative_position: bool = true
@export var spawn_time_variance: float = 0.0

var current_time: float = 0.0

func _ready():
	# Spawn initial objects
	for pos in positions:
		var spawn_pos = pos
		if( relative_position):
			spawn_pos += global_transform.origin
		var obj = spawned_scene.instantiate()
		obj.global_transform.origin = spawn_pos
		add_child(obj)

func _process(delta: float):
	current_time += delta
	if current_time >= spawn_rate:
		current_time -= spawn_rate
		spawn()
		if spawn_time_variance > 0.0:
			current_time += randf_range(0.0, spawn_time_variance)

func spawn():
	var obj = spawned_scene.instantiate()
	obj.global_transform.origin = global_transform.origin
	add_child(obj)
