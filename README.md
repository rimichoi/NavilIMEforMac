# NavilIME for Mac — 개인 포크 (두벌식 전용)

[Manwoo Yi](https://github.com/navilera)님의 [NavilIME for Mac](https://github.com/navilera/NavilIMEforMac)을 **개인 용도로 두벌식 전용 커스터마이즈**한 포크입니다.

나빌 입력기는 원작자가 세벌식 318Na 자판을 직접 디자인하고 리눅스/윈도우/맥용 입력기를 직접 구현한 프로젝트입니다. 저는 세벌식을 쓰지 않지만, macOS 기본 한글 입력기의 불안정함이 싫어 이 가볍고 깔끔한 입력기를 두벌식 전용으로 다듬어 쓰고 있습니다.

> 📖 **원작자 README**(입력기 구현 설명, 세벌식 자판 설계 등 1,200줄 분량의 원본 문서)는
> [`README.navilera.md`](README.navilera.md)에 그대로 보존돼 있습니다.

이 포크는 [JaeyunJun](https://github.com/JaeyunJun) 포크(두벌식 전용화 · 안정성 패치)를 베이스로, 개인적으로 필요한 기능을 더하고 안 쓰는 기능을 덜어낸 것입니다.

---

## 변경 요약

### 두벌식 전용 · 안정성 (베이스: JaeyunJun)
- 세벌식 318/390 자판 제거, 두벌식만 지원
- 옵션 창 제거 → 한/영 전환 설정을 트레이 메뉴로 통합
- force unwrap 제거로 입력기 크래시 방어, 로그를 `os_log`로 전환
  (Release 빌드에서는 입력 내용을 기록하지 않음)
- 코드 서명 분리(`Signing.xcconfig` / `Local.xcconfig`)로 개인 Team ID 비공개

### 텔레그램 조합 엔터 문제 수정 (출처: [evoka](https://github.com/evoka))
- 텔레그램(macOS)에서 한글 조합 중 첫 엔터가 전송되지 않던 "엔터 두 번" 문제 해결
- 해당 앱에서만 marked text 대신 직접 삽입(direct-insert) 방식으로 조합

### 한글 조합 버그 수정
- 모음만 입력된 상태에서 자음을 치면 한 글자로 합쳐지던 문제 수정
  (예: `ㅠ`→`ㅋ`가 "큐"로, `ㅏ`→`ㄴ`이 "나"로 합쳐짐 → 각각 "ㅠㅋ", "ㅏㄴ"으로 분리)
- 일반 Windows 한글 IME와 동작 일치

### 전역 특수키(SpecialKeyTap) 제거
- 베이스에 있던 `₩` / `~` / `` ` `` 전역 입력 기능 제거 (Karabiner로 대체)
- 덕분에 **손쉬운 사용(Accessibility) 권한이 불필요**해졌고 **App Sandbox를 다시 활성화**

베이스(JaeyunJun)의 상세 변경 이력은 [CHANGES.md](CHANGES.md)를, 이 포크의 추가 변경은 커밋 히스토리를 참고하세요.

---

## 빌드 / 설치

### 1. 코드 서명 (권장: 개인 Apple Development 신원)
무서명(ad-hoc)으로 빌드하면 재빌드할 때마다 서명 식별자가 바뀝니다. 본인 신원으로
서명하면 식별자가 고정됩니다. **유료 개발자 계정은 필요 없고**, Xcode에 Apple ID를
추가하면 생기는 무료 Personal Team으로 충분합니다.

1. Xcode → Settings → Accounts 에서 Apple ID 추가 (무료 Personal Team 생성)
2. `NavilIME/Local.xcconfig.example`을 같은 폴더에 `Local.xcconfig`로 복사
3. `Local.xcconfig`에 본인 `DEVELOPMENT_TEAM`(Team ID) 입력

```sh
# 본인 Team ID 확인 (출력의 OU=XXXXXXXXXX 가 Team ID)
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
```

`Local.xcconfig`는 `.gitignore`로 커밋되지 않으므로 개인 Team ID가 저장소에 남지 않습니다.

### 2. 빌드
```sh
xcodebuild -project NavilIME.xcodeproj -scheme NavilIME -configuration Release \
  -allowProvisioningUpdates clean build
```
또는 Xcode에서 열고 ⌘B.

### 3. 설치
빌드된 `NavilIME.app`을 `~/Library/Input Methods/`에 복사한 뒤, 시스템 설정 →
키보드 → 입력 소스에서 NavilIME를 추가합니다. 같은 이름으로 이미 설치돼 있으면
실행 중인 프로세스를 종료(`killall NavilIME`)하고 덮어쓴 다음 입력기를 다시 선택하세요.

---

## 크레딧
- **원작자**: [Manwoo Yi (navilera)](https://github.com/navilera) — 입력기 구현 및 세벌식 자판 설계
- **두벌식 전용화 · 안정성 베이스**: [JaeyunJun](https://github.com/JaeyunJun)
- **텔레그램 direct-insert**: [evoka](https://github.com/evoka)
