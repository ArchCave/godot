# 코드 품질 리뷰 - GDScript 코드베이스

**프로젝트:** 0303-renewal  
**리뷰 일자:** 2026-04-14  
**리뷰 대상 파일:**  
`player.gd`, `player_stats.gd`, `Player_ui.gd`, `poop_coin.gd`, `Enemy.gd`, `endflag.gd`, `floor.gd`, `Dialogue_area_2d.gd`, `Intro_Guide.gd`, `bird_intro_talk.gd`, `camera_level1.gd`

---

## 1. 파일명 네이밍 컨벤션 일관성

**심각도: Major**

GDScript 공식 스타일 가이드에서는 파일명에 `snake_case`를 권장합니다. 현재 프로젝트의 파일명이 일관되지 않습니다.

| 현재 파일명 | 문제점 | 권장 파일명 |
|---|---|---|
| `Player_ui.gd` | PascalCase + snake_case 혼합 | `player_ui.gd` |
| `Enemy.gd` | PascalCase | `enemy.gd` |
| `Dialogue_area_2d.gd` | PascalCase 시작 + snake_case 혼합 | `dialogue_area_2d.gd` |
| `Intro_Guide.gd` | PascalCase 시작 + 대문자 혼합 | `intro_guide.gd` |
| `player.gd` | 올바름 | - |
| `player_stats.gd` | 올바름 | - |
| `poop_coin.gd` | 올바름 | - |
| `endflag.gd` | 올바름 (단, `end_flag.gd`가 더 가독성 좋음) | `end_flag.gd` |
| `floor.gd` | 올바름 | - |

**권장 조치:** 모든 스크립트 파일명을 `snake_case`로 통일할 것.

---

## 2. 시그널 네이밍 컨벤션

**심각도: Critical**

GDScript 4 공식 스타일 가이드에서 시그널은 **snake_case** (과거형)로 작성하도록 권장합니다. 현재 `player.gd`의 시그널이 이 규칙을 위반합니다.

```gdscript
# 현재 (잘못된 네이밍)
signal OnUpdateHealth (health:int)
signal OnUpdateScore (score:int)

# 권장 (GDScript 컨벤션 준수)
signal health_updated(health: int)
signal score_updated(score: int)
```

**문제 상세:**
- `OnUpdateHealth` - C# 스타일의 PascalCase 이벤트 네이밍 사용. GDScript에서는 부적절함.
- `On` 접두사 - GDScript에서는 시그널에 `On` 접두사를 사용하지 않음. 이는 콜백 함수에 해당하는 네이밍임.
- 시그널명은 "어떤 일이 발생했는가"를 과거형으로 표현해야 함 (예: `health_changed`, `score_updated`).

**영향 범위:** `player.gd`, `Player_ui.gd` (시그널 연결부)

---

## 3. 타입 힌트 사용 일관성

**심각도: Major**

타입 힌트 사용이 파일 간, 심지어 같은 파일 내에서도 일관성이 없습니다.

### 3-1. 반환 타입 힌트 누락

| 파일 | 함수 | 현재 | 권장 |
|---|---|---|---|
| `player.gd` | `_ready()` | 반환 타입 없음 | `func _ready() -> void:` |
| `player.gd` | `_physics_process(delta)` | 매개변수+반환 타입 없음 | `func _physics_process(delta: float) -> void:` |
| `player.gd` | `update_animation()` | 반환 타입 없음 | `func update_animation() -> void:` |
| `player.gd` | `play_anim(...)` | 반환 타입 없음 | `func play_anim(...) -> void:` |
| `player.gd` | `take_damage(...)` | 반환 타입 없음 | `func take_damage(...) -> void:` |
| `player.gd` | `game_over()` | 반환 타입 없음 | `func game_over() -> void:` |
| `player.gd` | `increase_score(...)` | 반환 타입 없음 | `func increase_score(...) -> void:` |
| `Player_ui.gd` | `_ready()` | 반환 타입 없음 | `func _ready() -> void:` |
| `endflag.gd` | `_ready()` | 반환 타입 없음 | `func _ready() -> void:` |
| `poop_coin.gd` | `_ready()` | 반환 타입 없음 | `func _ready() -> void:` |

**참고:** `Enemy.gd`의 `_ready() -> void`와 `_on_body_entered(body: Node2D) -> void`는 올바르게 작성됨.

