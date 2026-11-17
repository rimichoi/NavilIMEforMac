//
//  NavilIMEInputController.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/4/22.
//

import InputMethodKit

@objc(NavilIMEInputController)
open class NavilIMEInputController: IMKInputController {
    let key_code:String =       "asdfhgzxcv\tbqweryt123465=97-80]ou[ip\tlj'k;\\,/nm.\t `"
    let shift_key_code:String = "ASDFHGZXCV\tBQWERYT!@#$^%+(&_*)}OU{IP\tLJ\"K:|<?NM>\t ~"
    
    var hangul:Hangul?

    // 이 앱들은 입력기보다 먼저 keyDown에서 `엔터 && !hasMarkedText()`로 전송을 판정해, marked text로
    // 조합하면 엔터가 첫 타에 전송되지 않는다. 그래서 조합 글자를 실제 텍스트로 넣고 교체한다.
    // 추가할 앱은 attributedSubstring(from:)이 nil을 주지 않아야 한다(nil이면 매 키 조합이 버려진다).
    static let direct_insert_clients:Set<String> = ["ru.keepcoder.Telegram"]

    func is_direct(_ client:Any!) -> Bool {
        guard let disp = client as? IMKTextInput else { return false }
        return NavilIMEInputController.direct_insert_clients.contains(disp.bundleIdentifier() ?? "")
    }

    // 직접 삽입 모드 상태: 화면에 넣어둔 조합 중 글자와, 삽입 직후의 기대 커서 위치
    var direct_pending:String = ""
    var direct_expected_loc:Int = -1

    override open func activateServer(_ sender: Any!) {
        super.activateServer(sender)

        PrintLog.shared.Log(log: "Server Activated")
        self.hangul = Hangul()
        self.hangul?.Start()
        self.direct_pending = ""
        self.direct_expected_loc = -1
    }

    override open func deactivateServer(_ sender: Any!) {
        PrintLog.shared.Log(log: "Server deactivating")

        // 세션을 정리(super)하기 전에 조합 중이던 글자를 이전 client로 먼저 확정한다.
        // super를 먼저 부르면 포커스가 새 앱으로 넘어간 뒤 commit돼, 그 글자가
        // 새 창(예: Raycast)으로 새어 "이전 입력기 것과 섞이는" 현상이 생길 수 있다.
        self.hangul?.Flush()
        self.update_display(client: sender)
        self.hangul?.Stop()
        self.direct_pending = ""
        self.direct_expected_loc = -1

        super.deactivateServer(sender)
    }
    
    // hangul이 없거나 automata가 nil이면 복구한다.
    // macOS가 activateServer 없이 handle을 호출하는 경우 대비.
    func ensureHangulReady() {
        if self.hangul == nil {
            self.hangul = Hangul()
        }
        if self.hangul?.automata == nil {
            self.hangul?.Start()
        }
    }

    override open func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        self.ensureHangulReady()

        // IMK가 event=nil로 호출하기도 한다. NSEvent!라 그대로 읽으면 트랩으로 입력기가 죽는다.
        guard let event = event else { return false }

        // 마우스 이벤트에서 keyCode를 읽으면 NSInternalInconsistencyException이 난다
        if event.type == .keyDown || event.type == .flagsChanged,
           OptHandler.shared.Is_han_eng_changed(keycode: event.keyCode, modi: event.modifierFlags) {
            self.hangul?.ToggleSuspend()
            self.commitComposition(sender)
            return true
        }

