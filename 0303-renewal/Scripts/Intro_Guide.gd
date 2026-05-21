extends Area2D
## 캐릭터 안내 트리거.
## allowed_character_id가 PlayerStats의 선택 캐릭터와 일치할 때만 안내 표시.
## 빈 값(&"")이면 모든 캐릭터에 반응 (구버전 호환 / 폴백).
##
## 사용법: 레벨에 intro_guide.tscn을 인스턴스화하고 인스펙터에서
## allowed_character_id를 bird/researcher/planner 중 골라 설정.
##
## IntroBackground는 선택사항 (없는 경우도 허용 — 배경 없이 안내만 띄울 때).

@export var allowed_character_id: StringName = &""

@onready var guide_sprite: Sprite2D = get_node_or_null("IntroGuide")
@onready var into_background: Sprite2D = get_node_or_null("IntroBackground")

func _ready() -> void:
	if guide_sprite:
		guide_sprite.visible = false
	if into_background:
		into_background.visible = false

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not _is_allowed_character():
		return
	if guide_sprite:
		guide_sprite.visible = true
	if into_background:
		into_background.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not _is_allowed_character():
		return
	if guide_sprite:
		guide_sprite.visible = false
	if into_background:
		into_background.visible = false

func _is_allowed_character() -> bool:
	if allowed_character_id == &"":
		return true
	return PlayerStats.selected_character_id == allowed_character_id
