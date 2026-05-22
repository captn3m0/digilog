import SwiftUI

private let rowCount = 10
private let maxRowLength = 35

enum Tab: String, CaseIterable, Identifiable {
    case today = "Today"
    case next = "Next"
    case someday = "Someday"
    var id: String { rawValue }
}

struct Row: Hashable {
    var text: String = ""
    var done: Bool = false
}

@MainActor
final class Store: ObservableObject {
    // Visible top-10 rows per tab. @Published on the dict re-renders the UI
    // whenever any tab's rows change.
    @Published private var lists: [Tab: [Row]] = [:]

    // Rows beyond the first 10 on disk. Hidden from the UI but written back
    // verbatim, so manually-edited files keep their overflow and `clean()`
    // can park kept items below the fresh 10.
    private var tails: [Tab: [Row]] = [:]

    private var todayKey = ""

    private let dir: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Digilog", isDirectory: true)

    init() { reload() }

    func reload() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Logical date = wall-clock − 4h. Recomputed on every reload (no timers),
        // so the "Today" file flips to a new name at 04:00 local time.
        todayKey = Self.logicalDateString()
        for tab in Tab.allCases {
            let (top, tail) = read(url(for: tab))
            lists[tab] = top
            tails[tab] = tail
        }
    }

    func rows(for tab: Tab) -> [Row] { lists[tab] ?? Self.blanks }

    func update(_ tab: Tab, index: Int, row: Row) {
        lists[tab]?[index] = row
        write(tab)
    }

    /// Wipe the visible 10 rows but preserve any non-empty ones in the tail,
    /// so the file becomes `[10 blanks] + [kept] + [prior tail]`.
    func clean(_ tab: Tab) {
        let kept = (lists[tab] ?? []).filter { !$0.text.isEmpty }
        tails[tab] = kept + (tails[tab] ?? [])
        lists[tab] = Self.blanks
        write(tab)
    }

    // MARK: - File I/O

    private func url(for tab: Tab) -> URL {
        let name: String
        switch tab {
        case .today: name = "\(todayKey).md"
        case .next: name = "NEXT.md"
        case .someday: name = "SOMEDAY.md"
        }
        return dir.appendingPathComponent(name)
    }

    private func read(_ url: URL) -> (top: [Row], tail: [Row]) {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let parsed = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { Self.parse(String($0)) }

        if parsed.count >= rowCount {
            return (Array(parsed.prefix(rowCount)), Array(parsed.dropFirst(rowCount)))
        }
        // Short file: pad to 10 rows so the UI always has 10 to bind to.
        return (parsed + Array(repeating: Row(), count: rowCount - parsed.count), [])
    }

    private func write(_ tab: Tab) {
        let lines = ((lists[tab] ?? []) + (tails[tab] ?? [])).map { row in
            let mark = row.done ? "x" : " "
            return row.text.isEmpty ? "- [\(mark)]" : "- [\(mark)] \(row.text)"
        }
        try? (lines.joined(separator: "\n") + "\n")
            .write(to: url(for: tab), atomically: true, encoding: .utf8)
    }

    /// Parses a single GFM checkbox line. Returns nil for anything else, which
    /// is how non-checkbox lines get silently skipped.
    private static func parse(_ line: String) -> Row? {
        let s = line.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("- [") else { return nil }
        let chars = Array(s)
        guard chars.count >= 5, chars[4] == "]" else { return nil }
        let done: Bool
        switch chars[3] {
        case " ": done = false
        case "x", "X": done = true
        default: return nil
        }
        let rest = String(chars[5...]).trimmingCharacters(in: .whitespaces)
        return Row(text: rest, done: done)
    }

    private static var blanks: [Row] { Array(repeating: Row(), count: rowCount) }

    private static func logicalDateString(_ now: Date = Date()) -> String {
        let shifted = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: shifted)
    }
}

struct ContentView: View {
    @StateObject private var store = Store()
    @State private var tab: Tab = .today
    @FocusState private var focusedRow: Int?

