extends Node3D

@export var target: Node3D
@export var offset: Vector3 = Vector3.ZERO
@export var camera: Camera3D
@export var viewmodel_root: Node3D
@export var vm_fov_deg: float = 90.0  # same default as shader

func _process(_dt: float) -> void:
	if target:
		var rel := target.global_transform.basis * offset # rotate offset by target basis
		global_position = target.global_position + rel
	if not camera or not viewmodel_root: return
	for m in _gather_materials(viewmodel_root):
		if m is ShaderMaterial:
			m.set_shader_parameter("cam_fov_deg", camera.fov)
			m.set_shader_parameter("vm_fov_deg", vm_fov_deg)




func _gather_materials(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat: out.append(mat)
	for c in n.get_children():
		out += _gather_materials(c)
	return out
# LeftArmExtend.gd

@export var extend_speed: float = 2.0  # units/sec

#@onready var left_cable: Node3D     = $"right cable"
#@onready var left_arm_down: Node3D  = $"right arm down"
@onready var rope := $"right arm/hook"
func _unhandled_input(event):
	if event.is_action_pressed("grapling Hook"):
		var dir = -global_transform.basis.z  # camera forward
		rope.shoot(dir, extend_speed)
