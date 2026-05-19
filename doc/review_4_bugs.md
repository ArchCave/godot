# 코드 리뷰: 버그, 엣지 케이스 및 크래시 분석

> 리뷰 대상: player.gd, Player_ui.gd, poop_coin.gd, Enemy.gd, endflag.gd, player_stats.gd  
> 리뷰 일자: 2026-04-14  
> 심각도 기준: P0(크래시/데이터 손실) | P1(게임 진행 불가) | P2(기능 오작동) | P3(사소한 문제)

---

## 1. 잠재적 버그 목록 (심각도별 분류)

### P0 - 크래시 / 게임 중단

#### BUG-001: `endflag.gd` - `scene_to_load`가 null일 때 크래시

**파일:** `endflag.gd` 라인: `get_tree().change_scene_to_packed(scene_to_load)`

**설명:** `scene_to_load`는 `@export` 변수로 인스펙터에서 할당해야 한다. 할당하지 않으면 `null`이 전달되어 즉시 크래시가 발생한다.

**재현 시나리오:**
1. EndFlag 씬을 레벨에 배치한다
2. 인스펙터에서 `scene_to_load`를 비워 둔다
3. 플레이어가 깃발에 닿으면 애니메이션 재생 후 크래시

**수정 방안:**
```gdscript
func _on_animation_finished() -> void:
    if scene_to_load == null:
        push_error("scene_to_load가 설정되지 않았습니다!")
        # 물리 처리를 복원하여 플레이어가 멈추지 않도록 함
        for body in get_tree().get_nodes_in_group("Player"):
            body.set_physics_process(true)
        return
    get_tree().change_scene_to_packed(scene_to_load)
```

---

#### BUG-002: `endflag.gd` - 플레이어 영구 정지 (물리 처리 비활성화 후 미복구)

**파일:** `endflag.gd` 라인: `body.set_physics_process(false)`

**설명:** `_on_body_entered`에서 플레이어의 `set_physics_process(false)`를 호출한다. 그러나 애니메이션이 재생되지 않거나("end" 애니메이션이 존재하지 않을 경우), `_on_animation_finished` 시그널이 다른 애니메이션(예: 기본 애니메이션)에서도 발동될 수 있어 씬 전환이 실패하면 플레이어가 영구적으로 정지한다.

**재현 시나리오:**
1. AnimatedSprite2D에 "end" 애니메이션이 없는 경우
2. 플레이어가 깃발에 닿으면 `set_physics_process(false)` 실행
3. 애니메이션 에러로 `_on_animation_finished`가 호출되지 않음
4. 플레이어는 조작 불가 상태로 영구 정지

**수정 방안:**
```gdscript
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    body.set_physics_process(false)
    if anim_sprite.sprite_frames.has_animation("end"):
        anim_sprite.play("end")
    else:
        push_warning("'end' 애니메이션이 없습니다. 즉시 씬 전환합니다.")
        _on_animation_finished()
```

---

#### BUG-003: `Player_ui.gd` - `hearts` 배열에 Label 노드가 포함되어 인덱스 오류 발생

**파일:** `Player_ui.gd` 라인: `hearts = health_container.get_children()`

**설명:** `HealthContainer`의 자식을 전부 가져오는데, `HeartScoreText` Label도 자식이므로 `hearts` 배열에 포함된다. `_update_hearts`에서 `hearts[i].visible = i < health` 로직이 Label의 visibility도 제어하게 되어, 체력이 낮을 때 점수 텍스트가 사라진다. `EnergyContainer`의 `energy` 배열도 동일한 문제가 있다.

**재현 시나리오:**
1. 체력이 `hearts` 배열 내 Label의 인덱스보다 낮아질 때
2. `HeartScoreText` Label이 `visible = false`가 되어 화면에서 사라짐

**수정 방안:**
```gdscript
func _ready():
    # Label을 제외하고 하트 아이콘만 필터링
    for child in health_container.get_children():
        if child is TextureRect:  # 또는 하트 아이콘의 실제 타입
            hearts.append(child)
    for child in energy_container.get_children():
        if child is TextureRect:
            energy.append(child)
    # ... 이하 시그널 연결
```

---

### P1 - 게임 진행에 심각한 영향

