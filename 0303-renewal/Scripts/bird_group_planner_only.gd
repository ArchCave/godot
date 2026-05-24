extends Node
## Bird(Planner) 그룹 매니저 (level_1).
## 선택 캐릭터가 planner일 때만 자식 BirdEnemy들을 살려두고,
## 그 외 캐릭터에선 전부 비활성화한다 → 보이지도, 부딪히지도 않음.
##
## BirdEnemy는 본체 충돌 외에 HurtArea(Area2D)와 점프 physics를 따로 가지므로
## 단순히 visible만 끄면 안 된다. bird_enemy.gd의 deactivate()가
## (physics 정지 + hurt_area monitoring off + 충돌 shape disable + queue_free)
## 모든 비활성화를 처리하므로 그걸 그대로 사용한다.

@export var match_character_id : StringName = &"planner"

func _ready() -> void:
	if PlayerStats.selected_character_id == match_character_id:
		return
	for child in get_children():
		if child.has_method("deactivate"):
			child.deactivate()
		else:
			child.queue_free()
