# Weapon.gd
extends Node3D

@export var bullet_scene: PackedScene
@export var speed: float = 40.0
@export var cooldown: float = 0.02
@export var camera: Camera3D
@export var player: CharacterBody3D   # or RigidBody3D, set in editor
# desired LOCAL offset at spawn
const SPAWN_POS  := Vector3(-0.141, 0.02, -0.034)
const SPAWN_ROT  := Vector3(-4.3, 179.0, -89.9) # degrees
const SPAWN_SCALE:= Vector3(0.05, 0.05, 0.05)

var _next := 0.0
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("right click") and visible:
		shoot()
func shoot() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now < _next or bullet_scene == null:
		return
	_next = now + cooldown

	var b := bullet_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(b)

	# build local offset transform
	var offset := Transform3D()
	offset.basis = Basis.from_euler(SPAWN_ROT * deg_to_rad(1.0)).scaled(SPAWN_SCALE)
	offset.origin = SPAWN_POS

	# copy parent pose *with* local offset, then decouple
	b.global_transform = global_transform * offset
	b.top_level = true

	# shoot forward based on resulting orientation (-Z)
	var dir := -camera.global_transform.basis.z.normalized()
	var player_vel := player.velocity if player else Vector3.ZERO
	var bullet_vel := player_vel + dir * speed
	if b.has_method("init"):
		b.call("init", bullet_vel)
	else:
		b.set("vel",bullet_vel)
