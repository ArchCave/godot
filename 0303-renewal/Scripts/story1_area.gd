extends Area2D

@export var fade_in_time : float = 0.8
@export var fade_out_time : float = 0.6
@export var free_time_before : float = 4.0   # 진입 직후 자유 이동
@export var hold_time : float = 2.0           # 정지(홀드)
@export var free_time_after : float = 4.0     # 홀드 후 다시 자유 이동
@export var overlay_alpha : float = 0.9
@export var image_y_offset : float = -25.0
@export var text_y_offset : float = 30.0

@onready var collision_shape : CollisionShape2D = $CollisionShape2D
@onready var hidden_node : Node = get_node("../Hidden")
@onready var intro_bg : Sprite2D = hidden_node.get_node("IntroBackground")
@onready var story_image1 : Sprite2D = hidden_node.get_node("story_image1")
@onready var story_text1 : Sprite2D = hidden_node.get_node("story_text1")

var triggered : bool = false
var player : CharacterBody2D = null
var _active : bool = false
var _player_z : int = 0

func _ready() -> void:
	intro_bg.modulate.a = 0.0
	intro_bg.z_index = 50
	for s in [story_image1, story_text1]:
		s.modulate.a = 0.0
		# 어두운 오버레이(50) + 플레이어(51) 위에 그려지도록 이미지/텍스트는 52.
		s.z_index = 52
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if not body.is_in_group("Player"):
		return
	triggered = true
	player = body
	_run_sequence()

func _process(_delta: float) -> void:
	# 시퀀스 동안 오버레이/이미지가 항상 화면 중심에 보이도록 매 프레임 따라다님.
	if _active:
		_position_visuals()

func _position_visuals() -> void:
	var cam : Camera2D = _get_camera()
	if cam == null:
		return
	var center : Vector2 = cam.get_screen_center_position()
	intro_bg.global_position = center
	story_image1.global_position = Vector2(center.x, center.y + image_y_offset)
	story_text1.global_position = Vector2(center.x, center.y + text_y_offset)

func _run_sequence() -> void:
	_active = true
	# 0.9 어두운 오버레이 위에서도 캐릭터가 보이도록 플레이어를 잠시 올린다.
	_player_z = player.z_index
	player.z_index = 51
	_position_visuals()

	# 페이드 인 — 진입과 동시에 이미지/텍스트 표시 (자유 이동은 그대로 가능)
	var fin : Tween = create_tween()
	fin.tween_property(intro_bg, "modulate:a", overlay_alpha, fade_in_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fin.parallel().tween_property(story_image1, "modulate:a", 1.0, fade_in_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fin.parallel().tween_property(story_text1, "modulate:a", 1.0, fade_in_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 1) 자유 이동
	await get_tree().create_timer(free_time_before).timeout
	if not is_instance_valid(player):
		_active = false
		return

	# 2) 정지(홀드)
	player.velocity = Vector2.ZERO
	if player.has_method("play_anim"):
		player.play_anim("Idle")
	player.set_physics_process(false)
	await get_tree().create_timer(hold_time).timeout

	# 3) 다시 자유 이동
	if is_instance_valid(player):
		player.set_physics_process(true)
	await get_tree().create_timer(free_time_after).timeout

	# 페이드 아웃 후 정리
	var fout : Tween = create_tween()
	fout.tween_property(story_image1, "modulate:a", 0.0, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fout.parallel().tween_property(story_text1, "modulate:a", 0.0, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fout.parallel().tween_property(intro_bg, "modulate:a", 0.0, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fout.finished
	_finish()

func _get_camera() -> Camera2D:
	# 카메라가 플레이어 자식(레거시)일 수도, 레벨 직속(분리형)일 수도 있어 둘 다 대응.
	if is_instance_valid(player) and player.has_node("Camera2D_Level2"):
		return player.get_node("Camera2D_Level2")
	if has_node("../Camera2D_Level2"):
		return get_node("../Camera2D_Level2")
	return get_viewport().get_camera_2d()

func _finish() -> void:
	_active = false
	if is_instance_valid(player):
		player.set_physics_process(true)
		player.z_index = _player_z
