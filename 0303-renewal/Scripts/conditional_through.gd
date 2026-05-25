extends Area2D
## level_8용 조건부 통과 블록.
## 기본적으로 자식 StaticBody2D가 길을 막는다.
## 플레이어가 해당 Area2D에 도달했을 때 "이 레벨(level_8)에서" BirdEnemy를 한 마리도
## 죽이지 않았으면 자기 자신(Area2D + StaticBody2D 자식 모두)을 제거해서 길을 연다.
##
## bird_enemy_kills는 런(run) 전역 누적 카운터라 이전 맵의 킬까지 포함된다. 이전 맵에서
## 죽인 새는 무시하기 위해, 레벨 로드 시점(_ready)의 값을 기준선으로 잡고 그 이후로
## 늘지 않았는지(= 이 레벨에서 죽인 새가 0마리인지)로 판정한다.

var _kills_at_level_start : int = 0

func _ready() -> void:
	_kills_at_level_start = PlayerStats.bird_enemy_kills
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if PlayerStats.bird_enemy_kills == _kills_at_level_start:
		queue_free()
