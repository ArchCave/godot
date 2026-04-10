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
	
func _on_timer_timeout() -> void:
	is_coin = true
	sprite.visible      = false
	anim_sprite.visible = true
	anim_sprite.play("spin")
	collision.disabled  = false
	
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	
	body.increase_score(1)
	queue_free()
