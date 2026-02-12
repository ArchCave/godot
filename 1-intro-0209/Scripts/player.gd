extends CharacterBody2D
var speed :float =100

func _ready() -> void:
	$AnimatedSprite2D.play("fly")

func _physics_process(_delta):
	velocity = Vector2.ZERO

	if Input.is_key_pressed(KEY_RIGHT):
		velocity.x += speed
		$AnimatedSprite2D.flip_h = false   # 오른쪽 보기

	if Input.is_key_pressed(KEY_LEFT):
		velocity.x -= speed
		$AnimatedSprite2D.flip_h = true    # 왼쪽 보기

	if Input.is_key_pressed(KEY_UP):
		velocity.y -= speed

	if Input.is_key_pressed(KEY_DOWN):
		velocity.y += speed

	move_and_slide()