### 3-2. 변수 타입 힌트 누락

```gdscript
# Player_ui.gd - 타입 힌트 누락
@onready var health_container = $HealthContainer        # 타입 미지정
@onready var energy_container = $EnergyContainer        # 타입 미지정
@onready var Player = get_parent()                      # 타입 미지정

# endflag.gd - 부분 누락
@onready var anim_sprite = $AnimatedSprite2D            # 타입 미지정
@onready var collision   = $CollisionShape2D            # 타입 미지정

# poop_coin.gd - 전부 누락
@onready var sprite      = $Sprite2D                    # 타입 미지정
@onready var anim_sprite = $AnimatedSprite2D            # 타입 미지정
@onready var collision   = $CollisionShape2D            # 타입 미지정
@onready var timer       = $Timer                       # 타입 미지정
```

**권장:** `@onready` 변수에 명시적 타입을 지정하면 에디터 자동완성과 정적 분석에 도움이 됨.

```gdscript
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
```

### 3-3. 지역 변수 타입 힌트

```gdscript
# player.gd
var poop = PoopCoin.instantiate()    # -> var poop: Area2D = PoopCoin.instantiate()
var ground_y = ray.get_collision_point().y  # -> var ground_y: float = ...
```

---

## 4. 불필요한 코드 (데드 코드)

**심각도: Minor**

### 4-1. 빈 `_process()` 함수

아래 파일들에 기능이 없는 빈 `_process()` 함수가 남아 있습니다. 빈 `_process()`는 매 프레임마다 호출되므로 미미하지만 불필요한 성능 비용이 발생합니다.

| 파일 | 라인 |
|---|---|
| `player_stats.gd` | 9-10행 |
| `Player_ui.gd` | 37-38행 |
| `Enemy.gd` | 9-10행 |
| `floor.gd` | 10-11행 |
| `Intro_Guide.gd` | 12-13행 |

**권장:** 사용하지 않는 `_process()` 및 `_ready()` 함수는 삭제할 것.

### 4-2. 빈 `_ready()` 함수

| 파일 | 라인 |
|---|---|
| `player_stats.gd` | 5-6행 (`pass` 주석 포함) |
| `floor.gd` | 5-6행 (`pass` 주석 포함) |

### 4-3. Godot 템플릿 주석 잔존

```gdscript
# Called when the node enters the scene tree for the first time.
# Called every frame. 'delta' is the elapsed time since the previous frame.
# Replace with function body.
```

위 주석들은 Godot 에디터가 자동 생성한 템플릿 주석으로, 실제 의미가 없으므로 삭제해야 합니다.

**해당 파일:** `player_stats.gd`, `Enemy.gd`, `floor.gd`, `Intro_Guide.gd`, `Player_ui.gd`

### 4-4. 미사용 변수

```gdscript
# poop_coin.gd
var is_coin := false    # 값을 설정하지만 어디에서도 읽지 않음
```

---

## 5. 디버그용 print 문 잔존

**심각도: Major**

프로덕션 코드에 `print()` 디버그 문이 여러 곳에 남아 있습니다. 릴리즈 빌드에서 로그가 노출되며, 성능에도 영향을 줄 수 있습니다.

| 파일 | 라인 | 코드 |
|---|---|---|
| `player.gd` | 44행 | `print("Attack")` |
| `player.gd` | 47행 | `print("Skill")` |
| `player.gd` | 84행 | `print("Player.gd : ", PlayerStats.score)` |
| `Dialogue_area_2d.gd` | 12행 | `print("Player entered the area")` |

**권장 조치:**
1. 모든 디버그 `print()` 문을 제거하거나,
2. 조건부 로깅 유틸리티를 만들어 사용할 것:

```gdscript
# 예시: debug_logger.gd (Autoload)
const DEBUG_MODE := OS.is_debug_build()

static func log(message: String) -> void:
    if DEBUG_MODE:
        print(message)
```

---

## 6. 매직 넘버 사용

**심각도: Major**

하드코딩된 숫자 값(매직 넘버)이 곳곳에 사용되어 코드 유지보수가 어렵습니다.

### 6-1. player.gd - 점프력 배율 테이블

