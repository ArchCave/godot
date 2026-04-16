extends Control

@onready var slide_container: Node2D = $SlideContainer
@onready var next_btn: Button = $UI/NextButton
@onready var skip_btn: Button = $UI/SkipButton

var slides : Array = []
var current_slide : int = 0
var is_transitioning : bool = false

@export var transition_duration : float = 0.4
@export var next_scene : String = "res://Scenes/level_2.tscn"

func _ready():
	slides = slide_container.get_children()
	# 첫 슬라이드만 보이게
	for i in slides.size():
		slides[i].modulate.a = 1.0 if i == 0 else 0.0
		slides[i].visible = true

func _on_next_pressed() -> void:
	if is_transitioning:
		return
	if current_slide >= slides.size() - 1:
		_go_to_game()
		return
	_transition_to(current_slide + 1)

func _on_skip_pressed() -> void:
	_go_to_game()

func _transition_to(index: int) -> void:
	is_transitioning = true
	var tween = create_tween()
	# 현재 슬라이드 페이드아웃
	tween.tween_property(slides[current_slide], "modulate:a", 0.0, transition_duration)
	# 다음 슬라이드 페이드인
	tween.tween_property(slides[index], "modulate:a", 1.0, transition_duration)
	tween.tween_callback(func():
		current_slide = index
		is_transitioning = false
	)

func _go_to_game() -> void:
	get_tree().change_scene_to_file(next_scene)
