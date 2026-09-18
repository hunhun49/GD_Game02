# 탑다운 기본 시스템

## 현재 방향

2026-09-16부터 횡스크롤 플랫폼 방식에서 **포켓몬 구작처럼 위에서 내려다보는 2D 탑다운 방식**으로 전환했습니다. Godot **4.7.2**에서 검증합니다.

- 기본 이동은 **8방향 자유 이동**입니다. 격자 한 칸씩 이동하는 방식은 아닙니다.
- 캐릭터 그림은 위·아래·왼쪽·오른쪽의 **4방향**을 표현합니다.
- **F2**로 4방향과 8방향 이동을 실행 중 비교할 수 있습니다.
- 운동장과 본관 교실에서 나무·책상 사이를 돌아다니며 NPC, 게시판, 문과 상호작용합니다.
- 게임 시간과 허기·갈증·피로, 방향별 호감도와 조건별 재방문 대사를 지원합니다. 설정은 [관계·생활 시스템 가이드](relationship-life-system.md)를 참고하세요.
- 점프·중력·대시·이동 발판은 현재 프로토타입에서 제거했습니다.

## 실행과 조작

`gd-game-02/project.godot`를 Godot에서 열고 **F5**를 누릅니다. 인게임·HUD·메뉴의 편집 위치와 단독 실행은 [게임 구조 가이드](game-architecture.md)를 참고하세요. 기본 해상도는 1280×720이며 Compatibility 렌더러를 사용합니다.

| 행동 | 키보드 | 게임패드 |
|---|---|---|
| 이동 | WASD, 방향키 | 왼쪽 스틱, 방향 패드 |
| 상호작용 | E | X |
| 기본 공격 / 체간 붕괴 시 제압 | 좌클릭 (J 유지) | B |
| 가드 / 타격 직전 튕겨내기 | 우클릭 (K 유지) | LB |
| 커서 방향 회피 / 붉은 공격 돌진 패링 | Shift | A |
| 보라색 공격 / 보라색 상쇄 | Q | RB |
| 대상 변경 | Tab | Y |
| 대화 다음/완료 | E, Space, Enter | X, A |
| 대화 취소 / 일시정지 | Esc | Start |
| 체크포인트 복귀 / 전투 불능 회복 | R | 미지정 |
| 4방향 ↔ 8방향 비교 | F2 | 미지정 |

게임패드 버튼 이름은 Xbox 기준입니다. 바인딩은 구현했지만 실제 패드 기기에서의 조작감은 별도 확인이 필요합니다. `프로젝트 설정 → 입력 맵`에서 변경할 수 있습니다.

## 이동과 충돌 규칙

- 플레이어의 `Movement` 노드에 있는 `mode` 기본값은 `EIGHT_DIRECTIONS`입니다. Inspector에서 `FOUR_DIRECTIONS`로 바꾸면 다음 실행부터 4방향으로 시작합니다. F2 변경은 저장하지 않습니다.
- 키보드 대각선 이동 속도는 직선 이동과 동일합니다. 스틱 입력도 이동 모드에 맞게 4개 또는 8개 방향으로 보정하며 입력 크기로 속도를 조절합니다.
- 4방향 모드에서 두 축을 함께 누르면 새로 누른 축을 우선하고, 계속 누르는 동안 방향을 유지합니다. 방향 전환 때 이전 축의 속도를 제거합니다.
- 캐릭터의 기준 위치는 **발밑**이며 플레이어는 반지름 10px의 원, NPC는 발밑 사각형으로 충돌합니다. 그림의 머리나 몸통 전체를 충돌체로 사용하지 않습니다.
- 장애물은 바닥에서 차지하는 영역인 `footprint`로 충돌합니다. 나무의 잎 아래로 걸어갈 수 있고 줄기는 통과할 수 없습니다.
- 플레이어와 사물은 발밑 Y좌표가 클수록 앞에 그려집니다. 메인 씬과 구역 씬의 `y_sort_enabled`를 함께 켜 두었습니다.

입력 크기는 [`Input.get_vector`](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-get-vector)로 제한하고, 앞뒤 가림은 [Godot의 Y 정렬](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-y-sort-enabled)을 사용합니다.

## 직접 확인할 순서