    var body: some View {
        VStack(spacing: 0) {
            TabBar(tab: $tab, onClean: store.clean)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { i in
                    RowView(
                        row: binding(i),
                        isFocused: $focusedRow,
                        index: i,
                        onSubmit: { focusedRow = i + 1 < rowCount ? i + 1 : nil }
                    )
                    .overlay(alignment: .bottom) {
                        if i < rowCount - 1 { Divider() }
                    }
                }
            }

            FooterView()
        }
        .padding(.top, 12)
        .background(ArrowKeyHandler { direction in
            guard let i = focusedRow else { return false }
            switch direction {
            case .up where i > 0: focusedRow = i - 1; return true
            case .down where i < rowCount - 1: focusedRow = i + 1; return true
            default: return false
            }
        })
        .onAppear { store.reload() }
    }

    private func binding(_ i: Int) -> Binding<Row> {
        Binding(
            get: { store.rows(for: tab)[i] },
            // Clamp in `set` so the TextField never displays a 36th character —
            // SwiftUI re-reads via `get` after every `set`, so a clamped write
            // visibly rejects the keystroke.
            set: { newRow in
                var r = newRow
                r.text = String(r.text.prefix(maxRowLength))
                store.update(tab, index: i, row: r)
            }
        )
    }
}

/// Catches ↑/↓ before they reach the focused TextField (which would otherwise
/// move the caret). Returning true from `onArrow` swallows the key event.
struct ArrowKeyHandler: NSViewRepresentable {
    enum Direction { case up, down }
    let onArrow: (Direction) -> Bool

    func makeNSView(context: Context) -> NSView { KeyView(onArrow: onArrow) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class KeyView: NSView {
        let onArrow: (Direction) -> Bool
        init(onArrow: @escaping (Direction) -> Bool) {
            self.onArrow = onArrow
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        // performKeyEquivalent fires before the focused responder sees the key,
        // so we can intercept arrows even while a TextField is first responder.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard event.type == .keyDown else { return false }
            switch event.keyCode {
            case 126: return onArrow(.up)
            case 125: return onArrow(.down)
            default: return false
            }
        }
    }
}

struct TabBar: View {
    @Binding var tab: Tab
    let onClean: (Tab) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                let selected = t == tab
                // Button fires on press for instant tab switching;
                // simultaneousGesture watches for a double-click without
                // gating the single-click (which a chained .onTapGesture would).
                Button { tab = t } label: {
                    Text(t.rawValue)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selected ? Color.secondary.opacity(0.18) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        tab = t
                        if t != .today { onClean(t) }
                    }
                )
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
    }
}

struct CircleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            ZStack {
                Circle().strokeBorder(Color.secondary, lineWidth: 1.25)
                if configuration.isOn {
                    Circle().fill(Color.primary).padding(2.5)
                }
            }
            .frame(width: 14, height: 14)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct RowView: View {
    @Binding var row: Row
    var isFocused: FocusState<Int?>.Binding
    let index: Int
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $row.done)
                .toggleStyle(CircleToggleStyle())
                .labelsHidden()
            TextField("", text: $row.text)
                .textFieldStyle(.plain)
                .strikethrough(row.done, color: .secondary)
                .foregroundStyle(row.done ? .secondary : .primary)
                .focused(isFocused, equals: index)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Rectangle hit-area + onTapGesture means clicking anywhere in the row
        // (padding, divider, left of the checkbox) focuses the text field.
        .contentShape(Rectangle())
        .onTapGesture { isFocused.wrappedValue = index }
    }
}

struct FooterView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        HStack {
            Button("Help") {
                if let url = URL(string: "https://captnemo.in/digilog/") {
                    NSWorkspace.shared.open(url)
                }
            }
            Spacer()
            Text("Digilog v\(version)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

@main
struct DigilogApp: App {
    var body: some Scene {
        MenuBarExtra("Digilog", systemImage: "checklist") {
            ContentView().frame(width: 250, height: 420)
        }
        .menuBarExtraStyle(.window)
    }
}
