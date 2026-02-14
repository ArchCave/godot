extends Node3D

var score : int = 0

var score_text : Label

func _ready ():
	score_text = $ScoreText
	score_text.text = "Score: 0"

func increase_score (amount : int):
	score += amount
	score_text.text = "Score: " + str(score)
