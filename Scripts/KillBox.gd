extends Area3D

@export var respawn_position: Vector3 = Vector3(0, 28.82, 0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Compare the node's name
	
	if body.name == "Player":
		body.global_position = respawn_position
		body.velocity.y = 0
	else:
		body.queue_free()