1. WASD와 방향키로 운동장을 걸어 봅니다. 두 방향을 함께 눌러 대각선으로 이동합니다.
2. F2로 4방향 모드로 바꿔 같은 길을 걸어 봅니다. 상단 안내에 현재 모드가 표시됩니다.
3. 왼쪽 나무 뒤를 지나 가려지는지, 나무 앞으로 오면 다시 보이는지 확인합니다.
4. 서윤과 대화하기 전에 본관 문을 바라보고 E를 누르면 출입 등록 안내가 나옵니다.
5. 서윤과 대화하다 Esc로 닫으면 출입 권한을 받지 않습니다. 마지막 대사까지 넘겨야 문이 열립니다.
6. 본관 문 앞에서 E를 눌러 들어갑니다. 출입은 자동 접촉 전환이 아닌 **명시적 상호작용**입니다.
7. 민재와 시간표 사이에서 위를 바라보고 Tab으로 대상을 바꿔 봅니다. 뒤돌아보면 앞에 있던 대상의 강조가 사라집니다.
8. 책상과 NPC에 부딪혀 보고, 사이의 통로로 이동합니다.
9. 깃발을 조사해 체크포인트를 등록합니다. 잠시 이동한 후 R을 눌러 등록 위치로 복귀합니다.
10. 교실 왼쪽 아래 문을 바라보고 E를 눌러 운동장에 돌아옵니다. 출입 권한은 유지됩니다.

## 상호작용과 대화

`interaction_detector.gd`가 범위 안의 대상 중 바라보는 방향과 거리를 기준으로 하나를 선택합니다. 뒤쪽 대상과 벽에 가려진 대상은 제외합니다. 선택한 대상에는 강조 표시와 하단 행동 안내가 나옵니다. Tab/패드 Y로 인접 대상을 전환할 수 있습니다.

NPC와 게시판은 충돌체를 가지고 있지만 자신의 상호작용 광선을 막지 않습니다. 문 판정은 문 발밑 위치를 기준으로 하므로 벽 앞의 입구를 조사할 수 있습니다.

대화 중에는 플레이어와 구역의 동작을 정지합니다. 검증된 JSON의 `on_complete` 효과는 대화를 끝까지 마쳤을 때만 실행합니다. 구조·데이터 규칙·확장 방법은 [대화 시스템 가이드](dialogue-system.md)를 참고하세요. 구역 전환 후에도 플래그는 유지됩니다.

체크포인트는 깃발의 충돌체 안이 아닌 **상호작용 당시 플레이어가 서 있던 위치**를 기록합니다. 구역을 바꾸면 새 구역의 도착 지점으로 초기화됩니다. 맵 경계에는 충돌 벽을 두었고, 경계 밖으로 나간 경우에도 체크포인트로 복귀합니다.

## 파일 구조

```text
gd-game-02/
├── scenes/
│   ├── main.tscn               # 전체 게임 구성
│   ├── game/ingame.tscn        # 월드·플레이어·카메라, 독립 실행
│   ├── ui/
│   │   ├── game_ui.tscn        # UI 묶음, 독립 실행
│   │   ├── hud.tscn            # 위치·상태·조작·상호작용 표시
│   │   ├── dialogue_view.tscn  # 독립 대화창
│   │   └── pause_menu.tscn     # 독립 일시정지 메뉴
│   ├── characters/             # 공통 캐릭터와 NPC 상속 씬
│   ├── player.tscn             # 공통 캐릭터 상속, 입력·카메라·대상 감지
│   ├── world_prop.tscn         # 벽, 책상, 나무, 벤치, 건물, 수납장
│   ├── interactable.tscn       # 게시판, 문, 체크포인트와 상호작용 컴포넌트
│   └── zones/                 # 운동장·본관 교실
├── scripts/
│   ├── main.gd                # 상태 객체 생성과 연결부 설정
│   ├── game/                  # 인게임, 영역 연결, 상태·잠금
│   ├── ui/                    # 표시 API와 UI 요청
│   ├── dialogue/              # 로딩·진행·UI 연동·효과 처리기
│   ├── characters/            # 정의·상태·이동·제어·표현
│   ├── interactions/          # 상호작용 컴포넌트·행동·컨텍스트
│   ├── player.gd              # 공통 캐릭터를 상속하는 플레이어 역할
│   ├── world_prop.gd          # 발밑 영역 충돌과 도형 표시
│   ├── interactable.gd        # 사물 외형과 충돌체
│   ├── interaction_detector.gd # 거리·방향·벽 검사와 대상 전환
│   └── zone.gd                # 구역 속성과 바닥 도형
├── data/characters/           # 캐릭터별 정의 Resource
├── data/dialogues.json        # 버전이 있는 대사·완료 효과 데이터
├── ui/theme.tres              # 시스템 한글 폰트
└── tests/                     # 분리 구조·대화·게임 회귀 검사
```

## 콘텐츠 확장

### 가구·나무·벽

구역 씬에 `world_prop.tscn`을 인스턴스로 추가합니다.

- `kind`: 벽, 책상, 나무, 벤치, 건물, 수납장 중 선택합니다.
- `footprint`: 사물이 바닥에서 차지하는 영역의 가로·세로 크기입니다.
- 노드의 원점은 충돌 영역의 **아래쪽 중앙**입니다. 충돌 영역은 X축으로 좌우 절반씩, Y축으로 위쪽에 배치됩니다.
- `tint`: 벽과 가구, 나무의 색상을 조정합니다.