```gdscript
# 현재 (매직 넘버)
func _update_jump_force():
    if PlayerStats.score >= 240:
        multiplier = 4.0
    elif PlayerStats.score >= 180:
        multiplier = 3.0
    elif PlayerStats.score >= 120:
        multiplier = 2.0
    elif PlayerStats.score >= 60:
        multiplier = 1.5
```

**문제:** 60, 120, 180, 240 같은 점수 임곗값과 1.5, 2.0, 3.0, 4.0 같은 배율 값의 의미가 불명확합니다. 밸런스 조정 시 여러 곳을 수정해야 할 위험이 있습니다.

**권장 개선:**

```gdscript
# 상수 또는 @export 배열로 추출
const JUMP_THRESHOLDS: Array[Dictionary] = [
    {"score": 240, "multiplier": 4.0},
    {"score": 180, "multiplier": 3.0},
    {"score": 120, "multiplier": 2.0},
    {"score": 60,  "multiplier": 1.5},
]

func _update_jump_force() -> void:
    var multiplier: float = 1.0
    for threshold in JUMP_THRESHOLDS:
        if PlayerStats.score >= threshold.score:
            multiplier = threshold.multiplier
            break
    jump_force = base_jump_force * multiplier
```

### 6-2. poop_coin.gd - 타이머 대기 시간

```gdscript
timer.wait_time = 20.0    # 20초의 의미가 불명확
```

**권장:** 상수 또는 `@export` 변수로 추출할 것.

```gdscript
@export var transform_delay: float = 20.0
```

### 6-3. poop_coin.gd - 점수 증가량

```gdscript
body.increase_score(1)    # 매직 넘버 1
```

### 6-4. Enemy.gd - 데미지량

```gdscript
body.take_damage(1)       # 매직 넘버 1
```

**권장:** 데미지량이나 점수를 `@export` 변수로 추출하여 에디터에서 조정 가능하게 할 것.

```gdscript
@export var damage: int = 1
# ...
body.take_damage(damage)
```

---

## 7. 기타 코드 품질 이슈

### 7-1. 변수명에 대문자 사용 (Player_ui.gd)

**심각도: Major**

```gdscript
@onready var Player = get_parent()    # 변수명이 PascalCase
```

GDScript에서 변수명은 `snake_case`를 사용해야 합니다. `Player`는 클래스명처럼 보여 혼동을 줍니다.

```gdscript
@onready var player: CharacterBody2D = get_parent()    # 권장
```

### 7-2. get_parent()를 통한 강결합 (Player_ui.gd)

**심각도: Major**

```gdscript
@onready var Player = get_parent()
```

`get_parent()`로 부모 노드를 참조하면 씬 트리 구조에 강하게 의존하게 됩니다. 부모가 반드시 Player일 것이라는 가정은 위험합니다.

**권장:** `@export`로 명시적 참조를 주입하거나, 그룹/시그널 버스 패턴을 사용할 것.

```gdscript
@export var player: CharacterBody2D
```

### 7-3. game_over_scene 경로 하드코딩 (player.gd)

**심각도: Minor**

```gdscript
@export var game_over_scene: String = "res://Scenes/level_1.tscn"
```

`@export`로 노출한 것은 좋지만, `String` 대신 `PackedScene`을 사용하면 경로 오타 방지 및 에디터에서의 편의성이 향상됩니다. (참고: `endflag.gd`에서는 `PackedScene`을 올바르게 사용 중)

```gdscript
@export var game_over_scene: PackedScene
```

### 7-4. 함수 접근 제한자 불일치 (player.gd)

**심각도: Minor**

GDScript에서 `_` 접두사는 private 함수를 의미하는 관례입니다. 현재 외부에서 호출되는 함수에 일관성이 없습니다.

```gdscript
func update_animation():      # 내부 전용인데 _ 접두사 없음
func play_anim(anim_name):    # 내부 전용인데 _ 접두사 없음
func take_damage(amount):     # 외부 호출 - _ 없는 것이 올바름
func increase_score(amount):  # 외부 호출 - _ 없는 것이 올바름
func game_over():             # 내부 전용인데 _ 접두사 없음
```

**권장:** 내부 전용 함수에는 `_` 접두사를 붙일 것.

```gdscript
func _update_animation() -> void:
func _play_anim(anim_name: String) -> void:
func _game_over() -> void:
```

### 7-5. player_stats.gd의 score 변수 캡슐화 부재

**심각도: Minor**

```gdscript
# player_stats.gd
var score : int = 0
```

