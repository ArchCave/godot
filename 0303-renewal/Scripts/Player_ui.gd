extends CanvasLayer
@onready var health_container = $HealthContainer
@onready var energy_container = $EnergyContainer
var hearts : Array = []
var energy : Array = []
@onready var heart_score_text : Label = $HealthContainer/HeartScoreText
@onready var energy_score_text : Label = $EnergyContainer/EnergyScoreText
@onready var player_node = get_parent()

func _ready():
	# Label을 제외한 Sprite 자식만 필터링
	for child in health_container.get_children():
		if child is not Label:
			hearts.append(child)
	for child in energy_container.get_children():
		if child is not Label:
			energy.append(child)

	player_node.OnUpdateHealth.connect(_update_hearts)
	player_node.OnUpdateHealth.connect(_update_heart_score)
	player_node.OnUpdateScore.connect(_update_energy)
	player_node.OnUpdateScore.connect(_update_energy_score)
	_update_heart_score(player_node.health)
	_update_energy_score(PlayerStats.score)

func _update_hearts(health: int):
	for i in len(hearts):
		hearts[i].visible = i < health

func _update_heart_score(hp: int):
	heart_score_text.text = str(hp)

func _update_energy_score(score: int):
	energy_score_text.text = str(score)

func _update_energy(score: int):
	for i in len(energy):
		energy[i].visible = i < score