사물은 플레이어와 같은 `z_index`를 유지해야 Y 정렬에 참여합니다. 나무의 `footprint`는 잎 전체가 아닌 줄기 주변만 포함하도록 두세요. 바닥에는 플레이어를 막는 큰 충돌체를 두지 않습니다.

### NPC·게시판·체크포인트

NPC는 `characters/npc.tscn`을 추가하고 고유 `character_id`와 `CharacterDefinition`을 설정합니다. 게시판·체크포인트는 `interactable.tscn`을 추가하고 외형용 `kind`를 지정합니다. 각 씬의 자식 `Interaction`에서 이름·안내 문구와 행동 Resource를 설정합니다. NPC와 게시판은 `DialogueInteraction.dialogue_id`와 같은 키를 `data/dialogues.json`에 추가합니다. 자세한 설정은 [캐릭터 시스템 가이드](character-system.md)를 참고하세요.

```json
{
  "lines": [
    {"speaker": "도서부원", "text": "도서관 출입 등록을 해 줄게."}
  ],
  "on_complete": [
    {"type": "set_flag", "parameters": {"key": "library_access", "value": true}},
    {"type": "notify", "parameters": {"text": "도서관 출입 등록 완료"}}
  ]
}
```

이 대화 정의를 `dialogues.json`의 `dialogues` 객체 안에 `"new_npc"` 같은 ID로 추가합니다. 파일 루트에는 `"schema_version": 1`이 필요합니다. `on_complete`는 선택 항목입니다. 노드 위치는 발밑에 맞추며 근처에 접근 가능한 공간을 확보합니다.

### 새 구역과 문

1. 기존 구역 씬을 복제하고 `zone_title`, `bounds`, 바닥과 장애물을 수정합니다.
2. `Spawns` 아래에 `Marker2D`를 만들고 플레이어가 도착할 발밑 좌표에 둡니다. 충돌체와 겹치지 않게 배치합니다.
3. `scripts/game/ingame.gd`의 `ZONES`에 새 구역 ID와 씬을 등록합니다.
4. 문 인스턴스의 `kind`를 `DOOR`로 지정하고, 자식 `Interaction.action`에 `DoorInteraction`을 연결해 `destination_zone`, `destination_spawn`을 입력합니다.
5. 잠긴 문의 행동 Resource에 `required_flag`와 `locked_dialogue_id`를 설정합니다.
6. 문 원점은 건물·벽 충돌 영역의 **바깥쪽**에 둡니다. 예를 들어 건물의 아래쪽 끝이 Y=350이면 문 원점을 Y=355, 도착 지점을 Y=410에 둡니다.
7. 화면 아래쪽으로 나가는 실내 문에는 `floor_doorway`를 켭니다. 세워진 문 그림 대신 바닥 출구 표시를 사용해 접근하는 캐릭터를 가리지 않습니다.

충돌 레이어는 **1: World / 2: Player**입니다. 상호작용 광선은 World 레이어를 검사합니다. 문 자체는 이동을 막지 않으며 주변 건물·벽의 충돌체가 경계를 형성합니다.

## 검증

```sh
godot --headless --path gd-game-02 --editor --import --quit
godot --headless --path gd-game-02 --script res://tests/character_test.gd
godot --headless --path gd-game-02 --script res://tests/ui_world_test.gd
godot --headless --path gd-game-02 --script res://tests/dialogue_test.gd
godot --headless --path gd-game-02 --script res://tests/systems_test.gd
```

`godot`가 PATH에 없다면 설치된 실행 파일 경로로 대체합니다. 최초 임포트 후 검사를 실행하세요. 검사는 8방향 속도, 4방향 전환, 벽·나무·NPC·책상 충돌, 방향별 상호작용, 대화 완료·취소, 건물 왕복, 체크포인트와 일시정지를 확인합니다. 화면에서는 운동장·교실 배치와 나무 앞뒤 가림을 별도로 확인합니다.

## 남은 범위

현재 그래픽은 도형으로 만든 임시 표현입니다. 실제 방향별 스프라이트, 타일셋, 대화 선택지, 퀘스트, 수업 시간표 진행, 파일 저장 시스템은 후속 작업입니다. 캐릭터·관계·게임 시간·신체 상태의 메모리 보관과 JSON 스냅샷·복원 기반은 구현되어 있습니다. 출입 플래그, 체크포인트와 실행 중 바꾼 이동 모드는 게임 종료 시 초기화됩니다.

한글은 운영체제의 Apple SD Gothic Neo, 맑은 고딕, Noto Sans 계열 폰트를 사용합니다. 배포 시에는 사용 허가를 확인한 한글 폰트를 프로젝트에 포함해야 운영체제 간 표시가 일정해집니다.

현재 가드·튕겨내기·체간·제압과 훈련 로봇 동작은 [체간 공방 A안](duel-prototype.md)을 참고하세요. 체력·스태미나 저장 기반의 기록은 [전투 기반 가이드](combat-system.md)에 있습니다.
