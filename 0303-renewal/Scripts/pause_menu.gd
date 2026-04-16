extends CanvasLayer

@onready var panel: ColorRect = $Panel

var is_paused : bool = false

func _ready():
	panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused
	panel.visible = is_paused
	get_tree().paused = is_paused

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_title_pressed() -> void:
	get_tree().paused = false
	PlayerStats.reset()
	get_tree().change_scene_to_file("res://Scenes/level_2.tscn")
