extends CanvasLayer

@onready var panel: ColorRect = $Panel
@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var title_button: Button = $Panel/VBox/TitleButton

var is_paused : bool = false

# ── 메뉴를 여는 컨트롤러 입력 ───────────────────────────────────────────────
# L1/R1은 숄더 "버튼", L2/R2는 아날로그 "트리거(축)"라서 감지 방식이 다르다.
const OPEN_SHOULDER_BUTTONS : Array[int] = [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]  # L1, R1
const OPEN_TRIGGER_AXES : Array[int] = [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]            # L2, R2
const TRIGGER_THRESHOLD : float = 0.5
# 트리거는 누르고 있는 동안 값이 계속 들어오므로 "안눌림→눌림" 전환에서만 1회 반응.
var _trigger_down : Dictionary = {}

# ── 메뉴 항목 선택 (컨트롤러/키보드) ────────────────────────────────────────
# story_scene과 동일한 연녹색 강조, 테두리 없음. index 0 = Resume, 1 = Restart.
const MENU_FILL_COLOR : Color = Color(0.43137255, 0.80784315, 0.65882355, 1)
var menu_buttons : Array[Button] = []
var menu_index : int = 0

func _ready():
	panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 입력/클릭을 받기 위해
	_trigger_down = { JOY_AXIS_TRIGGER_LEFT: false, JOY_AXIS_TRIGGER_RIGHT: false }
	# 포커스로 ✕/Enter가 버튼을 자동 클릭하지 않게 끄고, 강조를 직접 제어한다.
	menu_buttons = [resume_button, title_button]
	for i in menu_buttons.size():
		var idx := i  # capture
		var b : Button = menu_buttons[i]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_entered.connect(func(): _set_menu_index(idx))  # 마우스 hover ↔ 강조 동기화

func _unhandled_input(event: InputEvent) -> void:
	if not is_paused:
		# 닫힌 상태: 여는 입력(Esc / L1 / R1 / L2 / R2)만 본다.
		if _is_open_pressed(event):
			get_viewport().set_input_as_handled()
			_set_paused(true)
		return

	# 열린 상태: 메뉴 조작.
	if _is_open_pressed(event) or _is_back(event):
		# 같은 숄더/트리거 버튼 또는 ✕로 닫기.
		get_viewport().set_input_as_handled()
		_set_paused(false)
	elif event.is_action_pressed("ui_up"):
		_set_menu_index(menu_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_set_menu_index(menu_index + 1)
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		# 씬이 바뀔 수 있으니 입력을 먼저 소비하고 확정한다.
		get_viewport().set_input_as_handled()
		_activate_menu()

## 메뉴 여는 입력 여부: 키보드 Esc, L1/R1, L2/R2(트리거 전환). 트리거 상태도 여기서 갱신.
## (ui_cancel을 쓰지 않는 이유: 엔진 기본값상 ○ 버튼이 ui_cancel에도 묶여 있어
##  게임 중 스킬(○) 입력이 메뉴를 여는 오작동을 막기 위해 Esc만 명시 처리한다.)
func _is_open_pressed(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index in OPEN_SHOULDER_BUTTONS:
		return true
	if event is InputEventJoypadMotion and event.axis in OPEN_TRIGGER_AXES:
		var down : bool = event.axis_value >= TRIGGER_THRESHOLD
		var was : bool = _trigger_down.get(event.axis, false)
		_trigger_down[event.axis] = down
		return down and not was
	return false

## 뒤로/닫기: 듀얼센스 ✕ (JOY_BUTTON_A).
func _is_back(event: InputEvent) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A

## 확정: 듀얼센스 ○ (JOY_BUTTON_B) 또는 키보드 Enter/Space. (✕는 확정 아님 — 컨벤션 유지)
func _is_confirm(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		return true
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return true
	return false

func _set_paused(paused: bool) -> void:
	is_paused = paused
	panel.visible = paused
	get_tree().paused = paused
	if paused:
		menu_index = 0  # 열 때마다 Resume에서 시작
		_update_menu_highlight()

func _set_menu_index(idx: int) -> void:
	menu_index = clampi(idx, 0, menu_buttons.size() - 1)
	_update_menu_highlight()

func _activate_menu() -> void:
	if menu_index == 0:
		_on_resume_pressed()
	else:
		_on_title_pressed()

## 선택된 항목만 연녹색 채움으로 강조, 나머지는 흐리게.
func _update_menu_highlight() -> void:
	var box := _make_highlight_box()
	for i in menu_buttons.size():
		var btn : Button = menu_buttons[i]
		var selected : bool = i == menu_index
		for st in ["normal", "hover", "pressed", "focus"]:
			if selected:
				btn.add_theme_stylebox_override(st, box)
			else:
				btn.remove_theme_stylebox_override(st)
		btn.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.6)

func _make_highlight_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = MENU_FILL_COLOR
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_right = 2
	sb.corner_radius_bottom_left = 2
	sb.content_margin_left = 4
	sb.content_margin_top = 2
	sb.content_margin_right = 4
	sb.content_margin_bottom = 2
	return sb

func _on_resume_pressed() -> void:
	Sfx.play("click")
	_set_paused(false)

func _on_title_pressed() -> void:
	Sfx.play("click")
	get_tree().paused = false
	PlayerStats.reset()
	get_tree().change_scene_to_file("res://Scenes/level_2.tscn")
