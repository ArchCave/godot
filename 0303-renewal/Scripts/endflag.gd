extends Area2D
## 캐릭터별 종료지점.
## character_id가 PlayerStats에서 선택된 캐릭터와 일치할 때만 보이고 활성화되며,
## 일치하지 않는 EndFlag는 visible=false + 감지/충돌 OFF 상태가 된다.
## (queue_free 안 함 — 트리에는 남아있고 단지 비활성/숨김.)
##
## 한 레벨에 캐릭터 수만큼(보통 3개) 인스턴스를 떨어뜨려서 사용한다.
## character_id를 비워두면 모든 캐릭터에 대해 활성화 (구버전 호환 / 폴백).

@export var scene_to_load : PackedScene
@export var character_id: StringName = &""

@onready var anim_sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

var triggered : bool = false

func _ready():
	var ps := get_node_or_null("/root/PlayerStats")
	var selected_id: StringName = &""
	if ps != null and ps.has_method("get_selected"):
		var data = ps.get_selected()
		if data != null:
			selected_id = data.id

	if character_id != &"" and character_id != selected_id:
		# 비매칭 캐릭터의 EndFlag: 숨기고 감지/충돌 OFF
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		collision.set_deferred("disabled", true)
		return

	# 매칭: 보이게 + 활성화
	visible = true
	anim_sprite.visible = true
	anim_sprite.animation_finished.connect(_on_animation_finished)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if not body.is_in_group("Player"):
		return
	triggered = true
	# physics 멈추기 전에 idle 애니메이션으로 전환 — 그냥 멈추면 walk/jump 그대로 굳음.
	if body.has_method("play_anim"):
		body.play_anim("Idle")
	body.set_physics_process(false)
	collision.set_deferred("disabled", true)
	anim_sprite.play("end")

func _on_animation_finished() -> void:
	if not triggered:
		return
	get_tree().change_scene_to_packed(scene_to_load)
