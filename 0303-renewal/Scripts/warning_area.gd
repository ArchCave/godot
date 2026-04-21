extends Area2D

@export var freeze_duration : float = 5.0
@export var fade_out_time : float = 0.5
@export var warning_texture : Texture2D
@export var challenge_duration : float = 120.0
@export var required_points : int = 6
@export_group("Countdown UI")
@export var countdown_font : Font
@export var countdown_font_size : int = 16
@export var countdown_font_color : Color = Color.WHITE
@export var countdown_outline_color : Color = Color.BLACK
@export var countdown_outline_size : int = 4
@export var countdown_top_offset : float = 4.0

var triggered : bool = false
var challenged_player : CharacterBody2D = null
var challenge_start_score : int = 0
var challenge_remaining : float = 0.0
var challenge_active : bool = false
var challenge_label : Label = null

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if not body.is_in_group("Player"):
		return
	triggered = true

	# 플레이어 프리즈
	body.set_physics_process(false)
	body.velocity = Vector2.ZERO

	# Player 내부 CanvasLayer 찾기 (UI 레이어)
	var ui_layer : CanvasLayer = body.get_node("CanvasLayer")
	var viewport_size = get_viewport().get_visible_rect().size

	# 어두운 오버레이
	var overlay = ColorRect.new()
	overlay.name = "WarningOverlay"
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(overlay)

	# 빨간 플래시용 오버레이
	var red_flash = ColorRect.new()
	red_flash.name = "RedFlash"
	red_flash.color = Color(0.8, 0, 0, 0.0)
	red_flash.anchors_preset = Control.PRESET_FULL_RECT
	red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(red_flash)

	# 경고 이미지 - 화면 상단에 좌우 꽉 채움
	var tex_rect = TextureRect.new()
	tex_rect.name = "WarningImage"
	tex_rect.texture = warning_texture
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.anchor_left = 0.0
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_top = 0.0
	tex_rect.anchor_bottom = 0.0
	# 이미지 원본 비율로 높이 계산
	var img_size = warning_texture.get_size()
	var img_height = viewport_size.x * (img_size.y / img_size.x)
	tex_rect.offset_top = 4.0
	tex_rect.offset_bottom = 4.0 + img_height
	tex_rect.offset_left = 0
	tex_rect.offset_right = 0
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(tex_rect)

	# 초기 상태: 투명
	overlay.modulate.a = 0.0
	tex_rect.modulate.a = 0.0

	# 메인 타임라인: 페이드인 → 대기 → 페이드아웃
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(tex_rect, "modulate:a", 1.0, 0.2)
	tween.tween_interval(freeze_duration - fade_out_time - 0.2)
	tween.tween_property(overlay, "modulate:a", 0.0, fade_out_time)
	tween.parallel().tween_property(tex_rect, "modulate:a", 0.0, fade_out_time)
	tween.parallel().tween_property(red_flash, "color:a", 0.0, fade_out_time)
	tween.tween_callback(func():
		body.set_physics_process(true)
		overlay.queue_free()
		tex_rect.queue_free()
		red_flash.queue_free()
		_start_challenge(body)
	)

	# 빨간 플래시 반복 (별도 트윈으로 반짝임 루프)
	_start_red_flash_loop(red_flash, freeze_duration)

func _start_challenge(body: CharacterBody2D) -> void:
	challenged_player = body
	challenge_start_score = PlayerStats.score
	challenge_remaining = challenge_duration
	challenge_active = true

	var ui_layer : CanvasLayer = body.get_node("CanvasLayer")
	challenge_label = Label.new()
	challenge_label.name = "ChallengeCountdown"
	challenge_label.text = _format_time(challenge_remaining)
	challenge_label.anchor_left = 0.5
	challenge_label.anchor_right = 0.5
	challenge_label.anchor_top = 0.0
	challenge_label.anchor_bottom = 0.0
	challenge_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	challenge_label.offset_top = countdown_top_offset
	challenge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if countdown_font:
		challenge_label.add_theme_font_override("font", countdown_font)
	challenge_label.add_theme_font_size_override("font_size", countdown_font_size)
	challenge_label.add_theme_color_override("font_color", countdown_font_color)
	challenge_label.add_theme_color_override("font_outline_color", countdown_outline_color)
	challenge_label.add_theme_constant_override("outline_size", countdown_outline_size)
	ui_layer.add_child(challenge_label)

func _process(delta: float) -> void:
	if not challenge_active:
		return
	if PlayerStats.score - challenge_start_score >= required_points:
		_end_challenge(true)
		return
	challenge_remaining -= delta
	if challenge_remaining <= 0.0:
		_end_challenge(false)
		return
	if challenge_label and is_instance_valid(challenge_label):
		challenge_label.text = _format_time(challenge_remaining)

func _end_challenge(success: bool) -> void:
	challenge_active = false
	if challenge_label and is_instance_valid(challenge_label):
		challenge_label.queue_free()
	challenge_label = null
	if not success and is_instance_valid(challenged_player):
		challenged_player.take_damage(challenged_player.health)

func _format_time(seconds: float) -> String:
	var total : int = int(ceil(seconds))
	if total < 0:
		total = 0
	var m : int = total / 60
	var s : int = total % 60
	return "%02d:%02d" % [m, s]

func _start_red_flash_loop(red_flash: ColorRect, duration: float) -> void:
	var flash_tween = create_tween()
	# 반짝임 횟수: 0.4초 간격으로 반복
	var flash_count = int(duration / 0.4)
	for i in flash_count:
		flash_tween.tween_property(red_flash, "color:a", 0.3, 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		flash_tween.tween_property(red_flash, "color:a", 0.0, 0.25)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
