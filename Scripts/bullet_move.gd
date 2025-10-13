# Bullet.gd
extends Node3D

@export var lifetime: float = 10
var vel: Vector3 = Vector3.ZERO
func init(velo: Vector3) -> void:
	vel = velo

func _ready() -> void:
	top_level = true
	$Area3D.connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta: float) -> void:
	global_position += vel * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.collision_layer & (1 << 8) && body.has_method("apply_damage"):
		body.apply_damage()  
	# check collision layer of the other body
	if body.collision_layer & (1 << 8):  # layer 8 = bullet layer
		queue_free()
