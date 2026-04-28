# Gesture — macOS 제스처 인식 앱 설계

웹캠으로 손 제스처를 인식하여 설정된 단축키나 명령을 실행하는 macOS 네이티브 앱.

## 핵심 결정 사항

| 항목 | 결정 | 근거 |
|------|------|------|
| 플랫폼 | macOS 네이티브 (Swift/SwiftUI) | 시스템 API 직접 접근, 메뉴바 앱 |
| 제스처 인식 | MediaPipe (Python) | 21포인트 랜드마크, 커스텀 제스처 자유도 |
| IPC | Unix Domain Socket (JSON) | 최저 지연시간, 포트 불필요 |
| 제스처 타입 | 정적 포즈 + 동적 모션 | 최대 활용 범위 |
| 액션 범위 | hotkey + shell + applescript | 키보드 단축키부터 스크립트까지 |
| 설정 | YAML 파일 기반 | 멀티라인 스크립트 지원, 사람이 편집 가능 |
| UI | 메뉴바 상주 앱 | MVP에 적합한 최소 UI |

## 아키텍처

두 개의 프로세스로 구성된다:

```
┌─────────────┐         ┌──────────────────┐
│ Swift App   │         │ Python Process   │
│ • 메뉴바 UI  │         │ • MediaPipe      │
│ • 액션 실행  │◄──────►│ • 카메라 캡처     │
│ • 설정 관리  │  Unix   │ • 제스처 분류     │
│ • 프로세스   │  Socket │                  │
│   관리       │  (JSON) │                  │
└─────────────┘         └──────────────────┘
       │                        │
       ▼                        ▼
~/.gesture/config.yaml    카메라 (AVFoundation/OpenCV)
```

### Swift 앱 (GestureApp/)

메뉴바에 상주하며 시스템 제어를 담당한다.

- **GestureApp.swift** — `@main` 진입점, `MenuBarExtra` 기반 메뉴바 앱
- **SocketClient.swift** — Unix Domain Socket 클라이언트, Python 프로세스와 JSON 메시지 송수신
- **ActionExecutor.swift** — 제스처에 매핑된 액션 실행 (hotkey/shell/applescript)
- **ConfigManager.swift** — `~/.gesture/config.yaml` 파싱 및 관리
- **ProcessManager.swift** — Python 프로세스 launch/terminate/재시작
- **StatusBarController.swift** — 메뉴바 아이콘 및 상태 표시

### Python 엔진 (engine/)

카메라 캡처와 제스처 인식을 전담한다.

- **main.py** — 엔진 진입점, 메인 루프
- **camera.py** — OpenCV로 카메라 프레임 캡처
- **detector.py** — MediaPipe Hands로 손 랜드마크 추출
- **classifier.py** — 정적/동적 제스처 분류기
- **socket_server.py** — Unix Domain Socket 서버

## 데이터 흐름

1. `camera.py`가 카메라에서 프레임 캡처 (30fps)
2. `detector.py`가 MediaPipe로 손 랜드마크 21포인트 추출
3. `classifier.py`가 포즈/모션 패턴 매칭
4. `socket_server.py`가 인식 결과를 Swift에 전송: `{"gesture": "thumbs_up", "confidence": 0.95}`
5. Swift `ActionExecutor`가 config에서 매핑된 액션을 조회하여 실행

## 제스처 분류기

### 정적 포즈 인식 (StaticClassifier)

ML 모델 없이 규칙 기반(rule-based)으로 동작한다.

각 손가락의 펴짐/접힘을 랜드마크 좌표 비교로 판별:
- `fingertip.y < finger_pip.y` → 펴짐 (엄지는 x축 비교)

포즈 = 5개 손가락 상태의 조합:
- `thumbs_up = [1, 0, 0, 0, 0]` (엄지만 펴짐)
- `peace = [0, 1, 1, 0, 0]` (검지+중지 펴짐)
- `open_palm = [1, 1, 1, 1, 1]` (모두 펴짐)
- `fist = [0, 0, 0, 0, 0]` (모두 접힘)
- `ok_sign` — 엄지와 검지 끝 거리 < 임계값 + 나머지 펴짐

### 동적 모션 인식 (MotionTracker)

손바닥 중심점의 궤적을 분석한다.

1. 최근 15~20프레임의 손바닥 위치를 링 버퍼에 저장
2. 이동 거리가 임계값 초과 시 모션 시작 판별
3. 궤적의 주 방향 벡터를 추출하여 분류:
   - `swipe_left` — 주 방향이 ← (`dx < -threshold`)
   - `swipe_right` — 주 방향이 → (`dx > threshold`)
   - `swipe_up` — 주 방향이 ↑ (`dy < -threshold`)
   - `swipe_down` — 주 방향이 ↓ (`dy > threshold`)
   - `circle` — 궤적의 각도 변화 합 ≈ 360° (post-MVP)
   - `wave` — x축 방향 전환 횟수 ≥ 3 (post-MVP)

