extends CanvasLayer
@onready var health_container = $HealthContainer
@onready var energy_container = $EnergyContainer
var hearts : Array = []
var energy: Array = []
@onready var heart_score_text : Label = $HealthContainer/HeartScoreText
@onready var energy_score_text : Label = $EnergyContainer/EnergyScoreText
@onready var Player = get_parent()


# Called when the node enters the scene tree for the first time.
func _ready():
	hearts = health_container.get_children()
	energy = energy_container.get_children()
	Player.OnUpdateHealth.connect(_update_hearts)
	Player.OnUpdateHealth.connect(_update_heart_score)
	Player.OnUpdateScore.connect(_update_energy)
	Player.OnUpdateScore.connect(_update_energy_score)
	_update_heart_score(Player.health)
	_update_energy_score(PlayerStats.score)


func _update_hearts (health : int):
	for i in len(hearts):
		hearts[i].visible = i <health
		
func _update_heart_score (hearts : int):
	heart_score_text.text = str(hearts)
func _update_energy_score (energy : int):
	energy_score_text.text = str(energy)
	
func _update_energy (score : int):
	for i in len(energy):
		energy[i].visible = i <score

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
