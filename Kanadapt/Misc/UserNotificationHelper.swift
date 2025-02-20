//
//  UserNotificationHelper.swift
//
//  Fluor
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Cocoa
import UserNotifications
import os

enum UserNotificationHelper {
    static var holdNextModeChangedNotification: Bool = false

    static func askUserAtLaunch() {
        guard !AppManager.default.hideNotificationAuthorizationPopup else { return }
        askOnStartupIfNeeded()
    }

    static func askUser(then action: @escaping (Bool) -> ()) {
        askIfNeeded(then: action)
    }

    static func sendModeChangedTo(_ mode: FKeyMode) {
        guard !holdNextModeChangedNotification else {
            holdNextModeChangedNotification.toggle()
            return
        }
        guard AppManager.default.userNotificationEnablement.contains(.appSwitch) else { return }
        let title = NSLocalizedString("F-Keys mode changed", comment: "")
        let message = mode.label
        sendNotification(withTitle: title, andMessage: message)
    }

    static func sendFKeyChangedAppBehaviorTo(_ behavior: AppBehavior, appName: String) {
        guard AppManager.default.userNotificationEnablement.contains(.appKey) else { return }
        let title = String(format: NSLocalizedString("F-Keys mode changed for %@", comment: ""), appName)
        let message = behavior.label
        sendNotification(withTitle: title, andMessage: message)
    }

    static func sendGlobalModeChangedTo(_ mode: FKeyMode) {
        guard AppManager.default.userNotificationEnablement.contains(.globalKey) else { return }
        let title = NSLocalizedString("Default mode changed", comment: "")
        let message = mode.label
        sendNotification(withTitle: title, andMessage: message)
    }

    private static func sendNotification(withTitle title: String, andMessage message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = message

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                os_log("Notification error: %@", error.localizedDescription)
            }
        }
    }

    static func ifAuthorized(perform action: @escaping () -> (), else unauthorizedAction: @escaping () -> ()) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                guard settings.authorizationStatus == .authorized else {
                    unauthorizedAction()
                    return
                }
                action()
            }
        }
    }

    private static func askOnStartupIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                // 既に許可済み、または拒否済みの場合はポップアップを表示しない
                guard settings.authorizationStatus != .denied, settings.authorizationStatus != .authorized else { return }
                
                let alert = makeAlert(suppressible: true)
                let avc = makeAccessoryView()
                alert.buttons.first?.bind(.enabled, to: avc, withKeyPath: "canEnableNotifications", options: nil)
                alert.accessoryView = avc.view

                NSApp.activate(ignoringOtherApps: true)
                let result = alert.runModal()

                if result == .alertFirstButtonReturn {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { isAuthorized, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                AppErrorManager.showError(withReason: error.localizedDescription)
                            }
                            AppManager.default.userNotificationEnablement = isAuthorized ? .from(avc) : .none
                        }
                    }
                } else {
                    AppManager.default.userNotificationEnablement = .none
                }
                AppManager.default.hideNotificationAuthorizationPopup = (alert.suppressionButton?.state == .on)
            }
        }
    }

    private static func askIfNeeded(then action: @escaping (Bool) -> ()) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    action(true)
                } else if settings.authorizationStatus == .denied {
                    if retryOnDenied() {
                        askIfNeeded(then: action)
                    } else {
                        action(false)
                    }
                } else {
                    let alert = makeAlert()
                    NSApp.activate(ignoringOtherApps: true)
                    let result = alert.runModal()
                    
                    guard result == .alertFirstButtonReturn else { return action(false) }
                    
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { isAuthorized, error in
                        DispatchQueue.main.async {
                            if let error = error, isAuthorized {
                                AppErrorManager.showError(withReason: error.localizedDescription)
                            }
                            action(isAuthorized)
                        }
                    }
                }
            }
        }
    }

    private static func retryOnDenied() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("Notifications are not allowed from Fluor", comment: "")
        alert.informativeText = NSLocalizedString("To allow notifications from Fluor follow these steps:", comment: "")
        alert.addButton(withTitle: NSLocalizedString("I allowed it", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("I won't allow it", comment: ""))

        let vc = NSStoryboard(name: .preferences, bundle: nil).instantiateController(withIdentifier: "DebugAuthorization") as? NSViewController
        alert.accessoryView = vc?.view

        NSApp.activate(ignoringOtherApps: true)
        let result = alert.runModal()
        return result == .alertFirstButtonReturn
    }

    private static func makeAlert(suppressible: Bool = false) -> NSAlert {
        let alert = NSAlert()
        alert.icon = NSImage(named: "QuestionMark")
        alert.messageText = NSLocalizedString("Enable notifications ?", comment: "")
        alert.informativeText = NSLocalizedString("Fluor can send notifications when the F-Keys mode changes.", comment: "")
        if suppressible {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = NSLocalizedString("Don't ask me on startup again", comment: "")
            alert.suppressionButton?.state = .off
        }
        alert.addButton(withTitle: NSLocalizedString("Enable notifications", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Don't enable notifications", comment: ""))
        return alert
    }

    private static func makeAccessoryView() -> UserNotificationEnablementViewController {
        let avc = UserNotificationEnablementViewController.instantiate()
        avc.isShownInAlert = true
        return avc
    }
}
