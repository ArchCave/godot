# 코드 리뷰: 아키텍처 및 구조 분석

**프로젝트:** 0303-renewal (Godot 4 2D 플랫포머)
**리뷰어:** Senior Game Architect
**리뷰 일자:** 2026-04-14
**대상 파일:** `player.gd`, `player_stats.gd`, `Enemy.gd`, `Player_ui.gd`, `poop_coin.gd`, `endflag.gd`

---

## 1. 전체 아키텍처 평가

**등급: D+**

### 1.1 노드 구조

현재 추정되는 씬 트리 구조는 다음과 같다:

```
Level (Node2D)
├── Player (CharacterBody2D)          ← player.gd
│   ├── Sprite2D
│   ├── AnimationPlayer
│   ├── RayCast2D
│   └── Player_UI (CanvasLayer)       ← Player_ui.gd
├── Enemy (Area2D)                    ← Enemy.gd
├── PoopCoin (Area2D)                 ← poop_coin.gd (동적 인스턴스)
├── EndFlag (Area2D)                  ← endflag.gd
└── PlayerStats (AutoLoad/Singleton)  ← player_stats.gd
```

**문제점:**
- `Player_UI`가 Player의 자식 노드로 추정된다 (`get_parent()`로 Player 참조). UI는 게임 로직 노드의 자식이 되어서는 안 된다. Player가 제거되면 UI도 함께 사라진다.
- `PoopCoin`을 `get_parent().add_child()`로 생성하여 부모 노드에 의존한다. Player의 부모가 변경되면 코인 배치가 깨진다.
- 씬 전환 경로가 하드코딩 되어있다 (`"res://Scenes/level_1.tscn"`).

### 1.2 씬 구성

- 전용 GameManager나 LevelManager가 존재하지 않는다.
- 씬 전환 로직이 `player.gd`와 `endflag.gd`에 분산되어 있다.
- 게임 상태(진행, 일시정지, 게임오버)를 관리하는 상태 머신이 없다.

### 1.3 의존성 맵

```
player.gd ──────► PlayerStats (싱글톤 직접 참조)
    │             PoopCoin (preload 직접 참조)
    │
Player_ui.gd ──► player.gd (get_parent()로 강결합)
    │             PlayerStats (싱글톤 직접 참조)
    │
Enemy.gd ──────► player.gd (body.take_damage 직접 호출)
    │
poop_coin.gd ──► player.gd (body.increase_score 직접 호출)
    │
endflag.gd ────► (body.set_physics_process 직접 호출)
```

거의 모든 스크립트가 Player의 구체적인 메서드에 직접 의존하고 있어, Player 인터페이스 변경 시 연쇄 수정이 필요하다.

---

## 2. 단일 책임 원칙(SRP) 준수 여부

**등급: D**

### player.gd -- 책임이 과도하게 집중됨

`player.gd`는 현재 다음의 책임을 모두 갖고 있다:

| 책임 | 해당 메서드 |
|------|------------|
| 이동 처리 | `_physics_process()` |
| 점프 처리 | `_physics_process()` |
| 입력 처리 | `_physics_process()` |
| 애니메이션 제어 | `update_animation()`, `play_anim()` |
| 전투/피해 처리 | `take_damage()` |
| 스킬 시스템 (똥 생성) | `_spawn_poop()` |
| 점수 시스템 | `increase_score()` |
| 점프력 성장 시스템 | `_update_jump_force()` |
| 게임 오버 씬 전환 | `game_over()` |

**하나의 스크립트가 최소 7가지 이상의 책임을 지고 있다.** 기능이 추가될수록 이 파일은 급격하게 비대해질 것이다.

### player_stats.gd -- 책임이 지나치게 부족함

반대로 `player_stats.gd`는 `score` 변수 하나만 들고 있으며, `_ready()`와 `_process()`는 비어있다. 싱글톤으로서의 역할을 제대로 수행하지 못하고 있다. 점수 관련 로직(`increase_score`, `_update_jump_force`)이 `player.gd`에 있어야 할 이유가 없다.

### Player_ui.gd -- 경계가 모호함

UI 스크립트가 Player 노드의 내부 시그널과 `PlayerStats` 싱글톤 양쪽 모두에 의존하고 있다. 데이터 소스가 이원화되어 있다.

---

## 3. 커플링/디커플링 분석

**등급: D**

### 3.1 강결합(Tight Coupling) 사례

#### (1) Player_ui.gd의 부모 노드 강결합

```gdscript
# Player_ui.gd
@onready var Player = get_parent()  # Player가 반드시 부모여야 함
```

이 패턴은 UI 씬을 독립적으로 테스트하거나 재배치하는 것을 불가능하게 만든다. Player 노드가 부모가 아닌 상황이 발생하면 런타임 에러가 터진다.

#### (2) Enemy/PoopCoin의 duck typing 의존

