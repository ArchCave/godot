extends Area2D

@export var fade_in_time : float = 0.8
@export var fade_out_time : float = 0.6
@export var hold_time : float = 5.0
@export var initial_delay : float = 0.6
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
var seq : Tween

func _ready() -> void:
	intro_bg.modulate.a = 0.0
	intro_bg.z_index = 50
	for s in [story_image1, story_text1]:
		s.modulate.a = 0.0
		s.z_index = 51
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if not body.is_in_group("Player"):
		return
	triggered = true
	player = body
	_start_sequence()

func _start_sequence() -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	var center : Vector2 = _pin_camera()
	var anchor_x : float = collision_shape.global_position.x

	intro_bg.global_position = center
	story_image1.global_position = Vector2(anchor_x, center.y + image_y_offset)
	story_text1.global_position = Vector2(anchor_x, center.y + text_y_offset)

	seq = create_tween()
	seq.tween_property(intro_bg, "modulate:a", overlay_alpha, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(initial_delay)

	seq.tween_property(story_image1, "modulate:a", 1.0, fade_in_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.parallel().tween_property(story_text1, "modulate:a", 1.0, fade_in_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(hold_time)

	seq.tween_property(story_image1, "modulate:a", 0.0, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.parallel().tween_property(story_text1, "modulate:a", 0.0, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.parallel().tween_property(intro_bg, "modulate:a", 0.0, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_callback(_finish)

func _get_camera() -> Camera2D:
	# 카메라가 플레이어 자식(레거시)일 수도, 레벨 직속(분리형)일 수도 있어 둘 다 대응.
	if player != null and player.has_node("Camera2D_Level2"):
		return player.get_node("Camera2D_Level2")
	if has_node("../Camera2D_Level2"):
		return get_node("../Camera2D_Level2")
	return get_viewport().get_camera_2d()

func _pin_camera() -> Vector2:
	var cam : Camera2D = _get_camera()
	if cam == null:
		return player.global_position
	var rendered : Vector2 = cam.get_screen_center_position()
	cam.position_smoothing_enabled = false
	cam.global_position = rendered
	return rendered

func _release_camera() -> void:
	var cam : Camera2D = _get_camera()
	if cam == null:
		return
	cam.position = Vector2.ZERO
	cam.position_smoothing_enabled = true

func _finish() -> void:
	if is_instance_valid(player):
		_release_camera()
		player.set_physics_process(true)
