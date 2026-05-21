@tool
extends Marker2D
## 캐릭터별 스폰 마커.
## character_id가 PlayerStats에서 선택된 캐릭터와 일치할 때만 활성화되며,
## 자기 위치에 Player.tscn(또는 캐릭터별 fallback_scene)을 인스턴스화한 뒤
## 자신은 사라진다. 일치하지 않는 스포너는 즉시 queue_free.
##
## 한 레벨에 캐릭터 수만큼(보통 3개) 인스턴스를 떨어뜨려서 사용한다.
## character_id를 비워두면 모든 캐릭터에 대해 활성화 (구버전 호환 / 폴백).

@export var character_id: StringName = &""
@export var fallback_scene: PackedScene = preload("res://Scenes/Player.tscn")
@export var add_to_group_name: StringName = &"Player"

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var ps := get_node_or_null("/root/PlayerStats")
	var selected_id: StringName = &""
	if ps != null and ps.has_method("get_selected"):
		var data = ps.get_selected()
		if data != null:
			selected_id = data.id

	if character_id != &"" and character_id != selected_id:
		queue_free()
		return

	var scene_to_spawn: PackedScene = null
	if ps != null and ps.has_method("get_selected_scene"):
		scene_to_spawn = ps.get_selected_scene()
	if scene_to_spawn == null:
		scene_to_spawn = fallback_scene
	if scene_to_spawn == null:
		push_error("PlayerSpawner: no scene to spawn.")
		queue_free()
		return

	var player: Node = scene_to_spawn.instantiate()
	if player is Node2D:
		(player as Node2D).position = position
	if add_to_group_name != &"":
		player.add_to_group(add_to_group_name)

	get_parent().call_deferred("add_child", player)
	call_deferred("queue_free")