#### BUG-004: `player.gd` - 체력이 음수로 내려가도 계속 피해를 받음

**파일:** `player.gd` `take_damage()` 함수

**설명:** `take_damage`에서 체력이 0 이하가 된 후에도 함수 호출을 막지 않는다. 적과 반복 충돌 시 `game_over()`가 여러 번 호출될 수 있고, 음수 체력이 UI에 표시된다.

**재현 시나리오:**
1. 체력 1인 상태에서 2개의 적과 동시에 충돌
2. `take_damage(1)`이 2번 호출됨
3. 체력이 -1이 되고, `game_over()`가 2번 `call_deferred`됨
4. 씬 전환이 중복 실행되어 예측 불가능한 동작 발생

**수정 방안:**
```gdscript
func take_damage(amount : int):
    if health <= 0:
        return  # 이미 사망 상태면 무시
    health -= amount
    health = max(health, 0)  # 음수 방지
    OnUpdateHealth.emit(health)
    if health <= 0:
        # 추가 피해 방지를 위해 충돌 비활성화
        set_physics_process(false)
        call_deferred("game_over")
```

---

#### BUG-005: `player_stats.gd` - 씬 전환 시 점수가 초기화되지 않음

**파일:** `player_stats.gd`

**설명:** `PlayerStats`는 오토로드(싱글톤)로 사용되므로 씬 전환 시에도 `score` 값이 유지된다. 게임 오버 후 재시작하면 이전 점수가 그대로 남아 있어 점프력이 비정상적으로 높은 채로 시작된다.

**재현 시나리오:**
1. 점수 240 이상 달성 (점프력 4배)
2. 게임 오버 발생
3. 재시작 후에도 점수 240 유지, 점프력 4배인 채로 시작

**수정 방안:**
```gdscript
# player_stats.gd
extends Node
var score : int = 0

func reset():
    score = 0

# player.gd 또는 레벨 시작 스크립트에서:
func _ready():
    PlayerStats.reset()
    # ...
```

---

#### BUG-006: `player.gd` - `game_over_scene` 경로 대소문자 불일치

**파일:** `player.gd` 라인: `@export var game_over_scene: String = "res://Scenes/level_1.tscn"`

**설명:** 기본값이 `res://Scenes/level_1.tscn`인데, 프로젝트 내 다른 곳에서는 `res://scenes/` (소문자)를 사용할 수 있다. Godot은 내보내기 시 대소문자를 구분하므로 Linux/Android 빌드에서 씬 파일을 찾지 못해 크래시가 발생할 수 있다. 또한 게임 오버 시 로드하는 씬이 `level_1`(레벨 자체)이므로 게임 오버 화면이 아니라 레벨이 재시작되는 것으로 보인다 - 의도된 것인지 확인 필요.

**재현 시나리오:**
1. Android 또는 Linux로 내보내기
2. 게임 오버 발생
3. 파일 경로 대소문자 불일치로 크래시

**수정 방안:**
```gdscript
# 경로를 PackedScene으로 변경하여 에디터에서 검증 가능하게 함
@export var game_over_scene: PackedScene
# 또는 경로 통일
@export var game_over_scene: String = "res://scenes/level_1.tscn"
```

---

### P2 - 기능 오작동

#### BUG-007: `Enemy.gd` - 적 충돌 시 무적 시간 없이 연속 피해

**파일:** `Enemy.gd` `_on_body_entered()`

**설명:** `Area2D`의 `body_entered`는 일반적으로 한 번만 발동되지만, 플레이어가 적과 겹친 상태에서 약간 벗어났다 다시 닿으면 반복 발동된다. 무적 시간(invincibility frame)이 없으므로 플레이어가 순식간에 체력을 모두 잃을 수 있다.

**재현 시나리오:**
1. 플레이어가 적 위에서 낙하하여 충돌
2. 넉백이 없으므로 적 영역 안에 머무름
3. 미세한 물리 이동으로 `body_entered`가 반복 발동
4. 체력이 순식간에 0이 됨

