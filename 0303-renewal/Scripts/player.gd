extends CharacterBody2D

@export var move_speed : float = 25
@export var gravity : float = 420
@export var jump_force : float = 100
@export var health : int = 3

var move_input : float

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	anim.play("Idle")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	move_input = Input.get_axis("ui_left", "ui_right")

	if Input.is_action_just_pressed("ui_jump") and is_on_floor():
		velocity.y = -jump_force

	if Input.is_action_just_pressed("ui_attack"):
		print("Attack")

	if Input.is_action_just_pressed("ui_skill"):
		print("Skill")

	velocity.x = move_input * move_speed

	if move_input != 0:
		sprite.flip_h = move_input < 0

	move_and_slide()

	update_animation()

func update_animation():
	if not is_on_floor():
		play_anim("Jump")
	elif move_input != 0:
		play_anim("Walk")
	else:
		play_anim("Idle")

func play_anim(anim_name: String):
	if anim.current_animation != anim_name:
		anim.play(anim_name)

func take_damage(amount : int):
	health -= amount
	print(take_damage)
	if health <=0:
		call_deferred("game_over")

func game_over():
	get_tree().change_scene_to_file("res://Scenes/Enemy.tscn")
	
