# 패턴: 캐릭터별 시작 위치 (`PlayerSpawner`)

> "같은 레벨 안에서 bird는 왼쪽 절벽에서 시작하고, researcher는 가운데 사다리, planner는 오른쪽 문에서 시작" 같은 경우.

핵심 파일: `0303-renewal/Scripts/player_spawner.gd`, `Scenes/PlayerSpawner.tscn`

---

## 1. 동작 개요

`PlayerSpawner`는 `Marker2D`에 스크립트가 붙은 형태. 레벨 씬 안에 **캐릭터 수만큼(보통 3개)** 인스턴스를 떨어뜨려 놓는다. 각 스포너의 `character_id`를 다르게 지정.

`_ready()`에서:
1. `PlayerStats.get_selected().id`를 가져옴.
2. **매칭이면** → 자기 위치에 `Player.tscn`(또는 `CharacterData.scene`)을 instantiate → 그 위치를 자기 좌표로 세팅 → `"Player"` 그룹 추가 → 자기 자신은 `queue_free()`.
3. **불일치면** → 즉시 `queue_free()` (트리에서 사라짐).
4. `character_id`를 비워두면 → **모든 캐릭터에 매칭** (구버전 호환 / 한 캐릭터만 있는 레벨용).

결과: 어떤 캐릭터를 골랐든 그 캐릭터용 스포너 위치에서 Player가 1명만 살아남는다.

---

## 2. 셋업 절차

### Step 1 — 레벨에 스포너 인스턴스화
1. 레벨 씬(예: `level_7.tscn`)을 연다.
2. Scene 탭 → Instantiate Child Scene → `res://Scenes/PlayerSpawner.tscn` 선택.
3. 원하는 위치로 드래그.
4. 캐릭터 수만큼 반복(3개).

### Step 2 — `character_id` 지정
각 스포너의 인스펙터에서 **Character Id** 필드에 `bird` / `researcher` / `planner` 중 하나 입력.

> 비워두면 모든 캐릭터가 그 위치에서 스폰 → 같은 레벨에 빈 칸짜리 스포너가 여러 개면 두 명이 동시에 스폰돼서 카메라가 혼란스러워진다. **빈 칸은 레벨당 최대 1개**.

### Step 3 — `fallback_scene` (보통 그대로)
기본값 `res://Scenes/Player.tscn`. 캐릭터가 자기 `.tres`에 `scene` 필드를 안 지정했을 때 이게 쓰인다. 모든 캐릭터가 공통 `Player.tscn`을 쓰는 현재 구조에선 만질 필요 없다.

### Step 4 — 기존 Player 노드는 제거
PlayerSpawner를 쓰는 레벨에는 **이미 배치된 Player.tscn 인스턴스가 있으면 안 된다**. 둘 다 살아남아서 화면이 이상해진다. 레벨 트리에서 Player 노드를 삭제하고 스포너로만 운영.

---

## 3. 새 레벨 만들 때 권장 구조

```
level_X.tscn (Node2D root)
├── TileMapLayer (BG)
├── TileMapLayer (FG/collision)
├── TileMapLayer (Ladders, "Ladders" 그룹)   ← 사다리가 있다면
├── PlayerSpawner (Marker2D, character_id = "bird")
├── PlayerSpawner (Marker2D, character_id = "researcher")
├── PlayerSpawner (Marker2D, character_id = "planner")
├── Enemies/
│   ├── Drone1 (enemy_to = "bird" 등)
│   └── ...
├── EndFlag (character_id = "bird", scene_to_load = level_2)
├── EndFlag (character_id = "researcher", scene_to_load = level_8)
├── EndFlag (character_id = "planner", scene_to_load = level_5)
└── Camera2D (smooth_camera.gd, Player 그룹 자동 추적)
```

카메라는 `smooth_camera.gd`가 자동으로 "Player" 그룹의 첫 노드를 찾으므로, Camera를 Player의 자식으로 두지 않아도 동작한다.

---

## 4. 직접 짠 새 스폰 방식이 필요한 경우

`PlayerSpawner`로 부족한 케이스(예: 체크포인트, 부활):

```gdscript
# 어디서든:
var ps = get_node("/root/PlayerStats")
var scene = ps.get_selected_scene() if ps.get_selected_scene() else preload("res://Scenes/Player.tscn")
var player = scene.instantiate()
player.position = checkpoint_position
player.add_to_group("Player")
get_parent().call_deferred("add_child", player)
```

`call_deferred("add_child", ...)`를 쓰는 이유는 `_physics_process` 도중 트리 구조 변경 시 안전성을 위함. 기존 PlayerSpawner도 동일.

---

## 5. 디버그 팁

- **스포너가 다 사라졌는데 Player가 안 보임**: `character_id` 오타. `bird` 라고 쳤지만 PlayerStats에선 `&"bird"`라서 매칭은 됨. **대소문자**나 띄어쓰기를 확인.
- **Player가 2명 스폰됨**: 레벨에 PlayerSpawner와 기존 Player 노드가 공존. Player 노드 삭제.
- **Player가 카메라 밖**: smooth_camera가 "Player" 그룹을 찾는 데 1프레임 지연이 있음. `_ready()`에서 `await get_tree().process_frame` 후 해결되므로 시각적 깜빡임이 1프레임 정도 발생할 수 있음. 신경 쓰이면 `Camera2D.position_smoothing_enabled = false`로 시작 → 첫 lock 후 true.
- **점프 플랫폼이 플레이어를 인식 못 함**: `jump_platform.gd`는 `_player`를 그룹에서 찾는다. Player가 `"Player"` 그룹에 있어야 함. PlayerSpawner가 자동으로 넣어주지만, 수동 인스턴스화 시 빠뜨릴 수 있음.

---

## 6. 관련 패턴

- 캐릭터별 출구 → [endflag_per_character.md](endflag_per_character.md)
- 캐릭터별 적 → [per_character_enemy.md](per_character_enemy.md)