전역 상태를 직접 노출하고 있으며 setter/getter가 없어 값 변경 추적이 불가합니다.

```gdscript
# 권장
var score: int = 0:
    set(value):
        score = value
    get:
        return score
```

### 7-6. floor.gd - 완전히 비어 있는 스크립트

**심각도: Minor**

`floor.gd`는 빈 `_ready()`와 `_process()`만 포함하며 실질적인 로직이 없습니다. 스크립트가 불필요하다면 노드에서 스크립트를 제거하는 것이 좋습니다.

### 7-7. 공백/포맷팅 불일관

**심각도: Info**

- `player_stats.gd`: `var score : int =0` - 등호 앞 공백 누락 (`= 0`)
- `Player_ui.gd`: `i <health` - 비교 연산자 앞뒤 공백 불일치 (`i < health`)
- `player.gd`: `health <=0` - 공백 불일관 (`health <= 0`)
- `player.gd`: `increase_score (amount : int)` - 함수명과 괄호 사이 불필요한 공백
- 파일 끝 빈 줄 수가 파일마다 다름 (1개, 2개, 없음 등)

---

## 8. 전체 코드 품질 점수

| 항목 | 점수 (10점 만점) | 비고 |
|---|---|---|
| 네이밍 컨벤션 | 4/10 | 시그널, 파일명, 변수명의 일관성 부족 |
| 타입 힌트 | 3/10 | 대부분의 함수와 변수에서 누락 |
| 코드 청결도 | 5/10 | 디버그 print, 빈 함수, 템플릿 주석 잔존 |
| 설계/구조 | 6/10 | 기본 구조는 양호하나 결합도 개선 필요 |
| 매직 넘버 | 4/10 | 게임 밸런스 관련 값들이 하드코딩됨 |
| 포맷팅 일관성 | 5/10 | 공백, 빈 줄 등 사소한 불일치 다수 |
| **종합** | **4.5/10** | |

---

## 9. 우선순위별 개선 목록

### P0 - Critical (즉시 수정)

1. **시그널 네이밍 변경** - `OnUpdateHealth` / `OnUpdateScore`를 `health_updated` / `score_updated`로 변경. GDScript 컨벤션을 정면으로 위반하며 C# 스타일과 혼동을 일으킴.

### P1 - Major (가능한 빨리 수정)

2. **디버그 print 문 제거** - `player.gd`(3곳), `Dialogue_area_2d.gd`(1곳)의 모든 `print()` 호출 제거 또는 조건부 로깅으로 전환.
3. **파일명 통일** - `Enemy.gd`, `Player_ui.gd`, `Dialogue_area_2d.gd`, `Intro_Guide.gd`를 snake_case로 변경.
4. **타입 힌트 전면 추가** - 모든 함수의 매개변수 및 반환 타입, `@onready` 변수에 타입 힌트 추가.
5. **매직 넘버 상수화** - 점프력 임곗값, 데미지량, 점수 증가량, 타이머 값 등을 상수 또는 `@export` 변수로 추출.
6. **Player_ui.gd의 `Player` 변수명 수정** - `snake_case`로 변경하고 타입 힌트 추가.

### P2 - Minor (점진적 개선)

7. **빈 함수 제거** - `_process()`, `_ready()` 중 로직이 없는 것들 삭제.
8. **Godot 템플릿 주석 제거** - 자동 생성된 `# Called when...` 등의 주석 정리.
9. **함수 접근 제한자 정리** - 내부 전용 함수에 `_` 접두사 일관 적용.
10. **game_over_scene을 PackedScene 타입으로 변경** - 문자열 경로 대신 PackedScene 참조 사용.
11. **get_parent() 의존성 개선** - `@export`를 통한 명시적 참조 주입으로 변경.
12. **floor.gd 스크립트 제거 검토** - 로직이 없다면 노드에서 스크립트 분리.

### P3 - Info (개선하면 좋음)

13. **코드 포맷팅 통일** - 공백, 빈 줄, 연산자 주변 스페이싱 정리.
14. **player_stats.gd에 setter 추가** - 전역 점수 변경 추적을 위한 setter/getter 도입.
15. **미사용 변수 정리** - `poop_coin.gd`의 `is_coin` 등.

---

*이 리뷰는 GDScript 4.x 공식 스타일 가이드(https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)를 기준으로 작성되었습니다.*
