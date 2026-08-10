//
//  AppDelegate.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/3/22.
//

import Cocoa
import InputMethodKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var server = IMKServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("tried connection")

        // 오토마타 회귀 테스트. 전용 테스트 타깃이 없어서 Debug 빌드 실행 시 여기서 돌린다.
        // 기대값이 틀리면 test_debug()의 assert가 즉시 걸린다. (Release는 -O라 assert가 제거되고
        // 이 블록 자체도 컴파일되지 않으므로 사용자 빌드에는 영향 없다.)
#if DEBUG
        Test002().run()
#endif
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}
