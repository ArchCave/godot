extends Node3D

var score : int = 0

var score_text :Label

func _ready() -> void:
	score_text = $ScoreText
	score_text.text = "Score: 0"

func increase_score (amount: int):
	score += amount
	score_text.text = "Score: " + str(score)
	print(score)
	
# Called when the node enters the scene tree for the first time.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
