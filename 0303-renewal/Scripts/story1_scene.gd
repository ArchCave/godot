extends Control

@onready var story1: Sprite2D = $story1
@onready var story2: Sprite2D = $story2
@onready var story3: Sprite2D = $story3
@onready var skip_button: Button = $UI/SkipButton

# 이전 화면(story_scene)과 동일한 선택 강조 색: 버드 버튼 연녹색, 테두리 없음.
const SKIP_FILL_COLOR : Color = Color(0.43137255, 0.80784315, 0.65882355, 1)

# Per-character narrative sprite + starting level.
# Falls back to bird (story1 / level_1) if the selected id is unknown.
const ROUTES := {
	&"bird":       { "sprite": "story1", "next": "res://Scenes/level_1.tscn" },
	&"researcher": { "sprite": "story2", "next": "res://Scenes/level_7.tscn" },
	&"planner":    { "sprite": "story3", "next": "res://Scenes/level_6.tscn" },
}

var next_scene : String = "res://Scenes/level_1.tscn"

var seq : Tween
var _selected : bool = false  # Skip 버튼이 선택(강조)된 상태인지

func _ready() -> void:
	var route : Dictionary = ROUTES.get(PlayerStats.selected_character_id, ROUTES[&"bird"])
	next_scene = route["next"]

	story1.visible = false
	story2.visible = false
	story3.visible = false

	var active : Sprite2D = get_node(route["sprite"])
	active.visible = true
	active.modulate.a = 0.0

	# 포커스로 ✕/Enter가 버튼을 자동으로 누르지 않게 하고, 선택 강조를 직접 제어.
	skip_button.focus_mode = Control.FOCUS_NONE
	_update_skip_highlight()

	seq = create_tween()
	seq.tween_property(active, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(5.0)
	seq.tween_property(active, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_callback(_go_to_game)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		# 위(방향키/컨트롤러): Skip 버튼 선택 → 색 강조 (이전 화면과 동일)
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

func _on_skip_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
	_go_to_game()

func _go_to_game() -> void:
	get_tree().change_scene_to_file(next_scene)
