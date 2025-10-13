extends MeshInstance3D
# --- Endpoints and player ---
@export var start_node: Node3D				  # player side
@export var player: Node3D					  # CharacterBody3D or RigidBody3D

# --- Rope params ---
@export var rope_length: float = 12.0		   # fixed length after latch
@export var point_count: int = 24
@export var iterations: int = 10
@export var rope_width: float = 0.04			# for mesh (not shown here)
@export var resolution: int = 8				 # for mesh (not shown here)
@export var release_slack: float = 0.7      # extra length while flying
@export var extend_rate: float = 60.0       # m/s length change rate
@export var latch_extra_slack: float = 0.15 # small slack after latch
@export var bump_add_speed := 18.0   # Δv toward anchor when recalling
@export var bump_impulse   := 0.0    # if >0 and player is RigidBody3D, use impulse
@onready var rope_length_def: float = rope_length  
var eff_length: float = 0.0                 # effective length used for spacing
@export var end_area: Area3D 
@export var extend_speed: float = 80
@export var camera: Camera3D
# --- State ---
enum State { IDLE, FLYING, LATCHED }
var state: State = State.IDLE
var end_follow: Node3D = null				   # moving latch target
var end_local: Vector3 = Vector3.ZERO		   # latch point in target local space
var end_pos: Vector3 = Vector3.ZERO			 # free end world pos when FLYING
var end_vel: Vector3 = Vector3.ZERO
var current: bool = false
@export var end_hand: Node3D
@onready var end: Vector3 =  start_node.global_transform.origin

# --- Integrator (rope) ---
var points: Array[Vector3] = []
var points_old: Array[Vector3] = []
var point_spacing: float = 0.0
var gravity_default: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var return_speed : float = 40.0
@export var return_accel : float = 200.0
var returning: bool = false
const EPS := 1e-4

func _ready() -> void:
	mesh = ArrayMesh.new()
	_update_point_spacing()
	_prepare_points()
	end_area.monitoring = true
	end_area.monitorable = true
	end_area.collision_layer = 1 << 7			# RopeProbe layer
	end_area.collision_mask = (1 << 0) | (1 << 2) # e.g., World|Latchables
	end_area.body_entered.connect(_on_end_body_entered)
	end_area.area_entered.connect(_on_end_area_entered)
	visibility_changed.connect(_on_visibility_changed)
@export var parent: Node3D
func _on_visibility_changed() -> void:
	if parent:
		parent.visible = visible
func _physics_process(delta: float) -> void:
	end_area.global_transform.origin = end_pos  
	if start_node == null:
		return
	var start := start_node.global_transform.origin
	end = _update_end(delta, start)
	if state == State.FLYING:
		var d := start.distance_to(end_pos)
		var target : float = min(rope_length, d + release_slack)	# follow distance + slack
		eff_length = move_toward(eff_length, target, extend_rate * delta)
		eff_length = clamp(eff_length, d, rope_length)	   # never shorter than d, never beyond cap
		_set_spacing_from(eff_length)
	elif state == State.LATCHED:
		_set_spacing_from(rope_length)
	else: # IDLE
		eff_length = 0.0
	_update_points(delta, start, end)

	# 3) Enforce taut behavior on player only when tight
	_tether_player_if_tight(start, end)

	# 4) (Optional) update visual mesh
	if state != State.IDLE:
		_generate_mesh()
	else:
		var am := mesh as ArrayMesh
		if am: am.clear_surfaces()
	if end_hand:
		end_hand.global_position = end
# ---------- genarate mesh----------
# Build Frenet-like frames per point
func _compute_frames() -> Dictionary:
	var tangents: Array[Vector3] = []
	var normals: Array[Vector3] = []

	for i in range(point_count):
		var t: Vector3
		if i == 0:
			t = (points[1] - points[0]).normalized()
		elif i == point_count - 1:
			t = (points[i] - points[i - 1]).normalized()
		else:
			var fwd := (points[i + 1] - points[i]).normalized()
			var bwd := (points[i] - points[i - 1]).normalized()
			t = (fwd + bwd).normalized()
		tangents.append(t)

		if i == 0:
			var up := Vector3.UP if abs(t.dot(Vector3.UP)) < 0.8 else Vector3.FORWARD
			normals.append(up.cross(t).normalized())
		else:
			var t_prev := tangents[i - 1]
			var n_prev := normals[i - 1]
			var axis := t_prev.cross(t)
			if axis.length() < 1e-6:
				normals.append(n_prev)
			else:
				var angle := acos(clamp(t_prev.dot(t), -1.0, 1.0))
				var rot := Basis(axis.normalized(), angle)   # was: basis
				normals.append(rot * n_prev)

	return {"t": tangents, "n": normals}
	
