extends Area2D

@export var scene_to_load : PackedScene
@onready var anim_sprite = $AnimatedSprite2D
@onready var collision   = $CollisionShape2D

func _ready():
	anim_sprite.visible = true
	anim_sprite.animation_finished.connect(_on_animation_finished)
	
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	body.set_physics_process(false)
	
	anim_sprite.play("end")
	
func _on_animation_finished() -> void:
	get_tree().change_scene_to_packed(scene_to_load)
