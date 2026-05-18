extends Control

@onready var intro_img: Sprite2D = $SlideContainer/MainIntro_01/Main_Intro_Image2

@export var hold_duration : float = 5.0
@export var fade_in_duration : float = 0.8
@export var fade_out_duration : float = 0.6
@export var next_scene : String = "res://Scenes/main_menu.tscn"

var seq : Tween

func _ready():
	intro_img.modulate.a = 0.0
	_play_sequence()

func _play_sequence() -> void:
	seq = create_tween()
	seq.tween_interval(0.6)
	seq.tween_property(intro_img, "modulate:a", 1.0, fade_in_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(hold_duration)
	seq.tween_property(intro_img, "modulate:a", 0.0, fade_out_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_callback(_go_to_menu)

func _on_next_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
	_go_to_menu()

func _on_skip_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
	_go_to_menu()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file(next_scene)
