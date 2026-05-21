extends Control

## Character Select screen.
##
## Architecture:
##   - All character data lives in PlayerStats.characters (Array[CharacterData]).
##   - This screen iterates that array and binds it to fixed UI slots
##     (Bird / Researcher / Leader). Adding more characters only requires
##     adding a new slot in the .tscn and appending an entry to PlayerStats.
##   - On confirm: writes PlayerStats.selected_character_id and changes scene.
##     The next level's PlayerSpawner (or any code using
##     PlayerStats.get_selected_scene()) will spawn the right character.

# ── UI nodes (kept from the original .tscn layout) ─────────────────────────
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

## Maps the fixed character ids used in PlayerStats to the slot widgets in this
## scene. New characters can be added by extending PlayerStats.characters and
## (if you want a third visible slot) adding the slot to character_select.tscn.
var slots: Array = []
var selected_index : int = 0
var tile_origin_y : float = 0.0
var notice_tween : Tween

func _ready() -> void:
	notice_label.modulate.a = 0.0
	tile_origin_y = bg_tile.position.y

	# Build the slots table — order here must match the slot order in the .tscn
	# (Bird / Researcher / Leader). Each entry pairs a character id (looked up
	# in PlayerStats) with the on-screen widgets that represent that slot.
	slots = [
		{ "id": &"bird",       "btn": bird_btn,       "label": bird_label,       "sprite": bird_sprite },
		{ "id": &"researcher", "btn": researcher_btn, "label": researcher_label, "sprite": researcher_sprite },
		{ "id": &"planner",    "btn": leader_btn,     "label": leader_label,     "sprite": leader_sprite },
	]

	_bind_slots()
	_play_intro_anim()

	# Restore previous selection if the user re-enters this screen
	selected_index = _index_of(PlayerStats.selected_character_id)
	if selected_index < 0:
		selected_index = 0
	_apply_selection()

	for i in slots.size():
		var idx := i  # capture
		var slot : Dictionary = slots[i]
		var btn : Button = slot["btn"]
		btn.pressed.connect(func(): _activate(idx))
		btn.mouse_entered.connect(func(): _set_selected(idx))

func _process(delta: float) -> void:
	bg_tile.position.y -= scroll_speed * delta
	if bg_tile.position.y <= tile_origin_y - scroll_height:
		bg_tile.position.y += scroll_height

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_set_selected(min(selected_index + 1, slots.size() - 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_set_selected(max(selected_index - 1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate(selected_index)
		get_viewport().set_input_as_handled()

# ── slot binding from CharacterData ────────────────────────────────────────
func _bind_slots() -> void:
	for slot in slots:
		var data := _get_data(slot["id"])
		var label : Label = slot["label"]
		var sprite : Sprite2D = slot["sprite"]
		if data == null:
			label.text = "—"
			sprite.visible = false
			continue
		label.text = data.display_name
		if data.preview_texture != null:
			sprite.texture = data.preview_texture
		sprite.hframes = max(1, data.preview_hframes)
		sprite.vframes = max(1, data.preview_vframes)
		sprite.frame = clampi(data.preview_frame, 0, sprite.hframes * sprite.vframes - 1)
		# Dim characters that aren't ready yet so the user gets a visual hint.
		sprite.modulate = Color(1, 1, 1, 1) if data.implemented else Color(1, 1, 1, 0.45)

func _get_data(id: StringName) -> CharacterData:
	for c in PlayerStats.characters:
		if c != null and c.id == id:
			return c
	return null

func _index_of(id: StringName) -> int:
	for i in slots.size():
		if slots[i]["id"] == id:
			return i
	return -1

# ── selection / activation ─────────────────────────────────────────────────
func _set_selected(idx: int) -> void:
	if idx == selected_index:
		return
	selected_index = idx
	_apply_selection()

func _apply_selection() -> void:
	for i in slots.size():
		var slot : Dictionary = slots[i]
		var data := _get_data(slot["id"])
		var base_scale : Vector2 = data.preview_scale if data != null else Vector2(3, 3)
		_set_sprite_state(slot["sprite"], base_scale, i == selected_index)
		_apply_button_style(slot["btn"], i == selected_index)
	var focus_btn : Button = slots[selected_index]["btn"]
	focus_btn.grab_focus()

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

func _set_sprite_state(sprite: Sprite2D, base_scale: Vector2, is_selected: bool) -> void:
	var target : Vector2 = base_scale * 1.18 if is_selected else base_scale
	var t := create_tween()
	t.tween_property(sprite, "scale", target, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_intro_anim() -> void:
	title_label.modulate.a = 0.0
	for slot in slots:
		var s : Sprite2D = slot["sprite"]
		s.modulate = Color(s.modulate.r, s.modulate.g, s.modulate.b, 0)
	var t := create_tween()
	t.tween_property(title_label, "modulate:a", 1.0, 0.4)
	for slot in slots:
		var data := _get_data(slot["id"])
		var target_a : float = 1.0 if (data == null or data.implemented) else 0.45
		t.parallel().tween_property(slot["sprite"], "modulate:a", target_a, 0.4)

func _activate(idx: int) -> void:
	selected_index = idx
	var data := _get_data(slots[idx]["id"])
	if data == null:
		_show_notice("준비 중인 캐릭터입니다")
		return
	if not data.implemented:
		_show_notice("준비 중인 캐릭터입니다")
		return

	PlayerStats.set_selected_character(data.id)

	# Disable inputs while transitioning
	for slot in slots:
		(slot["btn"] as Button).disabled = true

	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): get_tree().change_scene_to_file(next_scene))

func _show_notice(msg: String = "") -> void:
	if msg != "":
		notice_label.text = msg
	if notice_tween and notice_tween.is_running():
		notice_tween.kill()
	notice_label.modulate.a = 0.0
	notice_tween = create_tween()
	notice_tween.tween_property(notice_label, "modulate:a", 1.0, 0.2)
	notice_tween.tween_interval(1.4)
	notice_tween.tween_property(notice_label, "modulate:a", 0.0, 0.4)
