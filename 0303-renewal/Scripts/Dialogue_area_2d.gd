extends Area2D

@onready var dialog_sprite = $IntroDialog

func _ready() -> void:
	dialog_sprite.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	print("Player entered the area")
	dialog_sprite.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	dialog_sprite.visible = false
