extends RigidBody2D

var hit_force : float = 50.0

func _process(delta: float):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		
		var mouse_pos = get_global_mouse_position()
		var dir = global_position.direction_to(mouse_pos)
		
		apply_impulse(dir * hit_force)
