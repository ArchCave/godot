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

# 위 방향키로 뒤집어 보여줄 캐릭터별 스탯 카드. 씬(.tscn)에 실제 노드로 있으므로
# 에디터 2D 화면에서 직접 클릭해 크기/위치를 조절할 수 있다. 스크립트는 이 노드를
# 참조해 평소엔 숨기고, 뒤집을 때만 보여준다 (크기는 에디터에서 잡은 scale을 그대로 사용).
@onready var bird_intro: Sprite2D = $Characters/BirdIntro
@onready var researcher_intro: Sprite2D = $Characters/ResearcherIntro
@onready var leader_intro: Sprite2D = $Characters/LeaderIntro

## 선택된 슬롯 sprite의 확대 배율 (_set_sprite_state와 공유).
const SELECTED_SCALE_MULT : float = 1.18

@export var next_scene : String = "res://Scenes/story1_scene.tscn"
@export var scroll_speed : float = 96.0
@export var scroll_height : float = 64.0

@export var normal_border_color : Color = Color(1, 1, 1, 0.55)
@export var normal_fill_color : Color = Color(1, 1, 1, 0)

@export_group("선택 강조 색 (캐릭터별)")
## Bird 선택 시 테두리/채움 색 (기존 그대로).
@export var selected_border_color : Color = Color(1, 0.9, 0.3, 1.0)
@export var selected_fill_color : Color = Color(1, 0.9, 0.3, 0.2)
## Researcher 선택 시 테두리/채움 색.
@export var researcher_selected_border_color : Color = Color(1, 0.9, 0.3, 1.0)
@export var researcher_selected_fill_color : Color = Color(1, 0.9, 0.3, 0.2)
## Planner 선택 시 테두리/채움 색.
@export var planner_selected_border_color : Color = Color(1, 0.9, 0.3, 1.0)
@export var planner_selected_fill_color : Color = Color(1, 0.9, 0.3, 0.2)
@export_group("")

@export_range(0, 8, 1) var border_width : int = 1
@export_range(0, 20, 1) var corner_radius : int = 2

## 카드 뒤집기(반쪽) 애니메이션 시간(초). 전체 뒤집기 = 이 값 ×2.
## (카드 크기는 에디터에서 BirdIntro/ResearcherIntro/LeaderIntro 노드를 직접 조절.)
@export var flip_duration : float = 0.13

## Maps the fixed character ids used in PlayerStats to the slot widgets in this
## scene. New characters can be added by extending PlayerStats.characters and
## (if you want a third visible slot) adding the slot to character_select.tscn.
var slots: Array = []
var selected_index : int = 0
var tile_origin_y : float = 0.0
var notice_tween : Tween

## 현재 선택된 카드가 스탯 면으로 뒤집혀 있는지.
var flipped : bool = false
## 뒤집기 애니메이션 진행 중 (중복 입력 방지).
var flip_busy : bool = false
## 진행 중인 뒤집기 트윈 (선택 변경 시 즉시 끊기 위해 보관).
var flip_tween : Tween

