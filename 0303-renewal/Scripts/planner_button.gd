extends Area2D
## Planner 전용 버튼.
##
## - PlayerStats 선택 캐릭터가 planner가 아닐 때: visible=false + monitoring/monitorable
##   비활성 + collision 비활성. 다른 캐릭터에게는 안 보이고 통과만 됨.
## - planner일 때: visible=true. Player가 영역에 진입하면 "press" 애니메이션을 1회 재생
##   (loop=false) → animation_finished 시 마지막 프레임에서 정지. 재진입해도 다시 재생 안 함.
##
## SpriteFrames의 animation 이름은 &"press" 로 가정하고, loop=false 로 설정해두면
## animation_finished 신호가 마지막 프레임 끝에서 emit 된다.

@onready var anim_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var collision : CollisionShape2D = $CollisionShape2D
## 버튼 위에 player가 올라와 있는 동안만 머리 위에 뜨는 안내 sprite.
## 진입(body_entered) → visible=true, 이탈(body_exited) → visible=false.
@onready var hover_bubble : Sprite2D = get_node_or_null("HoverBubble")

var _pressed : bool = false

func _ready() -> void:
	var selected_id : StringName = &""
	if PlayerStats.has_method("get_selected"):
		var data = PlayerStats.get_selected()
		if data != null:
			selected_id = data.id

	if selected_id != &"planner":
		# 비매칭: 숨김 + 감지/충돌 OFF (트리에는 남기되 사실상 없음 취급).
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		collision.set_deferred("disabled", true)
		return

	# 매칭: 보이게 + 첫 프레임에서 정지 상태로 대기.
	visible = true
	anim_sprite.stop()
	anim_sprite.frame = 0
	anim_sprite.animation_finished.connect(_on_anim_finished)
	if hover_bubble != null:
		hover_bubble.visible = false

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# 추가 안전장치: planner가 아닌 player가 어떻게든 닿아도 작동 안 함.
	if PlayerStats.selected_character_id != &"planner":
		return
	# hover bubble은 press 여부와 무관 — 위에 있는 동안 계속 뜸.
	if hover_bubble != null:
		hover_bubble.visible = true
	if _pressed:
		return
	_pressed = true
	anim_sprite.play("press")

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if hover_bubble != null:
		hover_bubble.visible = false

func _on_anim_finished() -> void:
	# loop=false 라서 마지막 프레임에서 멈추지만, 명시적으로 그 프레임에 고정.
	# stop() 은 frame 을 0 으로 리셋해버리므로 사용 금지 — pause() 로 현재 위치 유지.
	var frames := anim_sprite.sprite_frames
	if frames != null and frames.has_animation("press"):
		anim_sprite.frame = frames.get_frame_count("press") - 1
	anim_sprite.pause()
	_apply_press_effects()

## 버튼이 완전히 눌린 순간 맵 전체에 적용되는 효과.
## level_8 기준:
##   1) Intro_Guide3 슬램(tilemap_slam) 톱 모션을 그 자리에 정지
##   2) BirdSlamArea(bird_killer) 의 새 죽이기 효과 무효화
##   3) 맵에 존재하는 모든 BirdEnemy 비활성화 (visible=false + 충돌/감지 OFF)
## duck-typed: pause_slam / disable_kills / deactivate 메서드 유무로만 판단하므로
## 같은 인터페이스를 가진 노드가 다른 레벨에 있어도 그대로 동작.
func _apply_press_effects() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_walk_and_apply(root)

func _walk_and_apply(node: Node) -> void:
	if node.has_method("pause_slam"):
		node.pause_slam()
	if node.has_method("disable_kills"):
		node.disable_kills()
	# BirdEnemy 판별: deactivate + die_by_slam 둘 다 가진 노드만 (오탐 방지).
	if node.has_method("deactivate") and node.has_method("die_by_slam"):
		node.deactivate()
	for child in node.get_children():
		_walk_and_apply(child)
