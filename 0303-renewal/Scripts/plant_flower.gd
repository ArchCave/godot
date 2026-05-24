extends Node2D
## Planner의 스킬: 꽃 심기. 한 번 심으면 사라지지 않고 맵이 끝날 때까지 존재한다.
##
## player.gd._spawn_poop()에서 ray.is_colliding() 결과로 ground_y에 스폰되므로,
## Node2D 원점은 땅 표면이다. Sprite2D는 offset.y < 0 으로 위쪽에 그리고
## 회전 피벗(=Node2D 원점)이 줄기 밑둥에 오게 만든다 → sway가 자연스럽게 흔들림.
##
## 애니메이션: still_duration 만큼 정지 → sway_duration 동안 좌우 살랑살랑 → 반복.
## queue_free 없음 — 씬 전환 시점에 부모와 함께 자동 정리됨.
##
## 새 캐릭터가 같은 패턴의 스킬을 원할 경우 본 씬을 그대로 skill_scene으로 지정하면 됨.

## 정지 페이즈 길이 (초).
@export var still_duration : float = 1.6
## 살랑 페이즈 길이 (초). 0 → +각 → -각 → 0 의 4분할로 진행.
@export var sway_duration : float = 1.4
## 한쪽 최대 기울기 (도).
@export var sway_angle_deg : float = 7.0
## 스폰 위치에 더해질 Y 오프셋 (음수면 위). ground_y에 너무 박힌 듯 보이지 않게 보정.
@export var ground_offset_y : float = -1.0
## 스폰 시 살짝 위에서 떨어지듯 페이드인.
@export var spawn_pop_height : float = 5.0
@export var spawn_pop_duration : float = 0.25

@onready var sprite : Sprite2D = $Sprite2D

func _ready() -> void:
	position.y += ground_offset_y
	_play_spawn_anim()
	_start_sway_loop()

func _play_spawn_anim() -> void:
	var rest_y : float = sprite.position.y
	sprite.position.y -= spawn_pop_height
	sprite.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(sprite, "modulate:a", 1.0, spawn_pop_duration)
	t.tween_property(sprite, "position:y", rest_y, spawn_pop_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _start_sway_loop() -> void:
	var rad : float = deg_to_rad(sway_angle_deg)
	var quarter : float = sway_duration * 0.25
	# 첫 사이클 진입 전 0 ~ (still+sway) 랜덤 대기 — 위상 분산용. await 로 처리해서
	# 루프 본체에 포함되지 않게 한다 (set_loops 는 tween 전체를 반복하므로).
	if still_duration + sway_duration > 0.0:
		await get_tree().create_timer(randf_range(0.0, still_duration + sway_duration)).timeout
	if not is_inside_tree():
		return
	var t := create_tween()
	t.set_loops()
	t.tween_interval(still_duration)
	t.tween_property(sprite, "rotation", rad, quarter)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sprite, "rotation", -rad, quarter * 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sprite, "rotation", 0.0, quarter)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
