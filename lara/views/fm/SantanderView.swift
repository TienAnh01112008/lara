//
//  SantanderView.swift
//  symlin2k
//
//  Created by ruter on 15.02.26.
//

import SwiftUI
import Combine

// MARK: - Navigation Manager
//
// DirectoryView.swift của Lara sử dụng:
//
// @EnvironmentObject private var nav: santandernav
//
// Mỗi tab sẽ có một santandernav riêng.

final class santandernav: ObservableObject {

    @Published var root: santanderitem
    @Published var stack: [santanderitem] = []

    init(root: santanderitem) {
        self.root = root
    }

    /// Chuyển navigation tới item mới.
    func go(_ item: santanderitem) {
        root = item
        stack.removeAll()
    }
}

// MARK: - Tab Model
//
// Một santandertab chứa toàn bộ state của một tab.
//
// Tab 1:
//     root  -> thư mục hiện tại
//     stack -> navigation history
//     nav   -> EnvironmentObject cho DirectoryView
//
// Tab 2 có state hoàn toàn riêng.

final class santandertab: ObservableObject, Identifiable {

    let id = UUID()

    @Published var root: santanderitem

    @Published var stack: [santanderitem] = []

    /// Navigation object được DirectoryView.swift sử dụng.
    let nav: santandernav

    private var cancellables = Set<AnyCancellable>()

    /// Ngăn vòng lặp khi đồng bộ hai chiều.
    private var syncingFromNav = false
    private var syncingFromTab = false

    init(root: santanderitem) {

        self.root = root
        self.nav = santandernav(root: root)

        setupSynchronization()
    }

    // MARK: Synchronization

    private func setupSynchronization() {

        // ------------------------------------------------------------
        // nav.root -> tab.root
        // ------------------------------------------------------------

        nav.$root
            .receive(on: RunLoop.main)
            .sink { [weak self] newRoot in

                guard let self else {
                    return
                }

                guard !self.syncingFromTab else {
                    return
                }

                self.syncingFromNav = true

                if self.root != newRoot {
                    self.root = newRoot
                }

                self.syncingFromNav = false
            }
            .store(in: &cancellables)

        // ------------------------------------------------------------
        // nav.stack -> tab.stack
        // ------------------------------------------------------------

        nav.$stack
            .receive(on: RunLoop.main)
            .sink { [weak self] newStack in

                guard let self else {
                    return
                }

                guard !self.syncingFromTab else {
                    return
                }

                self.syncingFromNav = true

                if self.stack != newStack {
                    self.stack = newStack
                }

                self.syncingFromNav = false
            }
            .store(in: &cancellables)

        // ------------------------------------------------------------
        // tab.root -> nav.root
        // ------------------------------------------------------------

        $root
            .receive(on: RunLoop.main)
            .sink { [weak self] newRoot in

                guard let self else {
                    return
                }

                guard !self.syncingFromNav else {
                    return
                }

                self.syncingFromTab = true

                if self.nav.root != newRoot {
                    self.nav.root = newRoot
                }

                self.syncingFromTab = false
            }
            .store(in: &cancellables)

        // ------------------------------------------------------------
        // tab.stack -> nav.stack
        // ------------------------------------------------------------

        $stack
            .receive(on: RunLoop.main)
            .sink { [weak self] newStack in

                guard let self else {
                    return
                }

                guard !self.syncingFromNav else {
                    return
                }

                self.syncingFromTab = true

                if self.nav.stack != newStack {
                    self.nav.stack = newStack
                }

                self.syncingFromTab = false
            }
            .store(in: &cancellables)
    }

    // MARK: Go

    func go(_ item: santanderitem) {

        root = item
        stack.removeAll()

        nav.root = item
        nav.stack.removeAll()
    }
}

// MARK: - Tab Manager

final class santandertabmanager: ObservableObject {

    @Published var tabs: [santandertab] = []

    @Published var selectedindex: Int = 0

    init(defaultPath: String = "/") {

        let path =
            defaultPath.isEmpty
            ? "/"
            : defaultPath

        let initialTab = santandertab(
            root: santanderitem(
                path: path,
                isdir: true
            )
        )

        tabs = [initialTab]
    }

    // MARK: Current Tab