        switch event.type {
        case .keyDown:
            let eaten = self.keydown_event_handler(event: event, client: sender)
            if eaten == false {
                self.commitComposition(sender)
            }
            return eaten
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            self.commitComposition(sender)
        default:
            PrintLog.shared.Log(log: "unhandled event keycode=\(event.keyCode) modi=\(event.modifierFlags.rawValue)")
        }
        return false
    }
    
    func keydown_event_handler(event:NSEvent, client:Any!) -> Bool {
        guard let hangul = self.hangul else { return false }

        self.direct_sync_check(client: client)

        let keycode = event.keyCode
        let flag = event.modifierFlags

        // 특정 패턴 입력은 한글로 변환하지 않는다.
        // 단축키(cmd/option/control)와 함께 들어온 keycode는 hotfix 패턴에 섞으면 false-positive가 생기므로 제외.
        if !flag.contains(.command) && !flag.contains(.option) && !flag.contains(.control) {
            Hotfix.shared.add(keycode)
            if Hotfix.shared.check() {
                return false
            }
        }

        if flag.contains(.command)
            || flag.contains(.option)
            || flag.contains(.control) {
            PrintLog.shared.Log(log: "Modikey - \(keycode) with \(flag.rawValue)")
            return false
        }

        let enter_return:UInt16 = 0x24
        let tab:UInt16 = 0x30
        if keycode == enter_return || keycode == tab {
            PrintLog.shared.Log(log: "Enter or Tab")

            hangul.Flush()
            self.update_display(client: client)

            return false
        }

        let backspace:UInt16 = 0x33
        if keycode == backspace {
            PrintLog.shared.Log(log: "Backspace")

            // 커스텀 텍스트뷰는 insertText("")를 삭제로 처리한다는 보장이 없어 앱 백스페이스에 맡긴다
            if self.is_direct(client) && hangul.InputCount() == 1 {
                hangul.Discard()
                self.direct_pending = ""
                self.direct_expected_loc = -1
                return false
            }

            let remain = hangul.Backspace()
            if remain {
                self.update_display(client: client, backspace: true)
            }
            return remain
        }

        if keycode >= self.key_code.count {
            PrintLog.shared.Log(log: "Bypassd keycode: \(keycode) >= \(self.key_code.count)")

            hangul.Flush()
            self.update_display(client: client)

            return false
        }

        let ascii_idx = self.key_code.index(self.key_code.startIndex, offsetBy: Int(keycode))
        var ascii = self.key_code[ascii_idx]
        if flag.contains(.shift) {
            ascii = self.shift_key_code[ascii_idx]
        }

        let is_hangul:Bool = hangul.Process(ascii: String(ascii))
        if is_hangul == false {
            PrintLog.shared.Log(log: "Not Hangul: \(ascii)")

            hangul.Flush()
            self.update_display(client: client, backspace: false, additional: String(ascii))
        } else {
            self.update_display(client: client)
        }
        return true
    }
    
    func update_display(client:Any!, backspace:Bool = false, additional:String = "") {
        let commit_unicode:[unichar] = self.hangul?.takeCommit() ?? []
        let preedit_unicode:[unichar] = self.hangul?.takePreedit() ?? []
        
        // 출력할 내용이 전혀 없으면 IMKTextInput 호출을 건너뛴다.
        if commit_unicode.isEmpty && preedit_unicode.isEmpty && additional.isEmpty && backspace == false {
            return
        }
        
        var commited:String = ""
        if commit_unicode.isEmpty == false {
            commited = String(utf16CodeUnits:commit_unicode , count: commit_unicode.count)
        }
        
        var preediting:String = ""
        if preedit_unicode.isEmpty == false {
            preediting = String(utf16CodeUnits: preedit_unicode, count: preedit_unicode.count)
        }
        
        PrintLog.shared.Log(log: "C:'\(commited)' - \(commited.count) P:'\(preediting)' - \(preediting.count)")
        
        guard let disp = client as? IMKTextInput else {
            // 클라이언트 없이 호출되면 화면의 조합 글자는 그대로 확정된 것으로 본다
            self.direct_pending = ""
            self.direct_expected_loc = -1
            return
        }

        commited += additional

        // marked text를 쓰면 안 되는 앱은 직접 삽입 방식으로 처리
        if self.is_direct(disp) {
            self.direct_update(disp: disp, commited: commited, preediting: preediting)
            return
        }

        let build_count = 302
        if commited.isEmpty == false {
            disp.insertText(commited, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            
            PrintLog.shared.Log(log: "\(build_count) Commit: \(commited)")
        }
        
        // replacementRange 가 아래 코드와 같아야만 잘 동작한다.
        if (preediting.isEmpty == false) || (backspace == true) {
            // 백스페이스로 글자를 지울 때, preddition.count == 0 인 상태가 되는데
            // 이 때 명시적으로 length = 0 인 NSRange를 setMarkedText()에 주어야만 자연스럽게 처리된다.
            // NSRange.length는 UTF-16 단위. NFD로 분해된 한글은 grapheme count와 다르므로 NSString.length를 쓴다.
            let sr = NSRange(location: 0, length: (preediting as NSString).length)
            let rr = NSRange(location: NSNotFound, length: NSNotFound)
            PrintLog.shared.Log(log: "RR: \(rr) SR: \(sr) on \(String(describing: disp.bundleIdentifier()))")
            disp.setMarkedText(preediting, selectionRange: sr, replacementRange: rr)
            
            PrintLog.shared.Log(log: "\(build_count) Predit: \(preediting)")
        }
    }
    
    func direct_update(disp:IMKTextInput, commited:String, preediting:String) {
        let new_text = commited + preediting
        let old_pending = self.direct_pending

        if new_text.isEmpty && old_pending.isEmpty {
            return
        }
        // flush로 조합만 확정되고 화면 내용이 그대로면 클라이언트 호출 생략
        // (이미 실제 텍스트로 들어가 있으므로 상태만 정리하면 된다)
        // 주의: 이 비교는 commit 정규화 == preedit 정규화(normalization의 is_commit이
        // 현재 무시됨)에 의존한다. 둘을 다르게 만들면 이 조건이 깨진다.
        if preediting.isEmpty && new_text == old_pending {
            self.direct_pending = ""
            self.direct_expected_loc = -1
            return
        }

        let sel = disp.selectedRange()
        let old_len = old_pending.utf16.count
        var rr = NSRange(location: NSNotFound, length: 0)
        var base = sel.location

        if old_pending.isEmpty == false && sel.location != NSNotFound && sel.location >= old_len {
            // 직전에 넣어둔 조합 글자가 커서 앞에 그대로 있는지 확인하고 교체
            let check_range = NSRange(location: sel.location - old_len, length: old_len)
            let actual = disp.attributedSubstring(from: check_range)?.string
            if actual == old_pending {
                rr = check_range
                base = sel.location - old_len
            }
        }

        disp.insertText(new_text, replacementRange: rr)

        self.direct_pending = preediting
        if preediting.isEmpty || base == NSNotFound {
            self.direct_expected_loc = -1
        } else {
            self.direct_expected_loc = base + new_text.utf16.count
        }
        PrintLog.shared.Log(log: "direct: '\(new_text)' rr=\(rr) pending='\(self.direct_pending)' exp=\(self.direct_expected_loc)")
    }

    // 앱이 조합 글자를 포함해 전송했거나(텔레그램 엔터는 입력기에 오지 않는다) 커서가 옮겨졌으면 조합을 버린다
    func direct_sync_check(client:Any!) {
        guard self.direct_pending.isEmpty == false,
              let disp = client as? IMKTextInput,
              self.is_direct(disp) else {
            return
        }
        let pending_len = self.direct_pending.utf16.count
        let sel = disp.selectedRange()
        var stale = (sel.location == NSNotFound)
            || (sel.length != 0)    // 선택 영역이 있으면 조합을 버리고 네이티브처럼 선택을 대체
            || (sel.location != self.direct_expected_loc)
            || (sel.location < pending_len)
        if stale == false {
            let check_range = NSRange(location: sel.location - pending_len, length: pending_len)
            let actual = disp.attributedSubstring(from: check_range)?.string
            stale = (actual != self.direct_pending)
        }
        if stale {
            PrintLog.shared.Log(log: "direct: field changed externally, discard composition")
            self.hangul?.Discard()
            self.direct_pending = ""
            self.direct_expected_loc = -1
        }
    }

    /*
     입력 메서드가 이 메서드를 구현하면, 클라이언트가 컴포지션 세션을 즉시 종료하고자 할 때 호출됩니다.
     일반적인 응답은 클라이언트의 insertText 메서드를 호출한 다음 세션별 버퍼와 변수를 정리하는 것입니다.
     이 메시지를 받은 후 입력 방법은 주어진 컴포지션 세션이 완료된 것을 고려해야 합니다.
     */
    override open func commitComposition(_ sender: Any!) {
        PrintLog.shared.Log(log: "Commit Composition")
        self.direct_sync_check(client: sender)
        self.hangul?.Flush()
        self.update_display(client: sender)
    }
    
    /*
     클라이언트는 입력 메서드가 이벤트를 지원하는지 확인하기 위해 이 메서드를 호출합니다.
     기본 구현은 NSKeyDownMask를 반환합니다.
     입력 방법이 키 다운 이벤트만 처리하는 경우, 입력 방법 키트는 기본 마우스 처리를 제공합니다.
     기본 마우스다운 처리 동작은 다음과 같습니다:
       활성 컴포지션 영역이 있고 사용자가 텍스트를 클릭하지만 컴포지션 영역 외부에서 클릭하는 경우,
       입력 방법 키트는 입력 메서드에 commitComposition: 메시지를 보냅니다.
       이것은 기본값인 NSKeyDownMask만 반환하는 입력 메서드에서만 발생합니다.
     */
    override open func recognizedEvents(_ sender: Any!) -> Int {
        // drag는 frame마다 들어와 매번 commit이 호출되므로 제외.
        // appKitDefined/applicationDefined/systemDefined를 구독하면 문자 뷰어(⌃⌘Space)를
        // 닫은 뒤 setMarkedText가 무시돼 자모 조합만 먹통이 된다.
        return Int(NSEvent.EventTypeMask(arrayLiteral: .keyDown, .flagsChanged,
            .leftMouseUp, .rightMouseUp, .leftMouseDown, .rightMouseDown).rawValue)
    }
    
    /*
     마우스 버튼이 눌리면 현재 조합을 종료하고 커밋
     */
    override open func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint, withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!, client sender: Any!) -> Bool {
        PrintLog.shared.Log(log: "Mouse Down")
        
        self.commitComposition(sender)
        return false
    }
    
    
    /*
     이 메서드는 입력 메서드가 현재 상태를 반영하도록 메뉴를 업데이트할 수 있도록 메뉴를 그려야 할 때마다 호출됩니다.
     */
   override open func menu() -> NSMenu! {
        return HangulMenu.shared.menu
   }
    
    /*
     IMKit 프레임워크는 실제 NSMenu 객체가 어디에 있건간에 NSMenuItem.action은 무조건 InputController 내부에 있어야 한다.
     그리고 sender는 NSMenuItem이 아니다. <-- 졸라 중요.
     IMKit에서 생성한 Dictionary 타입 객체가 sender로 전달된다.
     거기서 NSMenuItem을 찾으려면 ["IMKCommandMenuItem"]으로 Dictionary에서 값을 가져와야 한다.
     인터넷 그 어디에도 공식적인 문서 자료가 없다. 내가 삽질해서 찾은 것임.
     */
    @objc func select_haneng_hotkey(_ sender:Any?) {
        self.hangul?.Flush()
        guard let dict = sender as? [String: Any],
              let item = dict["IMKCommandMenuItem"] as? NSMenuItem else {
            return
        }
        HangulMenu.shared.set_hotkey(tag: item.tag)
    }
}
