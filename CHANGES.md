# NavilIME 개인 수정 기록

이 프로젝트는 **Manwoo Yi**([@navilera](https://github.com/navilera))님이 만든 macOS용 한글 입력기입니다.
세벌식 318Na 자판을 직접 디자인하고, 리눅스/윈도우/맥 전부 입력기를 직접 구현하신 분입니다.
아래는 개인 용도로 포크하여 수정한 내용입니다.

원본: [navilera/NavilIMEforMac](https://github.com/navilera/NavilIMEforMac)

## 2026-11-17 - 교차리뷰 반영

### 마우스 이벤트의 `keyCode` 예외
- `handle()`이 이벤트 종류와 상관없이 `event.keyCode`를 읽어, 마우스 이벤트마다
  `NSInternalInconsistencyException`이 났다(IMK가 잡아 로그만 남김). 그래서 클릭 시
  조합을 확정하는 마우스 분기가 실행되지 않았다.
- 한영 전환 판정을 `keyDown`/`flagsChanged`에서만 하도록 한정. 이제 텍스트 안을
  클릭하면 조합 중인 글자가 확정된다.

### 텔레그램 직접 삽입: 글자 조회 실패 시 덮어쓰기
- `attributedSubstring(from:)`이 nil을 주면 화면 글자가 그대로라고 보고 그 범위를
  교체해, 외부에서 바뀐 같은 길이의 텍스트를 덮어쓸 수 있었다. 키 처리 전 판정
  (`direct_sync_check`)에서 nil이면 조합을 버리도록 수정.
- `Testcases.swift`에 `run_discard()` 회귀 테스트 추가.

## 2026-08-10 - 두벌식 모음 연타 분리

### 같은 모음 연타를 ㅒ/ㅖ로 합치지 않음
- `jungsung_layout`에 남아 있던 연타 매핑 `"oo"`(→ㅒ), `"pp"`(→ㅖ) 제거.
  ㅔ를 두 번 치면 ㅖ, ㅐ를 두 번 치면 ㅒ로 합쳐지던 문제 해결.
- ㅒ/ㅖ는 쌍자음과 같이 Shift 조합(`Shift+o`, `Shift+p`)으로만 입력한다.
  2026-05-23의 "두벌식 ㄷㄷㄷ 옵션 제거"에서 초성 쪽 연타 매핑만 없애
  ㅂㅂ는 분리되는데 ㅔㅔ만 합쳐지던 비대칭을 해소한 것.
- `Testcases.swift`에 `run_vowel_repeat()` 회귀 테스트 추가.
- 전용 테스트 타깃이 없어 `Test002`가 실행되지 않던 문제 보완: Debug 빌드
  실행 시 `AppDelegate`에서 오토마타 테스트를 돌린다. (Release는 컴파일 제외)

## 2026-07-16 - 한영 전환 간헐 먹통 해결

### `handle()`의 nil 이벤트 강제 언랩 크래시
- **증상**: 한영 전환이 간헐적으로 안 되다 잠시 뒤 스스로 복구됨. 그 순간
  입력 메뉴에서 NavilIME이 회색(비활성)으로 흐려져 있었음.
- **원인**: IMK가 `event=nil`로 `handle()`을 호출하는 경우가 있는데, 파라미터가
  `NSEvent!`(암시적 언랩)라 nil인 채 `event.keyCode`에 접근하면
  "Unexpectedly found nil while implicitly unwrapping" 트랩(EXC_BREAKPOINT,
  thread 0)으로 메인 스레드가 죽는다. macOS가 입력기를 회색으로 흐리고 자동
  재실행하는데, 이 사망→재실행이 '먹통→자가복구'의 정체였다.
  (크래시 리포트: `NavilIME-2026-07-09-165910.ips`)
- `handle()` 맨 앞에 `guard let event = event else { return false }` 추가.
- `recognizedEvents`에서 `appKitDefined`/`applicationDefined`/`systemDefined`
  구독 제거. 구독 중에는 문자 뷰어(⌃⌘Space)를 닫은 뒤 `setMarkedText`가 무시돼
  한글 조합만 먹통이 됐다(숫자/영문은 `insertText`라 입력됨).
  `keyDown` + `flagsChanged` + mouse만 구독한다.

## 2026-06-23 - 열린 음절 조합 버그

### 모음만 입력된 상태에서 자음이 오면 잘못 합쳐지는 문제
- **증상**: 중성(모음)만 있고 초성이 비어 있는 상태에서 자음을 입력하면 자음이
  비어 있는 초성 자리에 채워져 모음과 합쳐졌다. 예) ㅠ 다음 ㅋ → "큐",
  ㅏ 다음 ㄴ → "나".
- 한글은 초성이 중성보다 앞서야 하므로 이미 입력된 중성 앞에 초성을 끼워 넣을
  수 없다. `Automata.chosung()`에서 초성이 비어 있고 중성이 이미 있으면 현재
  글자를 확정(`done`)하고, 들어온 자음은 다음 글자의 초성으로 시작하도록 수정.
  Windows 등 일반 한글 IME와 동작 일치.
- `Testcases.swift`에 `run_open_syllable()` 회귀 테스트 추가 (ㅠ→ㅋ, ㅏ→ㄴ).

## 2026-06-23 - 텔레그램 직접 삽입, 전역 특수키 제거

### 텔레그램 조합 중 엔터가 첫 타에 전송되지 않는 문제
- 텔레그램은 입력기보다 먼저 `엔터 && !hasMarkedText()`로 전송을 판정한다.
  `direct_insert_clients`(`ru.keepcoder.Telegram`)에서는 marked text 대신 조합 글자를
  실제 텍스트로 넣고 `insertText(replacementRange:)`로 교체한다
  (`direct_update`/`direct_sync_check`, `Hangul.InputCount()`/`Discard()`).

### 특수키 조합 기능 제거
- `SpecialKeyTap`(전역)과 IMK 경로의 `special_keys`(`Shift+ESC→~`, `Cmd+ESC→\``,
  `Cmd+\→₩`), 손쉬운 사용 권한 메뉴를 제거. 아래 2026-05-27, 2026-04-14의 특수키 항목은
  더 이상 동작하지 않는다.
- 손쉬운 사용 권한이 필요 없어져 App Sandbox를 다시 켬.
- 개인 IDE 상태 파일(`*.xcuserstate`, `xcschememanagement.plist`) 추적 해제.

## 2026-05-27 - 전역 특수키 입력 및 개인 빌드 서명

### 특수키 조합을 다른 입력기 상태에서도 동작 (전역) — 2026-06-23 제거
- `SpecialKeyTap`: 세션 레벨 `CGEventTap`으로 특수키 조합(`Shift+ESC→~`,
  `Cmd+ESC→\``, `Cmd+\→₩`)을 전역에서 가로채 치환.
- 현재 입력기가 NavilIME가 아닐 때만 가로채고, NavilIME 활성 시엔 기존 IMK
  경로가 처리하도록 분기 → 이중 처리 방지.
- 탭이 타임아웃/사용자 입력으로 비활성화되면 자동 재활성화.
- App Sandbox에서는 전역 이벤트 탭이 막히므로 entitlements에서 `app-sandbox`를
  끔. (App Store가 아닌 직접 설치 방식이라 무방)

### 손쉬운 사용 권한 UI — 2026-06-23 제거
- `CGEventTap`은 손쉬운 사용(Accessibility) 권한이 필요.
- 트레이 메뉴에 "특수키 전역 입력 권한 허용…" 항목 추가. 권한이 있으면
  "특수키 전역 입력: 켜짐 ✓"로 표시(비활성).
- 클릭 시 시스템 권한 요청 + 손쉬운 사용 설정 창 열기 + 안내 alert.
  LSBackgroundOnly 환경에서도 표시되도록 활성화 정책을 잠시 올림.
- 부팅 시 권한이 이미 있으면 탭 자동 시작.

### 개인 빌드 서명 구조
- `Signing.xcconfig`(기본 ad-hoc) + `Local.xcconfig.example`(템플릿) 도입.
  실제 `Local.xcconfig`는 `.gitignore`로 커밋 제외 → 개인 Team ID 비공개.
- pbxproj에서 하드코딩된 `DEVELOPMENT_TEAM`/`CODE_SIGN_IDENTITY` 제거,
  `baseConfigurationReference`로 xcconfig 연결.
- `.gitignore` 신설, 추적되던 `.DS_Store` 추적 해제.

## 2026-05-23 - 옵션 창 제거 및 안정성 라운드

### 옵션 창 제거, 한영전환 단축키를 트레이 메뉴로 통합
- 옵션 창과 관련 xib UI 전체 제거
- 한/영 전환 단축키 설정(시스템입력기 사용 / 왼쪽 Shift+Space / 오른쪽 Command / 오른쪽 Option)을 트레이 메뉴 라디오 항목으로 이동

### 두벌식 ㄷㄷㄷ 옵션 제거
- 같은 자음 연속 입력을 쌍자음으로 합치는 옵션 제거
- `shift_cho`(분리 입력) 동작을 영구 기본으로 고정, 관련 테이블/영속화 코드 단순화

### 안정성 개선
- 죽은 NSScrollView 출력을 `os_log` 래퍼로 교체 (Console.app에서 `subsystem=io.navilera.NavilIME`로 필터링)
- `setMarkedText` selectionRange를 grapheme count 대신 NSString.length(UTF-16)로 계산 (NFD 분해된 한글 잘림 방지)
- cmd/option/control이 눌린 keycode는 hotfix 순환버퍼에 넣지 않음 (false-positive 방지)
- 드래그 매 프레임 commit 호출 제거
- IBOutlet들을 옵셔널로 변경, xib에 위젯이 없어도 크래시 없이 진행

## 2026-04-14 - 대규모 정리 및 개선

### 세벌식 제거
- 세벌식 318, 390 키보드 코드 전부 삭제 (`Keyboard318.swift`, `Keyboard390.swift`)
- 두벌식(Keyboard002)만 남김
- Hangul, Keyboards, SingletonMenu, SingletonOpt, Testcases 등에서 관련 참조 모두 제거
- 트레이 메뉴에서 키보드 선택 항목 제거 (옵션 메뉴만 남김)

### 옵션 창 개선
- 디버깅용 scrollView 제거
- 윈도우 크기 축소 (517px -> 210px)
- 타이틀 "NavilIME 옵션"으로 변경
- AppDelegate에서 디버그 로그 설정 코드 제거

### 특수키 조합 추가 — 2026-06-23 제거
- `Shift + ESC` -> `~` (물결)
- `Cmd + ESC` -> `` ` `` (백틱)
- `Cmd + \` -> `₩` (원화 기호)
- 테이블 기반으로 구현되어 있어 `special_keys` 배열에 추가만 하면 확장 가능

### 크래시 방어
- `Hangul!` (force unwrap) -> `Hangul?` (optional)로 변경
- `Automata` 접근 시 `guard let` 패턴 적용
- macOS가 비정상 순서로 생명주기 호출할 때 (화면 잠금, 슬립 복귀, 빠른 앱 전환) 크래시 방지

### Hotfix 버퍼 오염 방지
- 특수키 조합을 Hotfix 패턴 체크 이전에 처리
- ESC 등의 keycode가 hotfix circular buffer에 들어가지 않음
