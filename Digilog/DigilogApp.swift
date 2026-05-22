import SwiftUI

private let rowCount = 10

enum Tab: String, CaseIterable, Identifiable {
    case today = "Today"
    case next = "Next"
    case someday = "Someday"
    var id: String { rawValue }
}

struct Row: Identifiable, Hashable {
    let id = UUID()
    var text: String = ""
    var done: Bool = false
}

@MainActor
final class Store: ObservableObject {
    @Published var today: [Row] = Array(repeating: Row(), count: rowCount)
    @Published var next: [Row] = Array(repeating: Row(), count: rowCount)
    @Published var someday: [Row] = Array(repeating: Row(), count: rowCount)

    private let dir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Digilog", isDirectory: true)
    }()

    private var todayKey: String = ""

    init() { reload() }

    func reload() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        todayKey = Self.logicalDateString()
        today = read(url(for: .today))
        next = read(url(for: .next))
        someday = read(url(for: .someday))
    }

    func rows(for tab: Tab) -> [Row] {
        switch tab {
        case .today: return today
        case .next: return next
        case .someday: return someday
        }
    }

    func update(_ tab: Tab, index: Int, row: Row) {
        switch tab {
        case .today: today[index] = row
        case .next: next[index] = row
        case .someday: someday[index] = row
        }
        write(rows(for: tab), to: url(for: tab))
    }

    private func url(for tab: Tab) -> URL {
        dir.appendingPathComponent(filename(for: tab))
    }

    private func filename(for tab: Tab) -> String {
        switch tab {
        case .today: return "\(todayKey).md"
        case .next: return "NEXT.md"
        case .someday: return "SOMEDAY.md"
        }
    }

    private func read(_ url: URL) -> [Row] {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var rows: [Row] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let row = parse(String(line)) {
                rows.append(row)
                if rows.count == rowCount { break }
            }
        }
        while rows.count < rowCount { rows.append(Row()) }
        return rows
    }

    private func parse(_ line: String) -> Row? {
        let s = line.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("- [") else { return nil }
        let chars = Array(s)
        guard chars.count >= 5, chars[2] == "[", chars[4] == "]" else { return nil }
        let mark = chars[3]
        let done: Bool
        switch mark {
        case " ": done = false
        case "x", "X": done = true
        default: return nil
        }
        let rest = String(chars[5...]).trimmingCharacters(in: .whitespaces)
        return Row(text: rest, done: done)
    }

    private func write(_ rows: [Row], to url: URL) {
        let lines = rows.map { row -> String in
            let mark = row.done ? "x" : " "
            return row.text.isEmpty ? "- [\(mark)]" : "- [\(mark)] \(row.text)"
        }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

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

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { i in
                    RowView(row: binding(i))
                        .overlay(alignment: .bottom) {
                            if i < rowCount - 1 {
                                Divider()
                            }
                        }
                }
            }
        }
        .padding(.vertical, 12)
        .onAppear { store.reload() }
    }

    private func binding(_ i: Int) -> Binding<Row> {
        Binding(
            get: { store.rows(for: tab)[i] },
            set: { store.update(tab, index: i, row: $0) }
        )
    }
}

struct CircleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.secondary, lineWidth: 1.25)
                    .frame(width: 14, height: 14)
                if configuration.isOn {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 9, height: 9)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct RowView: View {
    @Binding var row: Row
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $row.done)
                .toggleStyle(CircleToggleStyle())
                .labelsHidden()
            TextField("", text: $row.text)
                .textFieldStyle(.plain)
                .strikethrough(row.done, color: .secondary)
                .foregroundStyle(row.done ? .secondary : .primary)
                .focused($focused)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
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
