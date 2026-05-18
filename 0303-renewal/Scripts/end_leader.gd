extends Area2D

const NEGOTIATING_THRESHOLD : int = 30
const ENDING_THRESHOLD : int = 31
const ENDING_DELAY : float = 10.0
const FADE_DURATION : float = 0.3
const ENDING_SCENE : String = "res://Scenes/ending_scene.tscn"

@onready var ending_message : Sprite2D = $ending_message
@onready var negotiating_bird_message : Sprite2D = $negotiating_bird_message

var player : Node2D = null
var player_inside : bool = false
var poop_count : int = 0
var ending_started : bool = false
var negotiating_y : float = 0.0

func _ready() -> void:
	ending_message.visible = false
	negotiating_bird_message.visible = false
	negotiating_y = negotiating_bird_message.global_position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	player = body
	player_inside = true
	_connect_player_signals(body)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	player_inside = false
	if not ending_started:
		_reset_messages()

func _connect_player_signals(p: Node2D) -> void:
	if p.has_signal("OnPoopSpawned") and not p.is_connected("OnPoopSpawned", _on_player_poop):
		p.OnPoopSpawned.connect(_on_player_poop)
	if p.has_signal("OnAttackFired") and not p.is_connected("OnAttackFired", _on_player_attack):
		p.OnAttackFired.connect(_on_player_attack)

func _on_player_poop() -> void:
	if ending_started or not player_inside or player == null:
		return
	poop_count += 1
	if poop_count <= NEGOTIATING_THRESHOLD:
		negotiating_bird_message.visible = true
		negotiating_bird_message.global_position = Vector2(player.global_position.x, negotiating_y)
	elif poop_count >= ENDING_THRESHOLD:
		negotiating_bird_message.visible = false
		ending_message.visible = true
		_start_ending_sequence()

func _on_player_attack() -> void:
	if ending_started:
		return
	_reset_messages()

func _reset_messages() -> void:
	poop_count = 0
	ending_message.visible = false
	negotiating_bird_message.visible = false

func _start_ending_sequence() -> void:
	ending_started = true
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	var t := create_tween()
	t.tween_interval(ENDING_DELAY)
	t.tween_property(rect, "color:a", 1.0, FADE_DURATION)
	t.tween_callback(func(): get_tree().change_scene_to_file(ENDING_SCENE))
