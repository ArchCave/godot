extends Control

@onready var intro_tile: TileMapLayer = $SlideContainer/MainIntro_01/TileMapLayer
@onready var intro_img1: Sprite2D = $SlideContainer/MainIntro_01/Main_Intro_Image1
@onready var intro_img2: Sprite2D = $SlideContainer/MainIntro_01/Main_Intro_Image2
@onready var skip_button: Button = $UI/SkipButton
@onready var next_button: Button = $UI/NextButton

# 위/아래(방향키·스틱)로 고르는 메뉴. index 0 = 위(Skip), 1 = 아래(Next).
var menu_buttons : Array[Button] = []
var menu_index : int = 1

@export var scroll_speed : float = 96.0
@export var scroll_height : float = 64.0
@export var next_scene : String = "res://Scenes/character_select.tscn"

var scrolling : bool = true
var tile_origin_y : float = 0.0
var current_step : int = 0
var seq : Tween

func _ready():
	intro_img1.modulate.a = 0.0
	intro_img2.modulate.a = 0.0
	tile_origin_y = intro_tile.position.y

	# 컨트롤러/방향키 선택 메뉴 준비. 포커스로 인한 기본 ui_accept(=✕ 버튼) 자동 클릭을
	# 막고, 하이라이트·확정을 직접 제어한다(클릭은 ○ 버튼만).
	menu_buttons = [skip_button, next_button]
	for b in menu_buttons:
		b.focus_mode = Control.FOCUS_NONE
	_update_menu_highlight()

	_play_step_0()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_menu(-1)        # 위: Skip 쪽
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_menu(1)         # 아래: Next 쪽
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):  # ○ 버튼 또는 키보드 Enter/Space
		# 확정하면 씬이 바뀌어 이 노드가 트리에서 빠질 수 있으므로,
		# 입력 소비를 먼저 하고 나서 확정한다.
		get_viewport().set_input_as_handled()
		_activate_menu()

func _move_menu(dir: int) -> void:
	menu_index = clampi(menu_index + dir, 0, menu_buttons.size() - 1)
	_update_menu_highlight()

# 버드 버튼 색(character_select의 bird selected_fill_color)인 연녹색. 테두리 없음.
const MENU_FILL_COLOR : Color = Color(0.43137255, 0.80784315, 0.65882355, 1)

func _update_menu_highlight() -> void:
	var box := _make_highlight_box()
	for i in menu_buttons.size():
		var btn : Button = menu_buttons[i]
		var selected : bool = i == menu_index
		# 선택된 항목은 노란 채움+테두리로 강조, 나머지는 흐리게.
		for st in ["normal", "hover", "pressed", "focus"]:
			if selected:
				btn.add_theme_stylebox_override(st, box)
			else:
				btn.remove_theme_stylebox_override(st)
		btn.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.6)

func _make_highlight_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = MENU_FILL_COLOR
	# 테두리 없음 (버드 버튼처럼)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_right = 2
	sb.corner_radius_bottom_left = 2
	sb.content_margin_left = 4
	sb.content_margin_top = 2
	sb.content_margin_right = 4
	sb.content_margin_bottom = 2
	return sb

func _is_confirm(event: InputEvent) -> bool:
	# 듀얼센스 ○(동그라미, button 1)
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		return true
	# 키보드 Enter / Space
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return true
	return false

func _activate_menu() -> void:
	Sfx.play("click")
	if menu_index == 0:
		_on_skip_pressed()
	else:
		_on_next_pressed()

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
	seq.tween_callback(_go_to_game)

func _on_next_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
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
