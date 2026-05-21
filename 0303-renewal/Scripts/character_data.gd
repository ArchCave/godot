class_name CharacterData extends Resource

## 한 캐릭터의 모든 데이터를 담는 단일 출처(single source of truth).
## 캐릭터 선택 화면, PlayerStats, 인게임 Player.tscn이 공통으로 이 리소스를 참조한다.
##
## 새 캐릭터를 추가하려면:
##   1. Resorces/Characters/ 안의 .tres 파일을 복제
##   2. 아래 필드를 채워 넣고
##   3. PlayerStats.characters 배열에 등록
##
## Player.tscn은 _ready()에서 PlayerStats.get_selected()를 읽어
## sprite_texture / animation_library / 스탯 / skill_scene 등을 자기 자신에 적용한다.
## 따라서 캐릭터마다 별도의 씬을 만들 필요가 없고, 레벨 파일도 수정할 필요가 없다.

# ── 식별 ────────────────────────────────────────────────────────────────
@export var id: StringName = &"bird"
@export var display_name: String = "WALKING BIRD"

# ── 인게임 비주얼 ──────────────────────────────────────────────────────
## Player.tscn의 Sprite2D에 적용될 텍스처. null이면 Player.tscn 기본값 유지.
@export_group("In-game Visuals")
@export var sprite_texture: Texture2D
@export var sprite_hframes: int = 1
@export var sprite_vframes: int = 1
## Player.tscn의 AnimationPlayer에 적용할 라이브러리.
## "Idle", "Walk", "Jump", "Death" 4개 애니메이션을 반드시 포함해야 한다
## (player.gd가 이 이름으로 호출함).
## null이면 Player.tscn에 임베드된 기본 라이브러리(걸음새 새 애니메이션)를 그대로 사용.
@export var animation_library: AnimationLibrary
## 캐릭터별 스프라이트 위치 보정. 스프라이트 시트의 빈 여백 때문에
## 충돌체 중심과 시각적 중심이 어긋날 때 사용. y가 음수면 위로 올라간다.
@export var sprite_offset: Vector2 = Vector2.ZERO
## Idle 애니메이션일 때만 sprite_offset에 추가로 더해지는 보정.
## (Idle 프레임만 다른 프레임보다 살짝 위/아래로 어긋날 때 사용)
@export var idle_offset_delta: Vector2 = Vector2.ZERO
## Walk 애니메이션일 때만 sprite_offset에 추가로 더해지는 보정.
@export var walk_offset_delta: Vector2 = Vector2.ZERO

# ── 캐릭터 선택 화면 미리보기 ──────────────────────────────────────────
@export_group("Select Screen Preview")
@export var preview_texture: Texture2D
@export var preview_hframes: int = 1
@export var preview_vframes: int = 1
@export var preview_frame: int = 0
@export var preview_scale: Vector2 = Vector2(3, 3)

# ── 스탯 (CharacterBody2D 파라미터 오버라이드) ─────────────────────────
@export_group("Stats")
@export var move_speed: float = 25.0
@export var air_speed_multiplier: float = 1.6
@export var jump_force: float = 100.0
@export var max_health: int = 5
@export var climb_speed: float = 40.0

# ── 캐릭터 고유 스킬 / 공격 (씬으로 정의) ──────────────────────────────
## ui_attack 입력 시 인스턴스화되는 씬. null이면 공격 비활성.
@export_group("Skills")
@export var attack_scene: PackedScene
## ui_skill 입력 시 인스턴스화되는 씬. null이면 스킬 비활성.
@export var skill_scene: PackedScene

# ── 가용성 ─────────────────────────────────────────────────────────────
@export_group("Availability")
## false면 선택 화면에서 "준비 중" 표시 + 선택 차단.
@export var implemented: bool = true

# ── (옵션) 캐릭터별 전용 씬 ────────────────────────────────────────────
## 보통은 비워둔다 — 모든 캐릭터가 같은 Player.tscn을 공유하기 때문.
## 만약 특정 캐릭터만 완전히 다른 노드 구조가 필요하다면 여기에 지정하고
## PlayerStats.get_selected_scene()을 사용하면 된다.
@export_group("Advanced")
@export var scene: PackedScene