### 오인식 방지 (CooldownManager)

- 제스처별 쿨다운 타이머 (기본 800ms) — 같은 제스처 연속 트리거 방지
- confidence 임계값 (기본 0.85) — 불확실한 인식 필터링
- 정적 포즈는 N프레임 연속 인식 시에만 확정 (안정화)

## Unix Socket 프로토콜

줄바꿈으로 구분된 JSON (JSONL) 형식.

```json
// Python → Swift: 제스처 인식
{"type": "gesture", "name": "thumbs_up", "confidence": 0.95, "timestamp": 1710841200}

// Python → Swift: 상태 업데이트
{"type": "status", "hands_detected": 1, "fps": 28.5}

// Swift → Python: 설정 변경
{"type": "config_update", "confidence_threshold": 0.90}

// Swift → Python: 제어 명령
{"type": "command", "action": "pause"}
```

소켓 경로: `/tmp/gesture.sock`

## 설정 파일

경로: `~/.gesture/config.yaml`

```yaml
camera:
  device: 0
  fps: 30
  resolution: [640, 480]

recognition:
  confidence_threshold: 0.85
  cooldown_ms: 800
  motion_buffer_frames: 20
  static_confirm_frames: 3

gestures:
  thumbs_up:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "c"]

  peace:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "v"]

  fist:
    type: static
    action:
      type: shell
      command: "osascript -e 'tell application \"Spotify\" to playpause'"

  open_palm:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "tab"]

  ok_sign:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "space"]

  swipe_left:
    type: motion
    action:
      type: shell
      command: "open -a 'Mission Control'"

  swipe_right:
    type: motion
    action:
      type: hotkey
      keys: ["cmd", "shift", "4"]
```

## 액션 타입

### hotkey
CGEvent API로 키보드 입력을 시뮬레이션한다.
- 지원 modifier: `cmd`, `shift`, `ctrl`, `opt`
- 지원 키: `a-z`, `0-9`, `F1-F12`, `space`, `tab`, `enter`, `esc`, 방향키
- Accessibility 권한 필요 (System Preferences → Privacy → Accessibility)

### shell
`Process()`로 셸 명령을 실행한다.
- `/bin/zsh -c "command"` 형태로 실행
- stdout/stderr 캡처하여 로깅
- 타임아웃 10초 (무한 대기 방지)

### applescript (post-MVP)
`NSAppleScript`로 AppleScript를 직접 실행한다.
- YAML의 `|` 블록 리터럴로 멀티라인 스크립트 지원
- 앱 제어, 시스템 설정 변경 등에 활용

## 필요 권한 (macOS)

- **카메라 접근** — `NSCameraUsageDescription` (Info.plist)
- **Accessibility** — CGEvent API 사용을 위해 필요 (수동 허용)
- **Automation** — AppleScript 실행 시 대상 앱별 허용 (post-MVP)

## 기술 스택

| 컴포넌트 | 기술 |
|----------|------|
| Swift 앱 | Swift 5.9+, SwiftUI, AppKit |
| YAML 파싱 | Yams (Swift Package) |
| 키 입력 | CGEvent (CoreGraphics) |
| 카메라 | OpenCV (Python) |
| 손 인식 | MediaPipe Hands 0.10+ |
| IPC | Unix Domain Socket (Foundation / Python socket) |
| 빌드 | Xcode (Swift), pip/venv (Python) |

## MVP 스코프 (v0.1)

### 포함

- 메뉴바 상주 앱 (시작/정지 토글)
- 정적 포즈 5종: 주먹, 브이, 엄지척, 손바닥, OK
- 동적 모션 2종: 좌/우 스와이프
- hotkey 액션 실행
- shell 명령 실행
- YAML 설정 파일
- Python 프로세스 자동 관리 (launch/terminate/재시작)
- 메뉴바 상태 표시 (감지중/정지/손 감지됨)

### 미포함 (post-MVP)

- AppleScript 액션 타입
- 원 그리기, 손 흔들기 등 추가 모션
- GUI 설정 화면
- 실시간 카메라 미리보기 창
- 커스텀 제스처 학습/등록
- 멀티 핸드 (양손 제스처)
- 로그인 시 자동 시작 (Login Items)
- 제스처 인식 통계/로그 뷰어
