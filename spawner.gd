# Spawns a scene at local y=0 within radius, forever, with downward random velocity.
extends Node3D

@export var thing_scene: PackedScene
@export var radius: float = 5.0
@export var spawn_time: float = 0.5
@export var speed_min: float = 5.0
@export var speed_max: float = 15.0

var _rng := RandomNumberGenerator.new()
var _timer: Timer

func _ready() -> void:
	_rng.randomize()
	_timer = Timer.new()
	_timer.wait_time = spawn_time
	_timer.autostart = true
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(_spawn_one)

func _spawn_one() -> void:
	if thing_scene == null:
		return

	# random local point on XZ disk (y=0)
	var p := _random_point_in_disk(radius)
	var local_pos := Vector3(p.x, 0.0, p.y)
	var world_pos := to_global(local_pos)

	# random downward unit direction (lower hemisphere)
	var dir := _random_down_unit()
	var speed := _rng.randf_range(speed_min, speed_max)
	var vel := dir * speed

	var inst := thing_scene.instantiate()
	get_tree().current_scene.add_child(inst)
	_set_world_position(inst, world_pos)
	_try_set_velocity(inst, vel)

func _random_point_in_disk(r: float) -> Vector2:
	# uniform over disk via polar sampling
	var theta := _rng.randf_range(0.0, TAU)
	var u := _rng.randf() # [0,1)
	var rr := r * sqrt(u)
	return Vector2(rr * cos(theta), rr * sin(theta))

func _random_down_unit() -> Vector3:
	# sample unit vector in lower hemisphere (y <= 0)
	var phi := _rng.randf_range(0.0, TAU)
	var u := _rng.randf_range(0.0, 1.0)  # cos(theta) over [0,1]; map to [0,1] for lower hemi
	var y := -u                          # y in [-1,0]
	var s := sqrt(max(0.0, 1.0 - y*y))
	return Vector3(s * cos(phi), y, s * sin(phi)).normalized()

func _set_world_position(node: Node, pos: Vector3) -> void:
	if node is Node3D:
		node.global_position = pos
	elif "global_position" in node:
		node.global_position = pos

func _try_set_velocity(node: Node, v: Vector3) -> void:
	# Common cases: RigidBody3D.linear_velocity, CharacterBody3D.velocity, custom "velocity"
	if node is RigidBody3D:
		node.linear_velocity = v
	elif node is CharacterBody3D:
		node.velocity = v
	elif "linear_velocity" in node:
		node.linear_velocity = v
	elif "velocity" in node:
		node.velocity = v
	# If the root is a wrapper, try first child Node3D
	elif node.get_child_count() > 0 and node.get_child(0) is Node:
		_try_set_velocity(node.get_child(0), v)
