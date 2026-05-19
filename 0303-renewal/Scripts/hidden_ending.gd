extends Area2D

@export var menu_scene : PackedScene = preload("res://Scenes/main_menu.tscn")
@export var fade_duration : float = 2.0
@export var wait_duration : float = 8.0

@onready var sprite : Sprite2D = $Sprite2D
@onready var collision : CollisionShape2D = $hidden_end_collision

var triggered : bool = false

func _ready() -> void:
	sprite.visible = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body : Node2D) -> void:
	if triggered:
		return
	if not body.is_in_group("Player"):
		return
	triggered = true
	collision.set_deferred("disabled", true)
	_start_sequence(body)

func _start_sequence(player : Node2D) -> void:
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if player.has_method("set_process"):
		player.set_process(false)
	if "velocity" in player:
		player.velocity = Vector2.ZERO

	var scene_root : Node = get_tree().get_current_scene()

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	scene_root.add_child(fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	var sprite_layer := CanvasLayer.new()
	sprite_layer.layer = 101
	scene_root.add_child(sprite_layer)

	var original_scale : Vector2 = sprite.scale
	var original_rotation : float = sprite.rotation
	sprite.get_parent().remove_child(sprite)
	sprite_layer.add_child(sprite)
	sprite.scale = original_scale
	sprite.rotation = original_rotation
	sprite.position = get_viewport().get_visible_rect().size * 0.5
	sprite.visible = true

	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var remaining : float = max(0.0, wait_duration - fade_duration)
	if remaining > 0.0:
		tween.tween_interval(remaining)
	tween.tween_callback(_go_to_main)

func _go_to_main() -> void:
	get_tree().change_scene_to_packed(menu_scene)
