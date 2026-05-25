extends Area2D

@export var speed : float = 120.0
@export var damage : int = 1
@export var max_range : float = 64.0
var direction : float = 1.0
var traveled : float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# direction은 인스턴스 생성 후 외부에서 설정되므로
	# _ready 시점에서 올바른 방향을 반영
	anim_sprite.flip_h = direction < 0
	anim_sprite.play("fire")

func _physics_process(delta):
	var move = speed * direction * delta
	position.x += move
	traveled += abs(move)
	if traveled >= max_range:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("Enemy"):
		return
	if area.has_method("take_bullet_damage"):
		area.take_bullet_damage(damage)
		Sfx.play("enemy_hit")   # 적이 공격받을 때
	queue_free()