    var currenttab: santandertab? {

        guard !tabs.isEmpty else {
            return nil
        }

        guard tabs.indices.contains(selectedindex) else {
            return tabs.first
        }

        return tabs[selectedindex]
    }

    // MARK: Select Tab

    func selecttab(_ index: Int) {

        guard tabs.indices.contains(index) else {
            return
        }

        selectedindex = index
    }

    // MARK: Add Tab

    func addtab(path: String? = nil) {

        let newPath: String

        if let path, !path.isEmpty {

            newPath = path

        } else {

            newPath =
                currenttab?.root.path
                ?? "/"
        }

        let newTab = santandertab(
            root: santanderitem(
                path: newPath,
                isdir: true
            )
        )

        tabs.append(newTab)

        selectedindex = tabs.count - 1
    }

    // MARK: Close Tab

    func closetab(at index: Int) {

        guard tabs.count > 1 else {
            return
        }

        guard tabs.indices.contains(index) else {
            return
        }

        let wasSelected =
            selectedindex == index

        tabs.remove(at: index)

        // Nếu xóa tab phía trước tab hiện tại,
        // index hiện tại phải giảm.
        if selectedindex > index {

            selectedindex -= 1
        }

        // Nếu xóa đúng tab đang chọn.
        else if wasSelected {

            if selectedindex >= tabs.count {
                selectedindex =
                    tabs.count - 1
            }
        }

        // Safety
        if selectedindex < 0 {
            selectedindex = 0
        }

        if selectedindex >= tabs.count {
            selectedindex =
                tabs.count - 1
        }
    }
}

// MARK: - Main Entry Point

struct SantanderView: View {

    let startpath: String

    @AppStorage("selectedmethod")
    private var selectedmethod: method = .hybrid

    @ObservedObject
    private var mgr = laramgr.shared

    init(startPath: String = "/") {

        self.startpath =
            startPath.isEmpty
            ? "/"
            : startPath
    }

    // MARK: Access Mode

    private var readsbx: Bool {

        selectedmethod != .vfs
    }

    private var writevfs: Bool {

        selectedmethod != .sbx
    }

    // MARK: Ready State

    private var ready: Bool {

        switch selectedmethod {

        case .sbx:
            return mgr.sbxready

        case .vfs:
            return mgr.vfsready

        case .hybrid:
            return mgr.sbxready &&
                   mgr.vfsready
        }
    }