**수정 방안:**
```gdscript
# player.gd에 무적 시간 추가
var is_invincible := false

func take_damage(amount : int):
    if health <= 0 or is_invincible:
        return
    health -= amount
    health = max(health, 0)
    OnUpdateHealth.emit(health)
    is_invincible = true
    # 피격 시각 효과 (깜빡임)
    var tween = create_tween()
    tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
    tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
    tween.set_loops(3)
    await get_tree().create_timer(1.0).timeout
    is_invincible = false
    if health <= 0:
        call_deferred("game_over")
```

---

#### BUG-008: `poop_coin.gd` - 코인 전환 전 플레이어 충돌 시 무반응 (의도적일 수 있으나 혼란 유발)

**파일:** `poop_coin.gd`

**설명:** 타이머(20초) 만료 전에는 `collision.disabled = true`이므로 `body_entered` 시그널이 발동하지 않는다. 이것은 의도된 동작일 수 있으나, 플레이어가 똥 오브젝트 위를 걸어다녀도 아무 반응이 없어 혼란스러울 수 있다. 또한 `body_entered` 시그널이 씬에서 연결되어 있는지 확인이 필요하다 - 코드에서 `connect()`를 호출하지 않으므로 씬 파일의 시그널 연결에 의존한다.

---

#### BUG-009: `poop_coin.gd` - `body_entered` 시그널 연결 누락 가능성

**파일:** `poop_coin.gd`

**설명:** `timer.timeout` 시그널은 코드에서 `connect()`로 연결하지만, `body_entered` 시그널은 코드에서 연결하지 않는다. 씬 파일(`.tscn`)에서 연결되어 있어야 하는데, 만약 누락되면 코인을 수집할 수 없다.

**수정 방안:**
```gdscript
func _ready():
    # ... 기존 코드 ...
    body_entered.connect(_on_body_entered)  # 명시적 연결 추가
```

---

#### BUG-010: `player.gd` - `_spawn_poop()` 무제한 사용 가능

**파일:** `player.gd` `_spawn_poop()`

**설명:** 쿨다운이나 사용 횟수 제한이 없어 `ui_skill` 키를 연타하면 무한으로 똥을 생성할 수 있다. 20초 후 모두 코인으로 변환되면 점수가 폭발적으로 증가하여 점프력 밸런스가 무너진다.

**재현 시나리오:**
1. `ui_skill` 키를 빠르게 연타 (초당 10~30회)
2. 20초 후 대량의 코인이 동시 생성
3. 모든 코인을 수집하면 점수가 급등
4. 점프력이 4배가 되어 레벨 디자인 무력화

**수정 방안:**
```gdscript
var skill_cooldown := false

func _physics_process(delta):
    # ...
    if Input.is_action_just_pressed("ui_skill") and not skill_cooldown:
        _spawn_poop()
        skill_cooldown = true
        await get_tree().create_timer(3.0).timeout  # 3초 쿨다운
        skill_cooldown = false
```

---

### P3 - 사소한 문제

#### BUG-011: `player.gd` - `move_speed`가 비정상적으로 낮음

**파일:** `player.gd` 라인: `@export var move_speed : float = 25`

**설명:** `move_speed = 25`는 Godot 2D 게임에서 매우 느린 값이다. 일반적으로 100~300 정도가 사용된다. `@export`이므로 인스펙터에서 변경 가능하나, 기본값으로 테스트하면 캐릭터가 거의 움직이지 않는 것처럼 느껴질 수 있다.

---

#### BUG-012: `Player_ui.gd` - 빈 `_process()` 함수

**파일:** `Player_ui.gd`

**설명:** 빈 `_process()` 함수가 매 프레임 호출된다. 성능에 큰 영향은 없으나 불필요한 오버헤드이다.

**수정 방안:** 삭제하거나 `set_process(false)` 호출.

---

## 2. 엣지 케이스 분석

### 2-1. 음수 체력

| 상황 | 현재 동작 | 예상 문제 |
|------|----------|----------|
| `take_damage(10)` 호출 (체력 5) | 체력 = -5, UI에 음수 표시 | `_update_hearts`에서 모든 하트 숨김 (정상), 하지만 `heart_score_text`에 "-5" 표시 |
| 체력 0 이하에서 추가 피해 | `game_over()` 중복 호출 | 씬 전환 충돌 가능 |

### 2-2. 무한 스킬 사용

