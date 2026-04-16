extends Area2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

@export var max_health : int = 8
var health : int

func _ready() -> void:
	health = max_health
	anim.play("drone")

func take_bullet_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
	else:
		_flash_hit()

func _flash_hit() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.0)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	body.take_damage(1)
