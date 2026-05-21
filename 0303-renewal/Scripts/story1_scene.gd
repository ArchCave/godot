extends Control

@onready var story1: Sprite2D = $story1
@onready var story2: Sprite2D = $story2
@onready var story3: Sprite2D = $story3

# Per-character narrative sprite + starting level.
# Falls back to bird (story1 / level_1) if the selected id is unknown.
const ROUTES := {
	&"bird":       { "sprite": "story1", "next": "res://Scenes/level_1.tscn" },
	&"researcher": { "sprite": "story2", "next": "res://Scenes/level_7.tscn" },
	&"planner":    { "sprite": "story3", "next": "res://Scenes/level_6.tscn" },
}

var next_scene : String = "res://Scenes/level_1.tscn"

var seq : Tween

func _ready() -> void:
	var route : Dictionary = ROUTES.get(PlayerStats.selected_character_id, ROUTES[&"bird"])
	next_scene = route["next"]

	story1.visible = false
	story2.visible = false
	story3.visible = false

	var active : Sprite2D = get_node(route["sprite"])
	active.visible = true
	active.modulate.a = 0.0

	seq = create_tween()
	seq.tween_property(active, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_interval(5.0)
	seq.tween_property(active, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	seq.tween_callback(_go_to_game)

func _on_skip_pressed() -> void:
	if seq and seq.is_running():
		seq.kill()
	_go_to_game()

func _go_to_game() -> void:
	get_tree().change_scene_to_file(next_scene)
