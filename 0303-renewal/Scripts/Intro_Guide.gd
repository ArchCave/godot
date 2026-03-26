extends Area2D

@onready var guide_sprite = $IntroGuide
@onready var into_background = $IntroBackground
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	guide_sprite.visible = false
	into_background.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	guide_sprite.visible = true
	into_background.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	guide_sprite.visible = false
	into_background.visible = false