| 상황 | 현재 동작 | 예상 문제 |
|------|----------|----------|
| 스킬 100회 연속 사용 | 100개의 poop_coin 노드 생성 | 20초 후 100개 타이머 동시 만료, 100개 코인 동시 활성화 |
| 코인 위에서 스킬 사용 | 같은 위치에 오브젝트 겹침 | 수집 시 한 번에 여러 개 수집 가능 |

### 2-3. 동시 충돌

| 상황 | 현재 동작 | 예상 문제 |
|------|----------|----------|
| 적 + 엔드플래그 동시 충돌 | 체력 감소 + 물리 비활성화 | 게임 오버와 씬 전환이 경쟁 |
| 적 2개 동시 충돌 | `take_damage` 2번 호출 | 체력 2 감소 (의도 여부 확인 필요) |
| 코인 수집 중 게임 오버 | `increase_score` + `game_over` | PlayerStats.score 업데이트 후 씬 전환, 점수 유지 |

---

## 3. Null 참조 / 크래시 가능성

### CRASH-001: `@onready` 노드 누락 시 즉시 크래시

**영향 범위:** 모든 스크립트

**설명:** 모든 `@onready` 변수는 씬 트리에 해당 노드가 존재한다고 가정한다. 씬 구조 변경 시 null 참조 크래시가 발생한다.

| 스크립트 | 변수 | 의존 노드 |
|---------|------|----------|
| `player.gd` | `ray` | `$RayCast2D` |
| `player.gd` | `anim` | `$AnimationPlayer` |
| `player.gd` | `sprite` | `$Sprite2D` |
| `poop_coin.gd` | `sprite` | `$Sprite2D` |
| `poop_coin.gd` | `anim_sprite` | `$AnimatedSprite2D` |
| `poop_coin.gd` | `collision` | `$CollisionShape2D` |
| `poop_coin.gd` | `timer` | `$Timer` |

**수정 방안 (중요한 노드에 대해):**
```gdscript
func _ready():
    if not ray:
        push_error("RayCast2D 노드를 찾을 수 없습니다!")
        return
```

---

### CRASH-002: `Player_ui.gd` - `get_parent()`가 Player가 아닐 때

**파일:** `Player_ui.gd` 라인: `@onready var Player = get_parent()`

**설명:** UI 노드의 부모가 반드시 Player라고 가정한다. UI를 다른 곳에 배치하면 `Player.OnUpdateHealth.connect()`에서 크래시가 발생한다. `CanvasLayer`의 특성상 씬 구조 변경 시 이런 문제가 발생하기 쉽다.

**수정 방안:**
```gdscript
@onready var Player = get_parent()

func _ready():
    if not Player.has_signal("OnUpdateHealth"):
        push_error("부모 노드가 Player가 아닙니다!")
        return
    # ... 시그널 연결
```

---

### CRASH-003: `_spawn_poop()` - `get_parent()`가 null일 때

**파일:** `player.gd`

**설명:** `get_parent().add_child(poop)`에서 플레이어가 씬 트리에서 분리된 상태이면 크래시가 발생한다. `queue_free()` 직후 등의 타이밍에 가능하다.

---

## 4. 씬 전환 시 문제점

### SCENE-001: 게임 오버와 엔드플래그 씬 전환 경쟁

**설명:** 플레이어가 엔드플래그 근처에서 동시에 사망하면:

1. `endflag.gd`: `body.set_physics_process(false)` 실행
2. `Enemy.gd`: `body.take_damage(1)` 실행 -> `game_over()` 호출
3. `endflag.gd`: 애니메이션 완료 후 `change_scene_to_packed()` 호출

두 개의 `change_scene` 호출이 같은 프레임 또는 연속 프레임에서 발생하여 예측 불가능한 동작이 발생한다.

**수정 방안:**
```gdscript
# player.gd에 상태 플래그 추가
var is_transitioning := false

func game_over():
    if is_transitioning:
        return
    is_transitioning = true
    get_tree().change_scene_to_file(game_over_scene)

# endflag.gd에서도 확인
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("Player"):
        return
    if body.is_transitioning:
        return
    body.is_transitioning = true
    body.set_physics_process(false)
    anim_sprite.play("end")
```

