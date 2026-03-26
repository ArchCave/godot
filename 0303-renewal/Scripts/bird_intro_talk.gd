extends Area2D

@onready var intro_talk_sprite = $IntroTalk_bubble

var player_in_area: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	intro_talk_sprite.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_in_area:
		intro_talk_sprite.global_position.x = player_in_area.global_position.x


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	intro_talk_sprite.visible = true
	player_in_area = body


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	intro_talk_sprite.visible = false
	player_in_area = null
