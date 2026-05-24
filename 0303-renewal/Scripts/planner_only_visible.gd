extends Node
## level_5용 자동 토글 매니저.
## 같은 씬 트리 안에서 노드 이름에 "(planner)" 가 포함된 모든 노드를 찾아서:
##   - planner 선택 시 → visible=true + 충돌 활성화
##   - 그 외 캐릭터 → visible=false + 충돌/감지 비활성
##
## 추가 노드를 토글하려면 그 노드 이름에 "(planner)" 만 넣어두면 자동 처리.
## (드론, 스프라이트, Area2D, CharacterBody2D 등 종류 무관.)

## 매칭 조건이 될 캐릭터 id. 기본 planner.
@export var match_character_id : StringName = &"planner"
## 노드 이름에 포함돼야 할 태그.
@export var name_tag : String = "(planner)"
## true 면 의미를 뒤집는다: 매칭일 때 OFF, 비매칭일 때 ON.
## 예: level_8 의 "onlyforplanner" slide — planner 일 때만 사라지고 다른 캐릭터에선 작동.
@export var invert : bool = false

func _ready() -> void:
	var is_match : bool = PlayerStats.selected_character_id == match_character_id
	if invert:
		is_match = not is_match
	# 같은 씬 트리에서 부모(보통 level 루트)부터 walk.
	var root := get_parent()
	if root == null:
		root = get_tree().current_scene
	if root != null:
		_walk(root, is_match)

func _walk(node: Node, is_match: bool) -> void:
	for child in node.get_children():
		if name_tag in child.name:
			_apply(child, is_match)
			# (planner) 노드 안쪽은 더 들어가지 않음. 그 안의 자식들은 부모와 운명 공동체.
		else:
			_walk(child, is_match)

func _apply(node: Node, is_match: bool) -> void:
	# 0) TileMapLayer 는 visible 만 끄면 충돌이 살아있으므로 enabled 도 토글.
	#    enabled=false 면 렌더링 + 물리 양쪽 모두 정지.
	if node is TileMapLayer:
		(node as TileMapLayer).enabled = is_match
	# 1) 시각: CanvasItem이면 visible 토글 (자식까지 상속).
	if node is CanvasItem:
		(node as CanvasItem).visible = is_match
	# 1.5) 태그 노드 자신이 CollisionShape2D/CollisionPolygon2D 인 경우 (예: StaticBody2D 의
	#      child shape 만 골라 끄고 싶을 때) — 자기 disabled 를 직접 토글.
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", not is_match)
	# 2) 충돌/감지: 자신이 CollisionObject2D면 monitoring/monitorable + 자식 shape도 disable.
	if node is CollisionObject2D:
		var co := node as CollisionObject2D
		if co is Area2D:
			co.set_deferred("monitoring", is_match)
			co.set_deferred("monitorable", is_match)
		# PhysicsBody2D (CharacterBody2D 등)도 collision layer/mask로는 안 끔. 자식 shape만 처리.
		for c in co.get_children():
			if c is CollisionShape2D or c is CollisionPolygon2D:
				c.set_deferred("disabled", not is_match)
	else:
		# 자식 중 충돌 노드만 따로 처리 (예: Sprite2D 그룹 안에 Area2D가 있는 케이스 대비).
		for c in node.get_children():
			if c is CollisionShape2D or c is CollisionPolygon2D:
				c.set_deferred("disabled", not is_match)
			elif c is CollisionObject2D:
				_apply(c, is_match)
