extends Control

@onready var intro_tile: TileMapLayer = $SlideContainer/MainIntro_01/TileMapLayer
@onready var intro_img1: Sprite2D = $SlideContainer/MainIntro_01/Main_Intro_Image1
@onready var intro_img2: Sprite2D = $SlideContainer/MainIntro_01/Main_Intro_Image2
@onready var story1: Sprite2D = $SlideContainer/MainIntro_01/story1

@export var scroll_speed : float = 96.0
@export var scroll_height : float = 64.0
@export var next_scene : String = "res://Scenes/level_1.tscn"

var scrolling : bool = true
var tile_origin_y : float = 0.0
var current_step : int = 0
var seq : Tween

func _ready():
	intro_img1.modulate.a = 0.0
	intro_img2.modulate.a = 0.0
	story1.modulate.a = 0.0
	tile_origin_y = intro_tile.position.y
	_play_step_0()

func _process(delta: float) -> void:
	if scrolling:
		intro_tile.position.y -= scroll_speed * delta
		if intro_tile.position.y <= tile_origin_y - scroll_height:
			intro_tile.position.y += scroll_height

func _play_step_0() -> void:
	current_step = 0
	seq = create_tween()
	seq.tween_interval(0.6)
	seq.tween_property(intro_img1, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(5.0)
	seq.tween_callback(_play_step_1)

func _play_step_1() -> void:
	current_step = 1
	seq = create_tween()
	seq.tween_property(intro_img1, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_property(intro_img2, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(5.0)
	seq.tween_callback(_play_step_2)

func _play_step_2() -> void:
	current_step = 2
	seq = create_tween()
	seq.tween_property(intro_img2, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_callback(func(): scrolling = false)
	seq.tween_property(intro_tile, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_property(story1, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(5.0)
	seq.tween_property(story1, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_callback(_go_to_game)

func _on_next_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
	# 현재 이미지 즉시 숨기고 다음으로
	intro_img1.modulate.a = 0.0
	intro_img2.modulate.a = 0.0
	if current_step == 0:
		_play_step_1()
	elif current_step == 1:
		_play_step_2()
	else:
		_go_to_game()

func _on_skip_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
	_go_to_game()

func _go_to_game() -> void:
	get_tree().change_scene_to_file(next_scene)
