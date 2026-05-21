extends CharacterBody2D
## 점프하는 새 적. level_8 같이 researcher/planner가 주인공인 맵에서 사용.

@export var gravity : float = 420.0
@export var jump_force : float = 130.0
@export var jump_interval_min : float = 0.6
@export var jump_interval_max : float = 1.6
@export var horizontal_jump_speed : float = 30.0
@export var max_health : int = 2

@onready var sprite : Sprite2D = $Sprite2D
@onready var hurt_area : Area2D = $HurtArea

var health : int
var _jump_timer : float = 0.0
var _facing_dir : float = -1.0

func _ready() -> void:
	health = max_health
	_reset_jump_timer()
	hurt_area.body_entered.connect(_on_hurt_area_body_entered)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		sprite.frame = 2  # jump pose
	else:
		velocity.x = 0.0
		sprite.frame = 0  # idle/walk pose
		_jump_timer -= delta
		if _jump_timer <= 0.0:
			_jump()

	move_and_slide()

func _jump() -> void:
	velocity.y = -jump_force
	if randf() < 0.4:
		_facing_dir *= -1.0
	velocity.x = horizontal_jump_speed * _facing_dir
	sprite.flip_h = _facing_dir < 0.0
	_reset_jump_timer()

func _reset_jump_timer() -> void:
	_jump_timer = randf_range(jump_interval_min, jump_interval_max)

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(1)

## player_bullet -> enemy_hurt_area(forwarder) -> 여기로 전달됨.
func take_bullet_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		PlayerStats.bird_enemy_kills += 1
		queue_free()