func _generate_mesh() -> void:
	var frames := _compute_frames()
	var tangents: Array[Vector3] = frames["t"]
	var normals: Array[Vector3] = frames["n"]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build ring vertices and indices
	var ring_indices: Array[int] = []
	var ring_vertices: Array[Vector3] = []

	for p in range(point_count):
		var center := points[p]
		var t := tangents[p]
		var n := normals[p]
		var b := n.cross(t).normalized()

		for c in range(resolution):
			var angle := TAU * float(c) / float(resolution)
			var offset := n * sin(angle) * rope_width + b * cos(angle) * rope_width
			ring_vertices.append(center + offset)
		# stitch to previous ring
		if p > 0:
			var prev_base := (p - 1) * resolution
			var cur_base := p * resolution
			for c in range(resolution):
				var c_next := (c + 1) % resolution
				ring_indices.append(prev_base + c)
				ring_indices.append(cur_base + c)
				ring_indices.append(cur_base + c_next)

				ring_indices.append(prev_base + c)
				ring_indices.append(cur_base + c_next)
				ring_indices.append(prev_base + c_next)

	# emit geometry
	for i in range(0, ring_indices.size(), 3):
		var a := ring_vertices[ring_indices[i]]
		var b := ring_vertices[ring_indices[i + 1]]
		var c := ring_vertices[ring_indices[i + 2]]
		var nrm := Plane(a, b, c).normal
		st.set_normal(nrm); st.add_vertex(a)
		st.set_normal(nrm); st.add_vertex(b)
		st.set_normal(nrm); st.add_vertex(c)

	st.generate_normals()
	mesh.clear_surfaces()
	st.commit(mesh)
# ---------- Public control ----------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("right click") and visible:
		shoot()
func shoot() -> void:
	var dir = -camera.global_transform.basis.z
	if state == State.IDLE:
		state = State.FLYING
		end_follow = null
		end_pos = start_node.global_transform.origin
		end_vel = dir.normalized() * extend_speed
	else:
		print_debug("yo")
			  # recalling while FLYING/LATCHED/RETURNING
		var had_anchor := (state == State.LATCHED and end_follow != null)
		var anchor_world :=  end_follow.to_global(end_local) if had_anchor else end_pos

		# detach and start return
		end_follow = null
		state = State.FLYING
		returning = true
		rope_length = rope_length_def

		if had_anchor:
			_bump_player_toward(anchor_world)

func _bump_player_toward(target: Vector3) -> void:
	var start := start_node.global_transform.origin
	var dir := (target - start)
	var L := dir.length()
	if L < 1e-6: return
	dir /= L

	if player is CharacterBody3D:
		var cb := player as CharacterBody3D
		var vel =  dir * bump_add_speed + gravity_default * Vector3.UP
		vel *= max(1, 1.5*rope_length/rope_length_def) 
		cb.velocity += vel
	elif player is RigidBody3D:
		var rb := player as RigidBody3D
		if bump_impulse > 0.0:
			rb.apply_impulse(dir * bump_impulse)	 # Godot 4
		else:
			rb.linear_velocity = rb.linear_velocity + dir * bump_add_speed

func latch_to(target: Node3D, hit_world: Vector3) -> void:
	state = State.LATCHED
	end_follow = target
	end_local = target.to_local(hit_world)

	var start := start_node.global_transform.origin
	var d := start.distance_to(hit_world)
	# cap stays as previous rope_length; freeze current effective length with a bit of slack
	rope_length = min(rope_length, max(d, eff_length) + latch_extra_slack)
	eff_length = rope_length
	_set_spacing_from(rope_length)
	_prepare_points()


func release() -> void:
	state = State.IDLE
	end_follow = null

# ---------- Internals ----------
func _set_spacing_from(L: float) -> void:
	point_spacing = L / float(max(point_count - 1, 1))
