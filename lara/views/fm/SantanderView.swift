
//
//  SantanderView.swift
//  symlin2k
//
//  Multi-tab File Manager UI
//

import SwiftUI
import Combine

// MARK: - Tab Model

final class santandertab: ObservableObject, Identifiable {

    let id = UUID()

    /// Thư mục gốc hiện tại của tab
    @Published var root: santanderitem

    /// Navigation stack riêng của tab
    @Published var stack: [santanderitem] = []

    init(root: santanderitem) {
        self.root = root
    }

    /// Reset tab về một thư mục mới
    func go(_ item: santanderitem) {
        root = item
        stack.removeAll()
    }
}

// MARK: - Tab Manager

final class santandertabmanager: ObservableObject {

    @Published var tabs: [santandertab] = []

    /// Index của tab đang được chọn
    @Published var selectedindex: Int = 0

    init(defaultPath: String = "/") {
        let path = defaultPath.isEmpty ? "/" : defaultPath

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

    // MARK: Add Tab

    func addtab(path: String? = nil) {

        let newPath: String

        if let path, !path.isEmpty {
            newPath = path
        } else {
            newPath = currenttab?.root.path ?? "/"
        }

        let newTab = santandertab(
            root: santanderitem(
                path: newPath,
                isdir: true
            )
        )

        tabs.append(newTab)

        // Tự động chuyển sang tab mới
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

        let wasSelected = selectedindex == index

        tabs.remove(at: index)

        // Nếu đóng tab đứng trước tab hiện tại,
        // index hiện tại phải giảm xuống.
        if selectedindex > index {
            selectedindex -= 1
        }
        // Nếu đóng tab cuối cùng đang được chọn,
        // chuyển sang tab cuối còn lại.
        else if wasSelected && selectedindex >= tabs.count {
            selectedindex = tabs.count - 1
        }

        // Safety
        if selectedindex < 0 {
            selectedindex = 0
        }

        if selectedindex >= tabs.count {
            selectedindex = max(0, tabs.count - 1)
        }
    }

    // MARK: Rename/Update Tab Position

    func selecttab(_ index: Int) {

        guard tabs.indices.contains(index) else {
            return
        }

        selectedindex = index
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
        self.startpath = startPath.isEmpty ? "/" : startPath
    }

    // MARK: Access Mode

    private var readsbx: Bool {
        selectedmethod != .vfs
    }

    private var writevfs: Bool {
        selectedmethod != .sbx
    }

    // MARK: Exploit Ready

    private var ready: Bool {

        switch selectedmethod {

        case .sbx:
            return mgr.sbxready

        case .vfs:
            return mgr.vfsready

        case .hybrid:
            return mgr.sbxready && mgr.vfsready
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

                        Text("File Manager Not Ready!")
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
            // CURRENT TAB CONTENT
            // ============================================================

            Group {

                if let currentTab = tabmgr.currenttab {

                    santandertabview(
                        tab: currentTab,
                        readsbx: readsbx,
                        writevfs: writevfs
                    )
                    .id(currentTab.id)

                } else {

                    ContentUnavailableView(
                        "No Tabs",
                        systemImage: "folder",
                        description:
                            Text("Open a new tab to continue.")
                    )
                }
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

            // ============================================================
            // TABS
            // ============================================================

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {

                HStack(spacing: 6) {

                    ForEach(
                        Array(tabmgr.tabs.enumerated()),
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
                                tabmgr.selecttab(index)
                            },

                            onClose: {
                                tabmgr.closetab(at: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            // ============================================================
            // NEW TAB
            // ============================================================

            Button {

                tabmgr.addtab()

            } label: {

                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(
                        width: 34,
                        height: 34
                    )
                    .background(
                        Color.secondary.opacity(0.12)
                    )
                    .clipShape(Circle())
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

        let name = tab.root.name

        if name.isEmpty {
            return "/"
        }

        return name
    }

    var body: some View {

        HStack(spacing: 5) {

            // Folder icon

            Image(
                systemName:
                    selected
                    ? "folder.fill"
                    : "folder"
            )
            .font(.caption)

            // Tab title

            Button {

                onSelect()

            } label: {

                Text(title)
                    .font(
                        .subheadline.weight(
                            selected
                            ? .semibold
                            : .regular
                        )
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.plain)

            // Close

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
            ? Color.accentColor.opacity(0.15)
            : Color.secondary.opacity(0.08)
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
            .navigationDestination(
                for: santanderitem.self
            ) { item in

                if item.isdir {

                    santanderdirview(
                        item: item,
                        readsbx: readsbx,
                        writevfs: writevfs
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

