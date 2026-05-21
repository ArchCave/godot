extends Area2D

@onready var dialog_sprite = $IntroDialog

func _ready() -> void:
	dialog_sprite.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# bird 캐릭터에만 반응 — 다른 캐릭터엔 dialog가 안 떠야 함.
	if PlayerStats.selected_character_id != &"bird":
		return
	dialog_sprite.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if PlayerStats.selected_character_id != &"bird":
		return
	dialog_sprite.visible = false
