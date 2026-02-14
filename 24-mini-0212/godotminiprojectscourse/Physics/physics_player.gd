extends RigidBody2D

var hit_force : float = 50.0

func _process (_delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# get mouse position
		var mouse_pos = get_global_mouse_position()
		
		# get mouse direction
		var dir = global_position.direction_to(mouse_pos)
		
		# apply the force
		apply_impulse(dir * hit_force)
