extends RigidBody3D

@export var move_speed : float = 2.0

func _physics_process(_delta):
	if Input.is_physical_key_pressed(KEY_LEFT):
		apply_force(Vector3.LEFT * move_speed)
	elif Input.is_physical_key_pressed(KEY_RIGHT):
		apply_force(Vector3.RIGHT * move_speed)

func _on_body_entered(body):
	if body.is_in_group("Tree"):
		get_tree().reload_current_scene.call_deferred()
