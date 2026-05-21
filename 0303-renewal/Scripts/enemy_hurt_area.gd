extends Area2D
## CharacterBody2D 루트의 적에 붙는 Area2D용 forwarder.
## player_bullet은 Area2D의 take_bullet_damage만 호출하므로, 부모(적 본체)로 위임한다.

func take_bullet_damage(amount: int) -> void:
	var p := get_parent()
	if p != null and p.has_method("take_bullet_damage"):
		p.take_bullet_damage(amount)
