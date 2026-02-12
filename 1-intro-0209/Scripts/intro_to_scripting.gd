extends Node2D

func _ready ():
	var score: int = 100
	var won = false
	_has_won(score)

	
func _process(delta):
	pass

func _has_won (score: int) -> bool:
	if score >= 100:
		return true
	else:
		return false
		print("YOU WON", "score: ", score)

	

func _welcome_message ():
	print("welcome to the game")
	
