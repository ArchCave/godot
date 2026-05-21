extends Area2D
## level_8용 조건부 통과 블록.
## 기본적으로 자식 StaticBody2D가 길을 막는다.
## 플레이어가 해당 Area2D에 도달했을 때 BirdEnemy를 한 마리도 죽이지 않았으면
## 자기 자신(Area2D + StaticBody2D 자식 모두)을 제거해서 길을 연다.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if PlayerStats.bird_enemy_kills == 0:
		queue_free()
