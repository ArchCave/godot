extends Area2D

@onready var intro_talk_sprite: Sprite2D = _find_bubble_sprite()

var player_in_area: Node2D = null

func _find_bubble_sprite() -> Sprite2D:
	for child in get_children():
		if child is Sprite2D:
			return child
	return null

func _ready() -> void:
	intro_talk_sprite.visible = false
	set_process(false)

func _process(_delta: float) -> void:
	if player_in_area:
		intro_talk_sprite.global_position.x = player_in_area.global_position.x

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	intro_talk_sprite.visible = true
	player_in_area = body
	set_process(true)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	intro_talk_sprite.visible = false
	player_in_area = null
	set_process(false)