func _update_end(delta: float, start: Vector3) -> Vector3:
	match state:
		State.IDLE:
			# keep end at start (no rope)
			end_pos = start
		State.FLYING:
			var r := end_pos - start
			var vstep := end_vel * delta
			var dis := r.length()

			if not returning:
				# went from inside to outside this step
				if dis >= rope_length:
					# clamp to sphere surface
					var n := (r + vstep).normalized()
					end_pos = start + n * rope_length
					# redirect velocity toward start; keep speed or use return_speed
					var speed : float = max(end_vel.length(), return_speed)
					end_vel = -(end_pos - start).normalized() * speed
					returning = true
				else:
					end_pos += vstep
			else:
				# fly back to start with acceleration, then stop
				var dir_back := (start - end_pos).normalized()
				var player_vel : Vector3= _get_player_velocity()
				end_vel = end_vel.move_toward(player_vel + dir_back * return_speed, return_accel * delta)
				end_pos += end_vel * delta
				if end_pos.distance_to(start) <= max(0.1, return_speed * delta):
					end_pos = start
					end_vel = Vector3.ZERO
					returning = false
					state = State.IDLE
		State.LATCHED:
			var t := end_follow
			if t and t.is_inside_tree():
				# follow the exact latch point on a moving target
				end_pos = t.to_global(end_local)
			else:
				state = State.IDLE
				end_pos = start
	return end_pos

func _update_point_spacing() -> void:
	point_spacing = rope_length / float(max(point_count - 1, 1))

func _prepare_points() -> void:
	points.resize(0); points_old.resize(0)
	var a := start_node.global_transform.origin
	var b := end_pos
	for i in range(point_count):
		var t := float(i) / float(max(point_count - 1, 1))
		var p := a.lerp(b, t)
		points.append(p)
		points_old.append(p)

@warning_ignore("shadowed_variable")
func _update_points(delta: float, start: Vector3, end: Vector3) -> void:
	if points.size() != point_count:
		_prepare_points()

	# pin ends to nodes
	points[0] = start
	points[point_count - 1] = end

	# Verlet integrate interior
	for i in range(1, point_count - 1):
		var cur := points[i]
		var vel := points[i] - points_old[i]
		points[i] = points[i] + vel + Vector3.DOWN * gravity_default * delta * delta
		points_old[i] = cur

	# satisfy segment constraints
	for _k in range(iterations):
		_satisfy_constraints(start, end)

@warning_ignore("shadowed_variable")
func _satisfy_constraints(start: Vector3, end: Vector3) -> void:
	# ends remain pinned to start/end
	for i in range(point_count - 1):
		var seg := points[i + 1] - points[i]
		var dist := seg.length()
		if dist <= 1e-8:
			continue
		var dir := seg / dist
		var diff := dist - point_spacing
		if i != 0:
			points[i] += dir * (diff * 0.5)
		if i + 1 != point_count - 1:
			points[i + 1] -= dir * (diff * 0.5)
	points[0] = start
	points[point_count - 1] = end

# Only redirect velocity when rope is taut.
@warning_ignore("shadowed_variable")
func _tether_player_if_tight(start: Vector3, end: Vector3) -> void:
	if state != State.LATCHED: return
	var limit := rope_length
	if start.distance_to(end) < limit - EPS: return

	var n := (start - end).normalized()  # from anchor(end) toward player(start)

	# get + set velocity on CharacterBody3D or RigidBody3D
	var v : Vector3 = _get_player_velocity()
	if v == null:
		return

	# remove outward radial component only (keep tangential, keep inward)
	var vn := v.dot(n)
	if vn > 0.0:
		v -= n * vn
		_set_player_velocity(v)

func _get_player_velocity():
	if player is CharacterBody3D:
		return (player as CharacterBody3D).velocity
	if player is RigidBody3D:
		return (player as RigidBody3D).linear_velocity
	return null

func _set_player_velocity(v: Vector3) -> void:
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = v
	elif player is RigidBody3D:
		(player as RigidBody3D).linear_velocity = v
func _on_end_body_entered(body: Node3D) -> void:
	if !latch(body): return
	latch_to(body, end_area.global_transform.origin)
	print_debug(body.get_path())
	print_debug(body.collision_layer && 1<<8 == 0)
func _on_end_area_entered(body: Node3D) -> void:
	if !latch(body): return
	latch_to(body, end_area.global_transform.origin)
	print_debug(body.get_path())
	print_debug(body.collision_layer && 1<<8 == 0)
func latch(body: Node3D):
	return !(( body.collision_layer & 1<<8) == 0 || state != State.FLYING || returning)
func isIdleOrReturning():
	return state == State.IDLE || returning