    var body: some View {

        Group {

            if ready {

                santanderrootmultitab(
                    startpath: startpath,
                    readsbx: readsbx,
                    writevfs: writevfs
                )

            } else {

                NavigationStack {

                    VStack(spacing: 12) {

                        Image(
                            systemName:
                                "externaldrive.trianglebadge.exclamationmark"
                        )
                        .imageScale(.large)

                        Text(
                            "File Manager Not Ready!"
                        )
                        .font(.headline)

                        Text(
                            "Go back to the homepage, click Run Exploit, and then click Initalize System."
                        )
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Multi Tab Container

private struct santanderrootmultitab: View {

    let readsbx: Bool
    let writevfs: Bool

    @StateObject
    private var tabmgr: santandertabmanager

    init(
        startpath: String,
        readsbx: Bool,
        writevfs: Bool
    ) {

        self.readsbx = readsbx
        self.writevfs = writevfs

        _tabmgr = StateObject(
            wrappedValue:
                santandertabmanager(
                    defaultPath: startpath
                )
        )
    }

    var body: some View {

        VStack(spacing: 0) {

            // ============================================================
            // CURRENT TAB
            // ============================================================

            if let currentTab =
                tabmgr.currenttab {

                santandertabview(
                    tab: currentTab,
                    readsbx: readsbx,
                    writevfs: writevfs
                )
                .id(currentTab.id)

            } else {

                VStack(spacing: 12) {

                    Image(
                        systemName: "folder"
                    )
                    .font(.largeTitle)

                    Text("No Tabs")
                        .font(.headline)

                    Button("Create Tab") {

                        tabmgr.addtab()
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }

            // ============================================================
            // TAB BAR
            // ============================================================

            Divider()

            santandertabbar(
                tabmgr: tabmgr
            )
        }
    }
}

// MARK: - Tab Bar

private struct santandertabbar: View {

    @ObservedObject
    var tabmgr: santandertabmanager

    var body: some View {

        HStack(spacing: 6) {

            // ------------------------------------------------------------
            // Tabs
            // ------------------------------------------------------------

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {

                HStack(spacing: 6) {

                    ForEach(
                        Array(
                            tabmgr.tabs.enumerated()
                        ),
                        id: \.element.id
                    ) { index, tab in

                        santandertabbutton(
                            tab: tab,
                            selected:
                                index ==
                                tabmgr.selectedindex,
                            canClose:
                                tabmgr.tabs.count > 1,
                            onSelect: {

                                tabmgr.selecttab(
                                    index
                                )
                            },
                            onClose: {

                                tabmgr.closetab(
                                    at: index
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            // ------------------------------------------------------------
            // New Tab
            // ------------------------------------------------------------

            Button {

                let currentPath =
                    tabmgr.currenttab?
                        .root.path
                    ?? "/"

                tabmgr.addtab(
                    path: currentPath
                )

            } label: {

                Image(
                    systemName: "plus"
                )
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .frame(
                    width: 34,
                    height: 34
                )
                .background(
                    Color.secondary
                        .opacity(0.12)
                )
                .clipShape(
                    Circle()
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 50)
        .background(.bar)
    }
}

// MARK: - Individual Tab Button

private struct santandertabbutton: View {

    @ObservedObject
    var tab: santandertab

    let selected: Bool
    let canClose: Bool

    let onSelect: () -> Void
    let onClose: () -> Void

    private var title: String {

        let name =
            tab.root.name

        return name.isEmpty
            ? "/"
            : name
    }

    var body: some View {

        HStack(spacing: 5) {

            // ------------------------------------------------------------
            // Select
            // ------------------------------------------------------------

            Button {

                onSelect()

            } label: {

                HStack(spacing: 5) {

                    Image(
                        systemName:
                            selected
                            ? "folder.fill"
                            : "folder"
                    )
                    .font(.caption)

                    Text(title)
                        .font(
                            .subheadline.weight(
                                selected
                                ? .semibold
                                : .regular
                            )
                        )
                        .lineLimit(1)
                        .truncationMode(
                            .middle
                        )
                }
            }
            .buttonStyle(.plain)

            // ------------------------------------------------------------
            // Close
            // ------------------------------------------------------------

            if canClose {

                Button {

                    onClose()

                } label: {

                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            selected
            ? Color.accentColor
                .opacity(0.15)
            : Color.secondary
                .opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 9,
                style: .continuous
            )
        )
    }
}

// MARK: - Individual Tab Navigation

private struct santandertabview: View {

    @ObservedObject
    var tab: santandertab

    let readsbx: Bool
    let writevfs: Bool

    var body: some View {

        NavigationStack(
            path: $tab.stack
        ) {

            santanderdirview(
                item: tab.root,
                readsbx: readsbx,
                writevfs: writevfs
            )
            .environmentObject(
                tab.nav
            )
            .navigationDestination(
                for:
                    santanderitem.self
            ) { item in

                if item.isdir {

                    santanderdirview(
                        item: item,
                        readsbx: readsbx,
                        writevfs: writevfs
                    )
                    .environmentObject(
                        tab.nav
                    )

                } else {

                    santanderfileview(
                        item: item,
                        readsbx: readsbx,
                        writevfs: writevfs
                    )
                }
            }
        }
    }
}

// MARK: - UIKit Helper
//
// Giữ lại extension của SantanderView.swift gốc.

extension UIViewController {

    func topMostViewController()
        -> UIViewController {

        if let presented =
            presentedViewController {

            return presented
                .topMostViewController()
        }

        if let navigationController =
            self as? UINavigationController {

            return navigationController
                .visibleViewController?
                .topMostViewController()
                ?? navigationController
        }

        if let tabBarController =
            self as? UITabBarController {

            return tabBarController
                .selectedViewController?
                .topMostViewController()
                ?? tabBarController
        }

        for child in
            children.reversed() {

            if child.viewIfLoaded?
                .window != nil {

                return child
                    .topMostViewController()
            }
        }

        return self
    }
}
