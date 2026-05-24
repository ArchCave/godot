extends Area2D
## 망가진 드론 (망가진 호버 모션 + 코인 드롭).
## - 한쪽으로 기울어진 채 덜덜덜 떨고 있음 (정상 호버가 아닌 고장난 상태)
## - 플레이어가 부딪히면 그 자리에 poop_coin 1개를 drop_ready로 spawn하고 본체는 페이드아웃
##   → 플레이어가 코인을 줍는 순간 점수 +1 (poop_coin._on_body_entered가 처리)
##
## Enemy.tscn(비주얼)을 인스턴스화한 뒤 이 스크립트로 script_override해서 사용.

## 드롭할 코인 씬 (poop_coin과 동일한 픽업 동작 제공).
@export var coin_scene : PackedScene = preload("res://Scenes/poop_coin.tscn")
## 평소 기울어 있는 정도 (음수: 왼쪽으로 기울어짐).
@export var base_tilt_degrees : float = -16.0
## 위치 떨림 진폭 (px).
@export var shake_intensity : float = 1.0
## 회전 떨림 추가 각도 (base_tilt 위에 +/- 흔들림).
@export var tilt_jitter_degrees : float = 6.0
## 드론이 사라지는 페이드 시간.
@export var fade_duration : float = 0.3
## 픽업 효과음 (옵션).
@export var pickup_sound : AudioStream

@onready var sprite : Sprite2D = $Sprite2D
@onready var anim : AnimationPlayer = get_node_or_null("AnimationPlayer")

var _origin : Vector2
var _time : float = 0.0
var _picked : bool = false

func _ready() -> void:
	add_to_group("Item")
	body_entered.connect(_on_body_entered)
	_origin = position
	# 초기 기울기 적용 (이후 _process에서 jitter가 매 프레임 덮어씀)
	sprite.rotation_degrees = base_tilt_degrees
	# Enemy.tscn 기본 "drone" frame 루프는 그대로 재생 (프로펠러 회전 비주얼).
	if anim and anim.has_animation("drone"):
		anim.play("drone")

func _process(delta: float) -> void:
	if _picked:
		return
	_time += delta
	# 망가진 호버: 여러 주파수의 sin/cos를 겹쳐서 불규칙 덜덜 떨림.
	# 빠른 잔진동 + 느린 큰 흔들림 → "고장난 모터" 느낌.
	var shake_x : float = sin(_time * 23.0) * shake_intensity \
		+ sin(_time * 13.7) * shake_intensity * 0.5
	var shake_y : float = cos(_time * 19.0) * shake_intensity \
		+ sin(_time * 11.3) * shake_intensity * 0.5
	position = _origin + Vector2(shake_x, shake_y)
	# 기울어진 상태에서 추가 회전 떨림.
	sprite.rotation_degrees = base_tilt_degrees \
		+ sin(_time * 17.0) * tilt_jitter_degrees \
		+ sin(_time * 9.3) * tilt_jitter_degrees * 0.4

func _on_body_entered(body: Node2D) -> void:
	if _picked:
		return
	if not body.is_in_group("Player"):
		return
	_picked = true
	_drop_coin_and_die()

## 그 자리에 코인 1개를 drop_ready로 spawn (위로 살짝 튀어올랐다 떨어짐).
## 드론 본체는 살짝 위로 떠오르며 페이드아웃 → queue_free.
func _drop_coin_and_die() -> void:
	var parent := get_parent()
	if parent != null and coin_scene != null:
		var coin := coin_scene.instantiate()
		if coin is Node2D:
			(coin as Node2D).global_position = global_position
		if "drop_ready" in coin:
			coin.drop_ready = true
		if "velocity_y" in coin:
			coin.velocity_y = -90.0  # 위로 살짝 튀어오름
		if "velocity_x" in coin:
			coin.velocity_x = randf_range(-20.0, 20.0)  # 좌/우로 살짝 흩어짐
		parent.call_deferred("add_child", coin)
	# 픽업 효과음
	if pickup_sound != null:
		var p := AudioStreamPlayer2D.new()
		p.stream = pickup_sound
		p.autoplay = true
		parent.add_child(p)
		p.global_position = global_position
		p.finished.connect(p.queue_free)
	# 드론 페이드아웃 (감지는 즉시 OFF)
	set_deferred("monitoring", false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, fade_duration)
	t.tween_property(self, "position:y", position.y - 4.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(queue_free)
