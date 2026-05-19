extends CanvasLayer

@onready var health_container = $HealthContainer
var hearts : Array = []

@onready var score_text : Label = $ScoreText

@onready var player = get_parent()

func _ready ():
	hearts = health_container.get_children()
	
	player.OnUpdateHealth.connect(_update_hearts)
	player.OnUpdateScore.connect(_update_score)
	
	_update_hearts(player.health)
	_update_score(PlayerStats.score)

func _update_hearts (health : int):
	for i in len(hearts):
		hearts[i].visible = i < health

func _update_score (score : int):
	score_text.text = "Score: " + str(score)
