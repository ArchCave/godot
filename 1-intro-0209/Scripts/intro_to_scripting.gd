extends Node2D
var game_over: bool = false
var score:int = 100
func _ready ():
	if game_over==true:
		print("Go to menu")
	else :
		print("Keep Playing")