func _ready() -> void:
	notice_label.modulate.a = 0.0
	tile_origin_y = bg_tile.position.y

	# Build the slots table — order here must match the slot order in the .tscn
	# (Bird / Researcher / Leader). Each entry pairs a character id (looked up
	# in PlayerStats) with the on-screen widgets that represent that slot.
	slots = [
		{ "id": &"bird",       "btn": bird_btn,       "label": bird_label,       "sprite": bird_sprite,       "intro": bird_intro },
		{ "id": &"researcher", "btn": researcher_btn, "label": researcher_label, "sprite": researcher_sprite, "intro": researcher_intro },
		{ "id": &"planner",    "btn": leader_btn,     "label": leader_label,     "sprite": leader_sprite,     "intro": leader_intro },
	]

	_bind_slots()
	_init_intro_cards()
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
	if event.is_action_pressed("ui_up"):
		# 위 방향키: 선택된 캐릭터 카드를 뒤집어 스탯 면을 보이거나 다시 되돌린다.
		_toggle_flip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		# 아래 방향키: 스탯 면이면 캐릭터 면으로 되돌린다.
		if flipped and not flip_busy:
			_flip_to_front()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		# 좌우로 선택을 옮기기 전에, 뒤집힌 카드가 있으면 즉시 캐릭터 면으로 되돌린다.
		_reset_flip_instant()
		_set_selected(min(selected_index + 1, slots.size() - 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_reset_flip_instant()
		_set_selected(max(selected_index - 1, 0))
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		# 듀얼센스 얼굴 버튼은 여기서 직접 처리한다. ✕는 기본 ui_accept(=button 0)에
		# 묶여 있어 포커스된 버튼을 눌러버리므로, _input(GUI보다 먼저)에서 가로채
		# "확정"이 아닌 "뒤로가기"로만 쓰이도록 소비한다.
		if _handle_joypad_button(event.button_index):
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		# 키보드 Enter/Space로 확정 (조이패드 버튼은 위에서 따로 처리).
		_activate(selected_index)
		get_viewport().set_input_as_handled()

## 듀얼센스 얼굴 버튼 처리. 처리했으면 true(이벤트 소비), 아니면 false.
func _handle_joypad_button(button_index: int) -> bool:
	match button_index:
		JOY_BUTTON_B:   # ○ 동그라미: 캐릭터 선택 확정
			_activate(selected_index)
			return true
		JOY_BUTTON_Y:   # △ 세모: 캐릭터 설명(뒷면 카드) 보기
			if not flipped and not flip_busy:
				_flip_to_stats()
			return true
		JOY_BUTTON_A:   # ✕ 엑스: 설명 면에서 캐릭터 선택 화면으로 되돌아가기
			if flipped and not flip_busy:
				_flip_to_front()
			return true  # 뒤집힌 상태가 아니어도 ✕가 선택을 확정하지 않도록 항상 소비
	return false

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
	# 다른 슬롯으로 옮기면 현재 뒤집힌 카드는 즉시 캐릭터 면으로 되돌린다 (마우스 hover 포함).
	_reset_flip_instant()
	selected_index = idx
	_apply_selection()

func _apply_selection() -> void:
	for i in slots.size():
		var slot : Dictionary = slots[i]
		var data := _get_data(slot["id"])
		var base_scale : Vector2 = data.preview_scale if data != null else Vector2(3, 3)
		_set_sprite_state(slot["sprite"], base_scale, i == selected_index)
		_apply_button_style(slot["btn"], i == selected_index, slot["id"])
	var focus_btn : Button = slots[selected_index]["btn"]
	focus_btn.grab_focus()

## 캐릭터 id별 선택 강조 색 (테두리/채움)을 돌려준다. bird는 기존 selected_* 사용.
func _selected_colors(id: StringName) -> Dictionary:
	match id:
		&"researcher":
			return { "border": researcher_selected_border_color, "fill": researcher_selected_fill_color }
		&"planner":
			return { "border": planner_selected_border_color, "fill": planner_selected_fill_color }
		_:
			return { "border": selected_border_color, "fill": selected_fill_color }

func _apply_button_style(btn: Button, is_selected: bool, id: StringName) -> void:
	var sel : Dictionary = _selected_colors(id)
	var border : Color = sel["border"] if is_selected else normal_border_color
	var fill : Color = sel["fill"] if is_selected else normal_fill_color
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
	var target : Vector2 = base_scale * SELECTED_SCALE_MULT if is_selected else base_scale
	var t := create_tween()
	t.tween_property(sprite, "scale", target, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ── stat card flip ──────────────────────────────────────────────────────────
## 씬에 미리 둔 스탯 카드 노드(BirdIntro/ResearcherIntro/LeaderIntro)를 초기화한다.
## 에디터에서 잡아 둔 위치/크기는 그대로 두고(런타임에 그 scale을 "펼친 크기"로 사용),
## 게임 시작 시엔 숨겨만 둔다. 뒤집을 때 _flip_to_stats가 다시 보여준다.
func _init_intro_cards() -> void:
	for slot in slots:
		var card : Sprite2D = slot.get("intro")
		if card == null:
			continue
		slot["intro_scale"] = card.scale  # 에디터에서 조절한 크기를 펼친 상태 기준으로 기억
		card.visible = false

## 선택된 슬롯 sprite가 가져야 할 (확대된) 스케일.
func _selected_sprite_scale(idx: int) -> Vector2:
	var data := _get_data(slots[idx]["id"])
	var base : Vector2 = data.preview_scale if data != null else Vector2(3, 3)
	return base * SELECTED_SCALE_MULT

## 위 방향키: 캐릭터 면 ↔ 스탯 면 토글.
func _toggle_flip() -> void:
	if flip_busy:
		return
	if flipped:
		_flip_to_front()
	else:
		_flip_to_stats()

## 캐릭터 면 → 스탯 면. sprite를 가로로 접었다가(scale.x→0) 카드로 펼친다(0→full).
func _flip_to_stats() -> void:
	var slot : Dictionary = slots[selected_index]
	var card : Sprite2D = slot.get("intro")
	if card == null:
		return
	Sfx.play("chest_open")   # 캐릭터 설명(뒷면 카드) 펼치기
	var sprite : Sprite2D = slot["sprite"]
	flip_busy = true
	flipped = true
	var full : Vector2 = slot["intro_scale"]
	card.scale.x = 0.0
	if flip_tween and flip_tween.is_valid():
		flip_tween.kill()
	flip_tween = create_tween()
	flip_tween.tween_property(sprite, "scale:x", 0.0, flip_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		sprite.visible = false
		card.visible = true)
	flip_tween.tween_property(card, "scale:x", full.x, flip_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_callback(func(): flip_busy = false)

## 스탯 면 → 캐릭터 면. 카드를 접었다가 캐릭터 sprite를 다시 펼친다.
func _flip_to_front() -> void:
	var slot : Dictionary = slots[selected_index]
	var card : Sprite2D = slot.get("intro")
	if card == null:
		return
	var sprite : Sprite2D = slot["sprite"]
	flip_busy = true
	flipped = false
	var sprite_full : Vector2 = _selected_sprite_scale(selected_index)
	sprite.scale.x = 0.0
	if flip_tween and flip_tween.is_valid():
		flip_tween.kill()
	flip_tween = create_tween()
	flip_tween.tween_property(card, "scale:x", 0.0, flip_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		card.visible = false
		sprite.visible = true)
	flip_tween.tween_property(sprite, "scale:x", sprite_full.x, flip_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_tween.tween_callback(func(): flip_busy = false)

## 애니메이션 없이 현재 선택 슬롯을 캐릭터 면으로 즉시 복구 (선택 이동 직전 호출).
func _reset_flip_instant() -> void:
	if not flipped and not flip_busy:
		return
	if flip_tween and flip_tween.is_valid():
		flip_tween.kill()
	var slot : Dictionary = slots[selected_index]
	var card : Sprite2D = slot.get("intro")
	var sprite : Sprite2D = slot["sprite"]
	if card != null:
		card.visible = false
	if sprite != null:
		sprite.visible = true
		# 정확한 스케일은 곧 _apply_selection이 다시 맞추므로 여기선 가로 접힘만 해제.
		sprite.scale = _selected_sprite_scale(selected_index)
	flipped = false
	flip_busy = false

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

	# 캐릭터를 확정하는 순간은 새 플레이의 시작점이다. 이전 플레이에서 누적된
	# 런 스탯(코인/킬 수 등)을 리셋해, 점프력(score 기반)이나 코인이 이어지지 않게 한다.
	# 하트는 레벨 로드 시 캐릭터의 max_health로 매번 새로 적용되므로 여기선 건드리지 않는다.
	PlayerStats.reset()

	PlayerStats.set_selected_character(data.id)

	# (BGM은 여기서 시작하지 않는다 — 실제 맵 진입 시 player.gd _ready에서 시작.)

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
