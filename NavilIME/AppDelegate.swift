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

        // 전용 테스트 타깃이 없어 오토마타 회귀 테스트를 Debug 실행 시 여기서 돌린다
#if DEBUG
        Test002().run()
#endif
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}
