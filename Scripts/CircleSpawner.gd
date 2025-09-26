extends "res://Spawner.gd"  # inherit from the base spawner above

@export var radius: float = 25.0
@export var no_spawn_radius: float = 10.0
@export var spawn_counter: int = 3
@export var max_attempts: int = 200
@export var relax_step: float = 0.85

var last_spawns: Array[Vector3] = []
var first_spawn: bool = true

func _ready():
	super._ready()

func spawn():
	if spawned_scene == null:
		return

	if first_spawn:
		last_spawns.resize(max(1, spawn_counter))
		var pos = global_transform.origin + rand_point_in_disk(radius)
		last_spawns[0] = pos
		for i in range(1, last_spawns.size()):
			last_spawns[i] = Vector3.INF
		place(pos)
		first_spawn = false
		return

	var min_dist_sqr = no_spawn_radius * no_spawn_radius
	var best = Vector3.ZERO
	var best_score = -1.0

	for attempt in range(max_attempts):
		var candidate = global_transform.origin + rand_point_in_disk(radius)

		# distance to nearest recent spawn
		var min_sqr = INF
		for last in last_spawns:
			var d = candidate.distance_squared_to(last)
			if d < min_sqr:
				min_sqr = d

		if min_sqr >= min_dist_sqr:
			place(candidate)
			return

		if min_sqr > best_score:
			best_score = min_sqr
			best = candidate

		if (attempt + 1) % 40 == 0:
			min_dist_sqr *= relax_step * relax_step

	# fallback
	place(best)

func place(pos: Vector3):
	# shift history
	for i in range(last_spawns.size() - 1, 0, -1):
		last_spawns[i] = last_spawns[i - 1]
	last_spawns[0] = pos

	var obj = spawned_scene.instantiate()
	obj.global_transform.origin = pos
	add_child(obj)

func rand_point_in_disk(r: float) -> Vector3:
	var angle = randf() * TAU
	var dist = sqrt(randf()) * r
	return Vector3(cos(angle) * dist, 0, sin(angle) * dist)
