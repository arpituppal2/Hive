//
//  BrowserState+TaskManager.swift
//  Hive
//
//  Chrome ⇧⎋ Task Manager: live per-process memory/CPU straight from CEF's
//  process-wide task manager (real metrics — not estimates). The sheet polls
//  a refresh tick every two seconds; rows merge CEF task info with the tab
//  they back, so the user sees "Hacker News — Renderer" instead of an opaque
//  process id. "End process" issues CEF's KillTask — for a renderer, CEF
//  surfaces its own crashed-page surface, exactly like Chrome.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - TaskManagerRow

/// One row in the Task Manager: a CEF process task merged with the tab it
/// backs (when it backs one).
struct TaskManagerRow: Identifiable {
    let id: Int64
    let type: CefTaskType
    let isKillable: Bool
    let title: String
    let subtitle: String
    let memoryString: String
    let cpuString: String
    let faviconURL: URL?
    let tabID: String?
    let isActiveTab: Bool
    let isPrivateTab: Bool
}


// MARK: - BrowserState + TaskManager

@MainActor
extension BrowserState {

    func openTaskManager() { isTaskManagerOpen = true }
    func closeTaskManager() { isTaskManagerOpen = false }

    /// The current task snapshot: CEF's tasks in CEF's stable order, each
    /// annotated with the tab it backs. Tasks for hibernated tabs (closed
    /// browsers) and web-chrome surfaces simply lack a tab annotation.
    var taskManagerRows: [TaskManagerRow] {
        let manager = CefTaskManager.shared
        let rows = manager.taskIDs.compactMap { taskID -> TaskManagerRow? in
            guard let info = manager.taskInfo(for: taskID) else { return nil }

            // Find the tab backing this task. A renderer task's title is the
            // URL, so prefer the tab's own title/custom name when present.
            let tab = tabs.first { tab in
                guard let browser = tab.model.browser else { return false }
                return manager.taskID(forBrowser: browser.id) == taskID
            }

            let title: String
            let subtitle: String
            if let tab {
                title = tab.customTitle ?? tab.model.title
                subtitle = tab.model.url?.host ?? (tab.isHibernated ? tab.savedURL?.host ?? info.title : info.title)
            } else {
                title = info.title.isEmpty ? info.type.label : info.title
                subtitle = info.type.label
            }

            return TaskManagerRow(
                id: taskID,
                type: info.type,
                isKillable: info.isKillable,
                title: title.isEmpty ? info.type.label : title,
                subtitle: subtitle,
                memoryString: TaskMetricFormatter.memoryString(bytes: info.memoryBytes),
                cpuString: TaskMetricFormatter.cpuString(cpuUsage: info.cpuUsage),
                faviconURL: tab?.model.faviconURL,
                tabID: tab?.id,
                isActiveTab: tab?.id == activeTabID,
                isPrivateTab: tab?.isPrivate ?? false
            )
        }
        // Sort like Chrome: browser first, then GPU, then renderers by title.
        return rows.sorted { lhs, rhs in
            let lRank = typeRank(lhs.type)
            let rRank = typeRank(rhs.type)
            if lRank != rRank { return lRank < rRank }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    /// Chrome's "End process": kills the task through CEF. For a renderer
    /// task the tab stays put but its page shows a crashed state until the
    /// user reloads (the app has no auto-recovery handler — the toast and
    /// the sheet's confirmation say so rather than promising one). Browser
    /// and GPU processes are not killable and never reach here.
    func endTask(taskID: Int64) {
        let ok = CefTaskManager.shared.killTask(taskID)
        taskManagerRefreshTick += 1
        if ok {
            showAppNotice("Ended process — reload the tab to restore its page")
        } else {
            showAppNotice("Could not end that process")
        }
    }

    /// Ordering rank for Chrome-style task sorting: browser, GPU, then
    /// everything else (renderers first within their group).
    private func typeRank(_ type: CefTaskType) -> Int {
        switch type {
        case .browser: return 0
        case .gpu: return 1
        case .renderer, .extensionProcess, .guest: return 2
        case .zygote, .utility, .plugin, .sandboxHelper: return 3
        case .dedicatedWorker, .sharedWorker, .serviceWorker: return 4
        case .unknown: return 5
        }
    }
}
