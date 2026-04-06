extends Area2D

@onready var sprite      = $Sprite2D
@onready var anim_sprite = $AnimatedSprite2D
@onready var collision   = $CollisionShape2D
@onready var timer       = $Timer

var is_coin := false

func _ready():
	sprite.visible      = true   # 똥만 보임
	anim_sprite.visible = false  # 코인은 숨김
	collision.disabled = true
	timer.wait_time = 20.0
	timer.start()
	timer.timeout.connect(_on_timer_timeout)
	body_entered.connect(_on_body_entered)

func _on_timer_timeout() -> void:
	is_coin = true
	sprite.visible      = false
	anim_sprite.visible = true
	anim_sprite.play("spin")
	collision.disabled  = false
	
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			PlayerStats.score += 1
			queue_free()
			return

func _on_body_entered(body: Node2D) -> void:
	print("touched: ", body.name)
	print("is_coin: ", is_coin)           # 이게 있어야 함
	print("player 그룹: ", body.is_in_group("Player"))  # 이것도
	if not is_coin:
		return
	if body.is_in_group("Player"):
		PlayerStats.score += 10
		queue_free()	


#func _on_body_entered(body: Node2D) -> void:
