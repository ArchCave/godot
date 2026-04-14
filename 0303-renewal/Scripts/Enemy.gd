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
	_flash_hit()
	if health <= 0:
		queue_free()

func _flash_hit() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	body.take_damage(1)