```gdscript
# Enemy.gd
body.take_damage(1)   # body에 take_damage가 있다고 가정

# poop_coin.gd
body.increase_score(1) # body에 increase_score가 있다고 가정
```

그룹 체크(`is_in_group("Player")`)를 하지만 실제 메서드 존재 여부는 검증하지 않는다. 다른 "Player" 그룹 노드가 해당 메서드를 갖고 있지 않으면 크래시가 발생한다.

#### (3) 씬 경로 하드코딩

```gdscript
# player.gd
@export var game_over_scene: String = "res://Scenes/level_1.tscn"
```

게임 오버 씬이 `level_1`인 것도 의문이지만, 씬 전환 자체를 Player가 관리하는 것이 근본적 문제다.

### 3.2 시그널 활용 평가

시그널은 선언되어 있으나 (`OnUpdateHealth`, `OnUpdateScore`) 활용 범위가 제한적이다. 적이 플레이어에게 데미지를 줄 때 시그널이 아닌 직접 메서드 호출을 사용하고 있다.

---

## 4. 확장성 평가

**등급: D-**

### 4.1 새로운 적 유형 추가 시

현재 `Enemy.gd`는 고정 데미지(`1`)를 하드코딩하고 있다. 새로운 적 유형이 추가되면:
- 데미지 값을 변경할 수 없다 (export 없음).
- 이동 패턴, 체력 등의 속성이 없다.
- 기본 Enemy 클래스를 상속할 구조가 마련되어 있지 않다.

### 4.2 새로운 스킬 추가 시

스킬이 `_physics_process` 안에 인라인으로 들어있다:

```gdscript
if Input.is_action_just_pressed("ui_skill"):
    _spawn_poop()
```

스킬이 2개, 3개로 늘어나면 `_physics_process`가 거대해지고 스킬 간 전환 로직이 복잡해진다.

### 4.3 점프력 성장 시스템

```gdscript
func _update_jump_force():
    if PlayerStats.score >= 240:
        multiplier = 4.0
    elif PlayerStats.score >= 180:
        multiplier = 3.0
    ...
```

매직 넘버가 하드코딩되어 있다. 레벨 디자이너가 밸런싱을 조정하려면 코드를 직접 수정해야 한다. 스테이지가 늘어날수록 이 if-elif 체인도 계속 늘어난다.

### 4.4 멀티플레이어/NPC 확장

Player에 점수, 체력, 물리, 입력, 애니메이션이 전부 묶여있어 NPC나 2P 캐릭터로의 확장이 사실상 불가능하다.

---

## 5. 개선 제안

### 5.1 GameManager 싱글톤 도입 (우선순위: 높음)

씬 전환과 게임 상태를 중앙에서 관리하는 매니저를 도입한다.

```gdscript
# game_manager.gd (AutoLoad 등록)
extends Node

signal game_over_triggered
signal scene_change_requested(scene_path: String)

enum GameState { PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.PLAYING

func trigger_game_over() -> void:
    current_state = GameState.GAME_OVER
    game_over_triggered.emit()
    await get_tree().create_timer(1.0).timeout
    get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

func change_scene(scene: PackedScene) -> void:
    get_tree().change_scene_to_packed(scene)
```

이렇게 하면 `player.gd`의 `game_over()`와 `endflag.gd`의 씬 전환 로직을 제거하고, 각 스크립트에서는 `GameManager.trigger_game_over()`만 호출하면 된다.

### 5.2 Player 책임 분리 (우선순위: 높음)

Player의 책임을 자식 노드 컴포넌트로 분리한다.

```
Player (CharacterBody2D)         ← player.gd (이동/물리만)
├── PlayerAnimator (Node)        ← player_animator.gd
├── PlayerCombat (Node)          ← player_combat.gd
├── PlayerSkills (Node)          ← player_skills.gd
├── Sprite2D
├── AnimationPlayer
└── RayCast2D
```

**player.gd (이동만 담당):**
```gdscript
extends CharacterBody2D

signal jumped
signal landed
signal direction_changed(direction: float)

@export var move_speed: float = 25.0
@export var gravity: float = 420.0
@export var jump_force: float = 100.0
var base_jump_force: float

func _ready() -> void:
    base_jump_force = jump_force

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    var move_input := Input.get_axis("ui_left", "ui_right")
    if move_input != 0:
        direction_changed.emit(move_input)

    if Input.is_action_just_pressed("ui_jump") and is_on_floor():
        velocity.y = -jump_force
        jumped.emit()

    velocity.x = move_input * move_speed
    move_and_slide()
```

**player_combat.gd (전투 담당):**
```gdscript
extends Node

signal health_changed(new_health: int)
signal died

@export var max_health: int = 5
var health: int

func _ready() -> void:
    health = max_health

func take_damage(amount: int) -> void:
    health -= amount
    health_changed.emit(health)
    if health <= 0:
        died.emit()
```

### 5.3 Player_ui.gd 디커플링 (우선순위: 높음)

