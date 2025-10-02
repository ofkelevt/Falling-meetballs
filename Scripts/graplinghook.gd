extends MeshInstance3D

@export var start: Vector3
@export var end: Vector3
@export var point_count: int = 10
@export var rope_width: float = 0.05
@export var resolution: int = 8        # ring verts
@export var iterations: int = 4        # constraint passes
@export var is_drawing: bool = false
@export var dirty: bool = true

var points: Array[Vector3] = []
var points_old: Array[Vector3] = []
var point_spacing: float = 0.0
var gravity_default: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	mesh = ArrayMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.2)        # pick a color
	# Optional: show pure color without lights
	# mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = mat                         # or: mesh.surface_set_material(0, mat)

	_prepare_points()
	_generate_mesh()

func _process(delta: float) -> void:
	if dirty or is_drawing:
		_update_points(delta)
		_generate_mesh()
		dirty = false

func _prepare_points() -> void:
	points.clear()
	points_old.clear()
	for i in range(point_count):
		var t := float(i) / float(point_count - 1)
		var p := start.lerp(end, t)
		points.append(p)
		points_old.append(p)
	_update_spacing()

func _update_spacing() -> void:
	point_spacing = (end - start).length() / float(point_count - 1)

func _update_points(delta: float) -> void:
	points[0] = start
	points[point_count - 1] = end
	_update_spacing()

	# Verlet integrate
	for i in range(1, point_count - 1):
		var cur := points[i]
		var vel := points[i] - points_old[i]
		points[i] = points[i] + vel + Vector3.DOWN * gravity_default * delta * delta
		points_old[i] = cur

	# Satisfy distance constraints
	for _i in range(iterations):
		_satisfy_constraints()

func _satisfy_constraints() -> void:
	for i in range(point_count - 1):
		var seg := points[i + 1] - points[i]
		var dist := seg.length()
		if dist == 0.0:
			continue
		var dir := seg / dist
		var diff := dist - point_spacing
		if i != 0:
			points[i] += dir * (diff * 0.5)
		if i + 1 != point_count - 1:
			points[i + 1] -= dir * (diff * 0.5)

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
