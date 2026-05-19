extends Control

@onready var title_label: Label = $UI/TitleLabel
@onready var bird_btn: Button = $Choices/BirdOption/BirdButton
@onready var researcher_btn: Button = $Choices/ResearcherOption/ResearcherButton
@onready var leader_btn: Button = $Choices/LeaderOption/LeaderButton
@onready var bird_label: Label = $Choices/BirdOption/BirdLabel
@onready var researcher_label: Label = $Choices/ResearcherOption/ResearcherLabel
@onready var leader_label: Label = $Choices/LeaderOption/LeaderLabel
@onready var bird_sprite: Sprite2D = $Characters/BirdSprite
@onready var researcher_sprite: Sprite2D = $Characters/ResearcherSprite
@onready var leader_sprite: Sprite2D = $Characters/LeaderSprite
@onready var notice_label: Label = $UI/NoticeLabel
@onready var bg_tile: TileMapLayer = $BackgroundScroll/TileMapLayer

@export var next_scene : String = "res://Scenes/story1_scene.tscn"
@export var scroll_speed : float = 96.0
@export var scroll_height : float = 64.0

@export var normal_border_color : Color = Color(1, 1, 1, 0.55)
@export var normal_fill_color : Color = Color(1, 1, 1, 0)
@export var selected_border_color : Color = Color(1, 0.9, 0.3, 1.0)
@export var selected_fill_color : Color = Color(1, 0.9, 0.3, 0.2)
@export_range(0, 8, 1) var border_width : int = 1
@export_range(0, 20, 1) var corner_radius : int = 2

var tile_origin_y : float = 0.0

const BIRD := 0
const RESEARCHER := 1
const LEADER := 2

const BASE_SCALES := {
	BIRD: Vector2(3.3, 3.3),
	RESEARCHER: Vector2(3.0, 3.0),
	LEADER: Vector2(3.0, 3.0),
}

var selected : int = BIRD
var notice_tween : Tween

func _ready() -> void:
	notice_label.modulate.a = 0.0
	tile_origin_y = bg_tile.position.y
	_play_intro_anim()
	_apply_selection()

	bird_btn.pressed.connect(func(): _activate(BIRD))
	researcher_btn.pressed.connect(func(): _activate(RESEARCHER))
	leader_btn.pressed.connect(func(): _activate(LEADER))

	bird_btn.mouse_entered.connect(func(): _set_selected(BIRD))
	researcher_btn.mouse_entered.connect(func(): _set_selected(RESEARCHER))
	leader_btn.mouse_entered.connect(func(): _set_selected(LEADER))

func _process(delta: float) -> void:
	bg_tile.position.y -= scroll_speed * delta
	if bg_tile.position.y <= tile_origin_y - scroll_height:
		bg_tile.position.y += scroll_height

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_set_selected(min(selected + 1, LEADER))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_set_selected(max(selected - 1, BIRD))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate(selected)
		get_viewport().set_input_as_handled()

func _set_selected(idx: int) -> void:
	if idx == selected:
		return
	selected = idx
	_apply_selection()

func _apply_selection() -> void:
	_set_sprite_state(bird_sprite, BIRD)
	_set_sprite_state(researcher_sprite, RESEARCHER)
	_set_sprite_state(leader_sprite, LEADER)
	_apply_button_style(bird_btn, selected == BIRD)
	_apply_button_style(researcher_btn, selected == RESEARCHER)
	_apply_button_style(leader_btn, selected == LEADER)
	match selected:
		BIRD: bird_btn.grab_focus()
		RESEARCHER: researcher_btn.grab_focus()
		LEADER: leader_btn.grab_focus()

func _apply_button_style(btn: Button, is_selected: bool) -> void:
	var border : Color = selected_border_color if is_selected else normal_border_color
	var fill : Color = selected_fill_color if is_selected else normal_fill_color
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	sb.bg_color = fill
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, sb)

func _set_sprite_state(sprite: Sprite2D, idx: int) -> void:
	var base : Vector2 = BASE_SCALES[idx]
	var target : Vector2 = base * 1.18 if idx == selected else base
	var t := create_tween()
	t.tween_property(sprite, "scale", target, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_intro_anim() -> void:
	title_label.modulate.a = 0.0
	for s in [bird_sprite, researcher_sprite, leader_sprite]:
		s.modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(title_label, "modulate:a", 1.0, 0.4)
	t.parallel().tween_property(bird_sprite, "modulate:a", 1.0, 0.4)
	t.parallel().tween_property(researcher_sprite, "modulate:a", 1.0, 0.4)
	t.parallel().tween_property(leader_sprite, "modulate:a", 1.0, 0.4)

func _activate(idx: int) -> void:
	selected = idx
	if idx == BIRD:
		bird_btn.disabled = true
		researcher_btn.disabled = true
		leader_btn.disabled = true
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(func(): get_tree().change_scene_to_file(next_scene))
	else:
		_show_notice()

func _show_notice() -> void:
	if notice_tween and notice_tween.is_running():
		notice_tween.kill()
	notice_label.modulate.a = 0.0
	notice_tween = create_tween()
	notice_tween.tween_property(notice_label, "modulate:a", 1.0, 0.2)
	notice_tween.tween_interval(1.4)
	notice_tween.tween_property(notice_label, "modulate:a", 0.0, 0.4)
