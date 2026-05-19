extends Control

@onready var story1: Sprite2D = $story1

@export var next_scene : String = "res://Scenes/level_1.tscn"

var seq : Tween

func _ready() -> void:
	story1.modulate.a = 0.0
	seq = create_tween()
	seq.tween_property(story1, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(5.0)
	seq.tween_property(story1, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_callback(_go_to_game)

func _on_skip_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
	_go_to_game()

func _go_to_game() -> void:
	get_tree().change_scene_to_file(next_scene)