---

### SCENE-002: `call_deferred("game_over")` 타이밍

**설명:** `call_deferred`는 현재 프레임의 물리 처리가 끝난 후 호출된다. 그 사이에 다른 적과의 충돌이 처리될 수 있어 `game_over`가 중복 예약될 수 있다.

---

### SCENE-003: 씬 전환 후 시그널 연결 잔존

**설명:** `Player.OnUpdateHealth`에 연결된 UI 콜백이 씬 전환 시 자동 정리되지만, `PlayerStats`(오토로드)에 연결된 참조가 있다면 메모리 누수 가능성이 있다.

---

## 5. 메모리 누수 가능성

### LEAK-001: `poop_coin` - 코인 상태에서 수집되지 않으면 영구 잔존

**파일:** `poop_coin.gd`

**설명:** 타이머(20초)로 코인으로 변환된 후, 플레이어가 수집하지 않으면 `queue_free()`가 호출되지 않아 노드가 영구적으로 존재한다. 무한 스킬 사용과 결합하면 노드 수가 지속적으로 증가한다.

**재현 시나리오:**
1. 스킬을 반복 사용하여 100개의 poop_coin 생성
2. 20초 후 모두 코인으로 변환
3. 플레이어가 수집하지 않고 이동
4. 노드가 씬 트리에 계속 남아 메모리 점유

**수정 방안:**
```gdscript
func _on_timer_timeout() -> void:
    is_coin = true
    sprite.visible      = false
    anim_sprite.visible = true
    anim_sprite.play("spin")
    collision.disabled  = false
    # 코인 상태에서 추가 타이머로 자동 삭제
    var expire_timer = get_tree().create_timer(30.0)
    expire_timer.timeout.connect(queue_free)
```

---

### LEAK-002: `poop_coin` - 타이머 만료 전 씬 전환

**설명:** 씬 전환 시 모든 노드가 `queue_free`되므로 큰 문제는 아니지만, `poop_coin`이 `get_parent()`(Player의 부모)에 추가되므로 씬 트리 구조에 따라 정리가 제대로 되지 않을 가능성이 있다.

---

## 6. 경쟁 조건 (Race Condition)

### RACE-001: `take_damage` + `game_over` + `_physics_process`

```
프레임 N:
  - Enemy A: body_entered -> take_damage(1) -> health = 0 -> call_deferred("game_over")
  - Enemy B: body_entered -> take_damage(1) -> health = -1 -> call_deferred("game_over")

프레임 N (deferred):
  - game_over() 첫 번째 호출 -> change_scene_to_file()
  - game_over() 두 번째 호출 -> change_scene_to_file() (이미 전환 중인 씬에 대해)
```

**위험:** Godot은 중복 `change_scene` 호출을 경고 없이 처리하지만, 전환 중 노드 접근 시 크래시 가능성이 있다.

---

### RACE-002: `endflag` 애니메이션 중 `body_entered` 재발동

**설명:** `_on_body_entered`에 재진입 방지가 없으므로, 플레이어가 엔드플래그 영역 안에서 미세하게 움직이면 `set_physics_process(false)`가 이미 비활성화된 상태에서 다시 호출되고 `anim_sprite.play("end")`가 재시작될 수 있다.

**수정 방안:**
```gdscript
var is_triggered := false

func _on_body_entered(body: Node2D) -> void:
    if is_triggered:
        return
    if not body.is_in_group("Player"):
        return
    is_triggered = true
    body.set_physics_process(false)
    anim_sprite.play("end")
```

---

### RACE-003: `_update_jump_force`와 점프 타이밍

**설명:** 코인 수집 -> `increase_score` -> `_update_jump_force`가 호출되는 도중, 같은 프레임에서 점프 입력이 처리되면 업데이트 전의 `jump_force` 또는 업데이트 후의 `jump_force`가 적용될 수 있다. `_physics_process`에서 점프와 코인 수집이 동일 프레임에 처리될 때 발생한다.

---

## 7. 종합 재현 시나리오 및 수정 방안

### 시나리오 A: "즉사 콤보"

