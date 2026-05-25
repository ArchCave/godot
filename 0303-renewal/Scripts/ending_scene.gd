extends Control

@onready var intro_img: Sprite2D = $SlideContainer/MainIntro_01/Main_Intro_Image2
@onready var skip_button: Button = $UI/SkipButton

# 다른 스킵 버튼과 동일한 선택 강조 색 (버드 버튼 연녹색, 테두리 없음).
const SKIP_FILL_COLOR : Color = Color(0.43137255, 0.80784315, 0.65882355, 1)

@export var hold_duration : float = 5.0
@export var fade_in_duration : float = 0.8
@export var fade_out_duration : float = 0.6
@export var next_scene : String = "res://Scenes/main_menu.tscn"
## 캐릭터별 next_scene 오버라이드. 비어있으면 기본 next_scene 사용.
## 예: middle_scene이 planner일 땐 level_5로, 다른 캐릭터일 땐 기본 main_menu로.
@export_file("*.tscn") var bird_next_scene : String = ""
@export_file("*.tscn") var researcher_next_scene : String = ""
@export_file("*.tscn") var planner_next_scene : String = ""

var seq : Tween
var _selected : bool = false  # Skip 버튼이 선택(강조)된 상태인지

func _ready():
	# 맵(레벨)이 끝나고 이 씬으로 오면 게임 BGM·걷기 소리를 멈춘다.
	# (BGM은 player.gd가 레벨 진입 시 켜고 한 번 켜지면 계속 이어지므로, 비(非)레벨
	#  씬에 도착할 때 명시적으로 꺼 줘야 메뉴/엔딩까지 따라오지 않는다.)
	Sfx.stop_bgm()
	Sfx.stop_footsteps()
	intro_img.modulate.a = 0.0
	# 포커스로 ✕/Enter가 버튼을 자동으로 누르지 않게 하고, 선택 강조를 직접 제어.
	skip_button.focus_mode = Control.FOCUS_NONE
	_update_skip_highlight()
	_play_sequence()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		# 위(방향키/컨트롤러): Skip 버튼 선택 → 색 강조 (다른 스킵 화면과 동일)
		_selected = true
		_update_skip_highlight()
		get_viewport().set_input_as_handled()
	elif _selected and _is_confirm(event):
		# 선택된 상태에서 ○(또는 Enter/Space)로 확정해야 넘어간다.
		get_viewport().set_input_as_handled()  # 씬 전환 전에 입력을 먼저 소비
		_on_skip_pressed()

## 듀얼센스 ○(동그라미, JOY_BUTTON_B) 또는 키보드 Enter/Space 인지.
func _is_confirm(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		return true
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return true
	return false

## Skip 버튼 강조 갱신. 선택되면 연녹색 채움(테두리 없음), 아니면 흐리게.
func _update_skip_highlight() -> void:
	if _selected:
		var box := StyleBoxFlat.new()
		box.bg_color = SKIP_FILL_COLOR
		box.corner_radius_top_left = 2
		box.corner_radius_top_right = 2
		box.corner_radius_bottom_right = 2
		box.corner_radius_bottom_left = 2
		box.content_margin_left = 4
		box.content_margin_top = 2
		box.content_margin_right = 4
		box.content_margin_bottom = 2
		for st in ["normal", "hover", "pressed", "focus"]:
			skip_button.add_theme_stylebox_override(st, box)
		skip_button.modulate = Color(1, 1, 1, 1)
	else:
		for st in ["normal", "hover", "pressed", "focus"]:
			skip_button.remove_theme_stylebox_override(st)
		skip_button.modulate = Color(1, 1, 1, 0.6)

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
	Sfx.play("click")   # 넘어가는 소리
	if seq and seq.is_running():
		seq.kill()
	_go_to_menu()

func _go_to_menu() -> void:
	# 캐릭터별 오버라이드가 설정돼 있으면 그걸 우선.
	var override : String = ""
	match PlayerStats.selected_character_id:
		&"bird": override = bird_next_scene
		&"researcher": override = researcher_next_scene
		&"planner": override = planner_next_scene
	var target : String = override if override != "" else next_scene
	get_tree().change_scene_to_file(target)