UI를 Player의 자식에서 분리하고, 시그널 기반으로 연결한다.

```gdscript
# Player_ui.gd -- 개선안
extends CanvasLayer

@onready var health_container = $HealthContainer
@onready var energy_container = $EnergyContainer
@onready var heart_score_text: Label = $HealthContainer/HeartScoreText
@onready var energy_score_text: Label = $EnergyContainer/EnergyScoreText

var hearts: Array = []
var energy: Array = []

func _ready() -> void:
    hearts = health_container.get_children()
    energy = energy_container.get_children()
    # 싱글톤 시그널을 통해 연결 -- Player 노드에 대한 의존 제거
    PlayerStats.health_changed.connect(_update_hearts)
    PlayerStats.score_changed.connect(_update_energy)

func _update_hearts(health: int) -> void:
    for i in len(hearts):
        if hearts[i] is TextureRect:
            hearts[i].visible = i < health
    heart_score_text.text = str(health)

func _update_energy(score: int) -> void:
    for i in len(energy):
        if energy[i] is TextureRect:
            energy[i].visible = i < score
    energy_score_text.text = str(score)
```

### 5.4 PlayerStats 강화 (우선순위: 중간)

데이터와 관련 로직을 `PlayerStats`로 통합한다.

```gdscript
# player_stats.gd -- 개선안
extends Node

signal health_changed(new_health: int)
signal score_changed(new_score: int)

var score: int = 0
var health: int = 5

# 점프력 성장 테이블 -- 데이터 드리븐 방식
const JUMP_MULTIPLIER_TABLE: Array[Dictionary] = [
    {"threshold": 240, "multiplier": 4.0},
    {"threshold": 180, "multiplier": 3.0},
    {"threshold": 120, "multiplier": 2.0},
    {"threshold": 60,  "multiplier": 1.5},
]

func add_score(amount: int) -> void:
    score += amount
    score_changed.emit(score)

func get_jump_multiplier() -> float:
    for entry in JUMP_MULTIPLIER_TABLE:
        if score >= entry.threshold:
            return entry.multiplier
    return 1.0

func reset() -> void:
    score = 0
    health = 5
```

이렇게 하면 `player.gd`의 `increase_score()`와 `_update_jump_force()`를 제거하고, 밸런싱 데이터를 한 곳에서 관리할 수 있다.

### 5.5 안전한 duck typing 적용 (우선순위: 중간)

```gdscript
# Enemy.gd -- 개선안
extends Area2D

@export var damage: int = 1

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("take_damage"):
        body.take_damage(damage)
```

`is_in_group` 체크 대신 `has_method`를 사용하면 "Player" 그룹에 속하지 않더라도 `take_damage`를 가진 모든 노드(예: 파괴 가능 오브젝트)에 데미지를 줄 수 있어 확장성이 높아진다. 필요 시 그룹 체크를 추가로 병행할 수 있다.

### 5.6 네이밍 컨벤션 통일 (우선순위: 낮음)

현재 파일명과 시그널명에 일관성이 없다:

| 현재 | GDScript 컨벤션 |
|------|----------------|
| `Enemy.gd` (PascalCase) | `enemy.gd` (snake_case) |
| `Player_ui.gd` (혼합) | `player_ui.gd` (snake_case) |
| `OnUpdateHealth` (PascalCase 시그널) | `health_updated` (snake_case 과거형) |
| `OnUpdateScore` (PascalCase 시그널) | `score_updated` (snake_case 과거형) |

GDScript의 공식 스타일 가이드에 따르면:
- 파일명: `snake_case.gd`
- 시그널명: `snake_case` (과거형 권장, 예: `health_changed`)
- 변수명: `snake_case`
- 클래스명: `PascalCase`

---

## 종합 평가

| 항목 | 등급 | 비고 |
|------|------|------|
| 전체 아키텍처 | **D+** | 매니저 부재, 씬 구조 미흡 |
| 단일 책임 원칙 | **D** | player.gd에 7개 이상의 책임 집중 |
| 커플링/디커플링 | **D** | get_parent() 강결합, 시그널 활용 부족 |
| 확장성 | **D-** | 새 기능 추가 시 기존 코드 대폭 수정 필요 |
| 코드 컨벤션 | **C** | 네이밍 비일관, 매직 넘버 산재 |
| **종합** | **D+** | 프로토타입 수준. 기능 확장 전 리팩토링 필수 |

### 우선 실행 항목 (Top 3)

1. **GameManager 싱글톤 도입** -- 씬 전환과 게임 상태를 중앙 관리한다.
2. **Player 책임 분리** -- 이동, 전투, 스킬, 애니메이션을 별도 컴포넌트로 분리한다.
3. **Player_UI를 Player 자식에서 분리** -- 시그널 또는 싱글톤 기반으로 느슨한 결합을 구현한다.

이 세 가지만 완료해도 코드베이스의 유지보수성과 확장성이 크게 개선될 것이다.
