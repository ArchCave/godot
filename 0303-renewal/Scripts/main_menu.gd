extends Control

@onready var bg: TileMapLayer = $Background2
@onready var logo: Sprite2D = $FloatingElements/MovingLogo
@onready var birdhuman: Sprite2D = $FloatingElements/birdhuman
@onready var text_sprite: Sprite2D = $FloatingElements/text

@export var slide_distance : float = 64.0
@export var slide_duration : float = 2.0

var bg_origin : Vector2
var logo_origin : Vector2
var bird_origin : Vector2
var text_origin : Vector2
var intro_done : bool = false

func _ready():
	# 메인메뉴로 돌아오면 직전 맵의 BGM·걷기 소리가 따라오지 않게 확실히 정지.
	# (hidden_ending 등 엔딩씬을 거치지 않고 바로 오는 경로까지 모두 커버.)
	Sfx.stop_bgm()
	Sfx.stop_footsteps()
	bg_origin = bg.position
	logo_origin = logo.position
	bird_origin = birdhuman.position
	text_origin = text_sprite.position

	# 처음에는 화면 밖에 숨김
	logo.position.y = -80.0
	birdhuman.position.y = 260.0
	text_sprite.modulate.a = 0.0
	text_sprite.position.y = 200.0

	_start_bg_slide()
	_play_intro()

func _play_intro() -> void:
	var intro = create_tween()
	# 0.5초 대기
	intro.tween_interval(0.5)
	# 로고: 위에서 부드럽게 내려옴 (1.8초)
	intro.tween_property(logo, "position:y", logo_origin.y, 1.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# birdhuman: 아래에서 올라옴 (동시에)
	intro.parallel().tween_property(birdhuman, "position:y", bird_origin.y, 1.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 텍스트: 아래에서 부드럽게 올라옴
	intro.tween_property(text_sprite, "position:y", text_origin.y - 8.0, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.parallel().tween_property(text_sprite, "modulate:a", 1.0, 0.2)
	# 스프링 반동: 느긋하게 위→아래→제자리
	intro.tween_property(text_sprite, "position:y", text_origin.y + 4.0, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro.tween_property(text_sprite, "position:y", text_origin.y, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 인트로 끝나면 루프 모션 시작
	intro.tween_callback(_start_loop_motions)

func _start_loop_motions() -> void:
	intro_done = true
	_start_logo_bob()
	_start_bird_bob()
	_start_text_slide()

func _input(event: InputEvent) -> void:
	if not intro_done:
		return
	# 키보드 아무 키 또는 듀얼센스 등 컨트롤러 아무 버튼이면 진입
	if (event is InputEventKey and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed):
		Sfx.play("click")
		get_tree().change_scene_to_file("res://Scenes/story_scene.tscn")

func _start_bg_slide() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(bg, "position:x", bg_origin.x - slide_distance, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bg, "position:x", bg_origin.x, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_logo_bob() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(logo, "position:y", logo_origin.y - 4.0, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo, "position:y", logo_origin.y + 4.0, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_bird_bob() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(birdhuman, "position:y", bird_origin.y - 4.0, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(birdhuman, "position:y", bird_origin.y + 4.0, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_text_slide() -> void:
	# 배경과 엇박: 우로 먼저 출발
	var tween = create_tween().set_loops()
	tween.tween_property(text_sprite, "position:x", text_origin.x + 1.5, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(text_sprite, "position:x", text_origin.x - 1.5, slide_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
