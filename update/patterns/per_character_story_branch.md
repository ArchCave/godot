# 패턴: 캐릭터별 스토리 인트로 + 시작 레벨 분기

> "캐릭터를 고르면 그 캐릭터의 인트로 스토리 컷이 나오고, 끝나면 그 캐릭터 전용 첫 레벨로 진입."

핵심 파일: `0303-renewal/Scripts/story1_scene.gd`

---

## 1. 동작 개요

`story1_scene.tscn`은 Control 루트 + 캐릭터별 컷 스프라이트(`story1` / `story2` / `story3`).

`_ready()`에서:
1. `PlayerStats.selected_character_id` 가져옴.
2. `ROUTES` dict로 매핑 — `{ "sprite": 노드 이름, "next": 다음 씬 경로 }`.
3. 매칭 스프라이트만 보이게 하고 나머지는 숨김.
4. 페이드 인 (0.8s) → 5초 대기 → 페이드 아웃 (0.6s) → 시작 레벨로 전환.
5. `_on_skip_pressed`로 스킵 가능 (즉시 전환).

```gdscript
const ROUTES := {
    &"bird":       { "sprite": "story1", "next": "res://Scenes/level_1.tscn" },
    &"researcher": { "sprite": "story2", "next": "res://Scenes/level_7.tscn" },
    &"planner":    { "sprite": "story3", "next": "res://Scenes/level_6.tscn" },
}
```

알 수 없는 id면 bird로 폴백 (`ROUTES.get(id, ROUTES[&"bird"])`).

---

## 2. 새 캐릭터의 스토리 추가

### Step 1 — `story1_scene.tscn`에 컷 스프라이트 추가
씬 트리에서 기존 `story1` / `story2` / `story3` Sprite2D 옆에 `story4` (예) 추가. 텍스처는 인트로 일러스트.

### Step 2 — `ROUTES`에 한 줄 추가
```gdscript
const ROUTES := {
    &"bird":       { "sprite": "story1", "next": "res://Scenes/level_1.tscn" },
    &"researcher": { "sprite": "story2", "next": "res://Scenes/level_7.tscn" },
    &"planner":    { "sprite": "story3", "next": "res://Scenes/level_6.tscn" },
    &"myhero":     { "sprite": "story4", "next": "res://Scenes/level_9.tscn" },  # ← 추가
}
```

### Step 3 — `_ready()`의 초기 숨김에도 추가
```gdscript
func _ready() -> void:
    ...
    story1.visible = false
    story2.visible = false
    story3.visible = false
    story4.visible = false  # ← 추가
    ...
```

또는 더 견고하게:
```gdscript
func _ready() -> void:
    var route : Dictionary = ROUTES.get(PlayerStats.selected_character_id, ROUTES[&"bird"])
    # 모든 스토리 스프라이트 일괄 숨김 (자식 노드명이 story*인 것들)
    for child in get_children():
        if child is Sprite2D and child.name.begins_with("story"):
            child.visible = false
    var active : Sprite2D = get_node(route["sprite"])
    active.visible = true
    ...
```

---

## 3. 인트로가 여러 컷일 때

스프라이트 1장 → 5초 후 전환 외에 여러 페이지를 보여주고 싶다면:

```gdscript
const ROUTES := {
    &"bird": {
        "pages": ["story1_a", "story1_b", "story1_c"],
        "next": "res://Scenes/level_1.tscn"
    },
    ...
}

func _ready() -> void:
    var route = ROUTES.get(PlayerStats.selected_character_id, ROUTES[&"bird"])
    seq = create_tween()
    for page_name in route["pages"]:
        var s : Sprite2D = get_node(page_name)
        s.visible = false
        s.modulate.a = 0.0
    for page_name in route["pages"]:
        var s : Sprite2D = get_node(page_name)
        seq.tween_callback(func(): s.visible = true)
        seq.tween_property(s, "modulate:a", 1.0, 0.6)
        seq.tween_interval(3.0)
        seq.tween_property(s, "modulate:a", 0.0, 0.4)
        seq.tween_callback(func(): s.visible = false)
    seq.tween_callback(_go_to_game)
```

---

## 4. 캐릭터별 다음 레벨 라우팅 (story scene 없이)

`character_select.gd._activate()`에서 직접 분기하고 싶다면:

```gdscript
func _activate(idx: int) -> void:
    ...
    PlayerStats.set_selected_character(data.id)
    var route_map = {
        &"bird":       "res://Scenes/level_1.tscn",
        &"researcher": "res://Scenes/level_7.tscn",
        &"planner":    "res://Scenes/level_6.tscn",
    }
    next_scene = route_map.get(data.id, next_scene)
    ...
```

하지만 현재 구조는 **story_scene을 거치는 게 표준**이고, 그 안에서 라우팅하는 게 깔끔. story_scene이 캐릭터별 분기의 단일 라우터 역할을 하므로 다른 곳에서 또 분기하면 일관성이 깨진다.

---

## 5. 스킵 버튼 동작

`story1_scene.tscn`에 Skip 버튼이 있고 `_on_skip_pressed`에 연결돼 있다. 누르면 진행 중인 tween을 `kill()`하고 즉시 `_go_to_game()` 호출. 새 인트로 추가 시 별도 처리 불필요 (기존 버튼이 그대로 작동).

---

## 6. 자주 하는 실수

- **`story4` 노드를 만들었는데 표시가 안 됨**: `ROUTES`에 추가했지만 `_ready()`의 visible=false 라인을 안 적어줘서 처음부터 보이고 있었던 것. 또는 visible=true가 다른 스프라이트와 동시에 떠 있어 겹친 경우. 위 Step 3 잊지 말 것.
- **스토리 끝나고 다른 캐릭터 레벨로 감**: `next` 경로 오타. 절대경로(`res://Scenes/level_X.tscn`) 사용.
- **씬 전환이 안 일어남**: `seq` Tween이 도중에 다른 코드에 의해 kill 됨, 또는 `_go_to_game` 시그니처에 인자가 추가됐는데 `tween_callback`은 인자 없는 Callable을 호출하므로 깨짐.