**재현 단계:**
1. 플레이어 체력 1 상태
2. 2개의 Enemy가 인접하여 배치된 위치로 이동
3. 두 적의 Area2D에 동시 진입
4. `take_damage(1)` 2회 호출 -> 체력 -1
5. `game_over()` 2회 deferred 호출
6. 첫 번째 `game_over()`에서 씬 전환 시작
7. 두 번째 `game_over()` 호출 시 이미 노드가 해제된 상태 -> 잠재적 크래시

**종합 수정 (player.gd):**
```gdscript
var is_invincible := false
var is_dead := false

func take_damage(amount : int):
    if is_dead or is_invincible:
        return
    health -= amount
    health = max(health, 0)
    OnUpdateHealth.emit(health)
    if health <= 0:
        is_dead = true
        set_physics_process(false)
        call_deferred("game_over")
    else:
        is_invincible = true
        # 무적 시간 1초
        var tween = create_tween()
        for i in range(5):
            tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
            tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
        tween.tween_callback(func(): is_invincible = false)
```

---

### 시나리오 B: "점프력 익스플로잇"

**재현 단계:**
1. 게임 시작 후 한 자리에서 `ui_skill` 키를 60회 연타
2. 20초 대기 (모든 똥이 코인으로 변환)
3. 좌우로 이동하며 60개 코인 전부 수집
4. 점수 60 달성 -> 점프력 1.5배
5. 반복하면 점프력 4배까지 도달
6. 레벨 디자인상 도달 불가능한 영역 접근 가능

**수정 방안:** 스킬 쿨다운 + 동시 존재 제한
```gdscript
var active_poops := 0
const MAX_ACTIVE_POOPS := 5

func _spawn_poop() -> void:
    if active_poops >= MAX_ACTIVE_POOPS:
        return
    var poop = PoopCoin.instantiate()
    active_poops += 1
    poop.tree_exited.connect(func(): active_poops -= 1)
    # ... 나머지 동일
```

---

### 시나리오 C: "엔드플래그 + 게임오버 교착"

**재현 단계:**
1. 엔드플래그 바로 옆에 적 배치
2. 체력 1인 플레이어가 엔드플래그와 적에 동시 접촉
3. `endflag`: `set_physics_process(false)` + "end" 애니메이션 시작
4. `Enemy`: `take_damage(1)` -> 체력 0 -> `call_deferred("game_over")`
5. `game_over()`가 먼저 실행되면 씬 전환 -> 엔드플래그 애니메이션 중단
6. 엔드플래그가 먼저 실행되면 다른 레벨로 전환, 하지만 체력은 0

**수정 방안:** 전역 씬 전환 락(lock) 도입
```gdscript
# player.gd
var is_transitioning := false

func game_over():
    if is_transitioning:
        return
    is_transitioning = true
    get_tree().change_scene_to_file(game_over_scene)
```

---

## 부록: 우선순위별 수정 체크리스트

| 우선순위 | 버그 ID | 설명 | 예상 작업량 |
|---------|---------|------|-----------|
| **P0** | BUG-001 | endflag scene_to_load null 체크 | 5분 |
| **P0** | BUG-002 | endflag 플레이어 영구 정지 | 10분 |
| **P0** | BUG-003 | UI 배열에 Label 포함 | 15분 |
| **P1** | BUG-004 | 음수 체력 + game_over 중복 | 15분 |
| **P1** | BUG-005 | PlayerStats 점수 미초기화 | 5분 |
| **P1** | BUG-006 | 씬 경로 대소문자 | 5분 |
| **P2** | BUG-007 | 무적 시간 없음 | 20분 |
| **P2** | BUG-008 | 코인 전환 전 상호작용 없음 | 5분 |
| **P2** | BUG-009 | body_entered 시그널 연결 확인 | 5분 |
| **P2** | BUG-010 | 무제한 스킬 사용 | 10분 |
| **P3** | BUG-011 | move_speed 기본값 | 1분 |
| **P3** | BUG-012 | 빈 _process 함수 | 1분 |
| **P1** | RACE-001 | take_damage 경쟁 조건 | BUG-004와 동시 수정 |
| **P2** | RACE-002 | endflag 재진입 | 5분 |
| **P2** | LEAK-001 | 코인 미수집 시 영구 잔존 | 5분 |
