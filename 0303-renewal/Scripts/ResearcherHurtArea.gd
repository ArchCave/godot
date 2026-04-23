extends Area2D

func take_bullet_damage(amount: int) -> void:
	var parent = get_parent()
	if parent and parent.has_method("take_bullet_damage"):
		parent.take_bullet_damage(amount)

func _on_body_entered(body: Node2D) -> void:
	var parent = get_parent()
	if parent and parent.has_method("on_player_contact"):
		parent.on_player_contact(body)
