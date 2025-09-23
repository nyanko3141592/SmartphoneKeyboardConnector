import SwiftUI
import UIKit

enum FlickDirection: CaseIterable {
    case center
    case up
    case down
    case left
    case right
}

enum FlickAction: Equatable {
    case sendText(String)
    case enter
    case backspace
    case tab
    case space
    case transformSmall
    case applyDakuten
    case applyHandakuten
}

struct FlickEntry: Equatable {
    let label: String
    let action: FlickAction
}

struct FlickCommitMetadata {
    let model: FlickKeyModel
    let direction: FlickDirection
}

struct FlickKeyModel: Identifiable {
    enum KeyKind {
        case kana
        case functional
    }

    let id = UUID()
    let entries: [FlickDirection: FlickEntry]
    let smallEntries: [FlickDirection: FlickEntry]?
    let dakutenEntries: [FlickDirection: FlickEntry]?
    let handakutenEntries: [FlickDirection: FlickEntry]?
    let width: CGFloat
    let kind: KeyKind

    func entry(for direction: FlickDirection) -> FlickEntry? {
        entries[direction] ?? entries[.center]
    }

    func smallEntry(for direction: FlickDirection) -> FlickEntry? {
        smallEntries?[direction]
    }

    func dakutenEntry(for direction: FlickDirection) -> FlickEntry? {
        dakutenEntries?[direction]
    }

    func handakutenEntry(for direction: FlickDirection) -> FlickEntry? {
        handakutenEntries?[direction]
    }

    var availableDirections: Set<FlickDirection> {
        Set(entries.keys)
    }
}

struct FlickKeyboardLayout {
    let rows: [[FlickKeyModel]]
    let functionRow: [FlickKeyModel]

    static let standard: FlickKeyboardLayout = {
        let row1: [FlickKeyModel] = [
            .kana(
                base: [
                    .center: ("あ", "a"),
                    .up: ("い", "i"),
                    .right: ("う", "u"),
                    .down: ("え", "e"),
                    .left: ("お", "o")
                ],
                small: [
                    .center: ("ぁ", "xa"),
                    .up: ("ぃ", "xi"),
                    .right: ("ぅ", "xu"),
                    .down: ("ぇ", "xe"),
                    .left: ("ぉ", "xo")
                ],
                dakuten: [
                    .right: ("ゔ", "vu")
                ]
            ),
            .kana(
                base: [
                    .center: ("か", "ka"),
                    .up: ("き", "ki"),
                    .right: ("く", "ku"),
                    .down: ("け", "ke"),
                    .left: ("こ", "ko")
                ],
                dakuten: [
                    .center: ("が", "ga"),
                    .up: ("ぎ", "gi"),
                    .right: ("ぐ", "gu"),
                    .down: ("げ", "ge"),
                    .left: ("ご", "go")
                ]
            ),
            .kana(
                base: [
                    .center: ("さ", "sa"),
                    .up: ("し", "shi"),
                    .right: ("す", "su"),
                    .down: ("せ", "se"),
                    .left: ("そ", "so")
                ],
                dakuten: [
                    .center: ("ざ", "za"),
                    .up: ("じ", "ji"),
                    .right: ("ず", "zu"),
                    .down: ("ぜ", "ze"),
                    .left: ("ぞ", "zo")
                ]
            )
        ]

        let row2: [FlickKeyModel] = [
            .kana(
                base: [
                    .center: ("た", "ta"),
                    .up: ("ち", "chi"),
                    .right: ("つ", "tsu"),
                    .down: ("て", "te"),
                    .left: ("と", "to")
                ],
                small: [
                    .right: ("っ", "xtsu")
                ],
                dakuten: [
                    .center: ("だ", "da"),
                    .up: ("ぢ", "di"),
                    .right: ("づ", "du"),
                    .down: ("で", "de"),
                    .left: ("ど", "do")
                ]
            ),
            .kana(
                base: [
                    .center: ("な", "na"),
                    .up: ("に", "ni"),
                    .right: ("ぬ", "nu"),
                    .down: ("ね", "ne"),
                    .left: ("の", "no")
                ]
            ),
            .kana(
                base: [
                    .center: ("は", "ha"),
                    .up: ("ひ", "hi"),
                    .right: ("ふ", "fu"),
                    .down: ("へ", "he"),
                    .left: ("ほ", "ho")
                ],
                dakuten: [
                    .center: ("ば", "ba"),
                    .up: ("び", "bi"),
                    .right: ("ぶ", "bu"),
                    .down: ("べ", "be"),
                    .left: ("ぼ", "bo")
                ],
                handakuten: [
                    .center: ("ぱ", "pa"),
                    .up: ("ぴ", "pi"),
                    .right: ("ぷ", "pu"),
                    .down: ("ぺ", "pe"),
                    .left: ("ぽ", "po")
                ]
            )
        ]

        let row3: [FlickKeyModel] = [
            .kana(
                base: [
                    .center: ("ま", "ma"),
                    .up: ("み", "mi"),
                    .right: ("む", "mu"),
                    .down: ("め", "me"),
                    .left: ("も", "mo")
                ]
            ),
            .kana(
                base: [
                    .center: ("や", "ya"),
                    .up: ("ゆ", "yu"),
                    .right: ("よ", "yo"),
                    .left: ("ゃ", "lya")
                ],
                small: [
                    .center: ("ゃ", "lya"),
                    .up: ("ゅ", "lyu"),
                    .right: ("ょ", "lyo"),
                    .left: ("ゃ", "lya")
                ]
            ),
            .kana(
                base: [
                    .center: ("ら", "ra"),
                    .up: ("り", "ri"),
                    .right: ("る", "ru"),
                    .down: ("れ", "re"),
                    .left: ("ろ", "ro")
                ]
            )
        ]

        let row4: [FlickKeyModel] = [
            .functional(label: "小書", action: .transformSmall),
            .kana(
                base: [
                    .center: ("ん", "nn"),
                    .up: ("わ", "wa"),
                    .right: ("ー", "-"),
                    .down: ("〜", "~"),
                    .left: ("を", "wo")
                ],
                small: [
                    .up: ("ゎ", "xwa")
                ]
            ),
            .kana(
                base: [
                    .center: ("、", "、"),
                    .up: ("？", "?"),
                    .right: ("！", "!"),
                    .down: ("…", "…"),
                    .left: ("。", "。")
                ]
            )
        ]

        let functionRow: [FlickKeyModel] = [
            .functional(label: "Space", action: .space, width: 1.8),
            .functional(label: "Enter", action: .enter),
            .functional(label: "Backspace", action: .backspace),
            .functional(label: "゛", action: .applyDakuten),
            .functional(label: "゜", action: .applyHandakuten),
            .functional(label: "Tab", action: .tab)
        ]

        return FlickKeyboardLayout(rows: [row1, row2, row3, row4], functionRow: functionRow)
    }()
}

extension FlickKeyModel {
    private static func mapEntries(_ source: [FlickDirection: (String, String)]) -> [FlickDirection: FlickEntry] {
        var result: [FlickDirection: FlickEntry] = [:]
        for (direction, mapping) in source {
            result[direction] = FlickEntry(label: mapping.0, action: .sendText(mapping.1))
        }
        return result
    }

    static func kana(base: [FlickDirection: (String, String)],
                     small: [FlickDirection: (String, String)]? = nil,
                     dakuten: [FlickDirection: (String, String)]? = nil,
                     handakuten: [FlickDirection: (String, String)]? = nil,
                     width: CGFloat = 1.0) -> FlickKeyModel {
        let entries = mapEntries(base)
        let smallEntries = small.map { mapEntries($0) }
        let dakutenEntries = dakuten.map { mapEntries($0) }
        let handakutenEntries = handakuten.map { mapEntries($0) }

        return FlickKeyModel(
            entries: entries,
            smallEntries: smallEntries,
            dakutenEntries: dakutenEntries,
            handakutenEntries: handakutenEntries,
            width: width,
            kind: .kana
        )
    }

    static func functional(label: String, action: FlickAction, width: CGFloat = 1.0) -> FlickKeyModel {
        let entry = FlickEntry(label: label, action: action)
        return FlickKeyModel(
            entries: [.center: entry],
            smallEntries: nil,
            dakutenEntries: nil,
            handakutenEntries: nil,
            width: width,
            kind: .functional
        )
    }
}

struct FlickKeyboardView: View {
    let layout: FlickKeyboardLayout
    let isCompact: Bool
    var onCommit: (FlickEntry, FlickCommitMetadata?) -> Void

    init(layout: FlickKeyboardLayout = .standard,
         isCompact: Bool,
         onCommit: @escaping (FlickEntry, FlickCommitMetadata?) -> Void) {
        self.layout = layout
        self.isCompact = isCompact
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(spacing: isCompact ? 6 : 10) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                FlickKeyboardRow(
                    row: row,
                    isCompact: isCompact,
                    keyHeight: isCompact ? 56 : 62
                ) { entry, model, direction in
                    handleCommit(entry: entry, model: model, direction: direction)
                }
            }

            if !layout.functionRow.isEmpty {
                FlickKeyboardRow(
                    row: layout.functionRow,
                    isCompact: isCompact,
                    keyHeight: isCompact ? 48 : 52
                ) { entry, model, direction in
                    handleCommit(entry: entry, model: model, direction: direction)
                }
                .padding(.top, isCompact ? 4 : 6)
            }
        }
    }

    private func handleCommit(entry: FlickEntry, model: FlickKeyModel, direction: FlickDirection) {
        if model.kind == .kana {
            let metadata = FlickCommitMetadata(model: model, direction: direction)
            onCommit(entry, metadata)
        } else {
            onCommit(entry, nil)
        }
    }
}

private struct FlickKeyboardRow: View {
    let row: [FlickKeyModel]
    let isCompact: Bool
    let keyHeight: CGFloat
    var onCommit: (FlickEntry, FlickKeyModel, FlickDirection) -> Void

    private func totalUnits() -> CGFloat {
        row.reduce(0) { $0 + $1.width }
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = isCompact ? 6 : 8
            let availableWidth = geo.size.width - spacing * CGFloat(max(0, row.count - 1))
            let units = max(totalUnits(), 1)
            let unitWidth = max(0, availableWidth) / units

            HStack(spacing: spacing) {
                ForEach(row) { key in
                    FlickKeyButton(
                        model: key,
                        width: unitWidth * key.width,
                        height: keyHeight,
                        isCompact: isCompact
                    ) { entry, direction in
                        onCommit(entry, key, direction)
                    }
                }
            }
        }
        .frame(height: keyHeight)
    }
}

private struct FlickKeyButton: View {
    let model: FlickKeyModel
    let width: CGFloat
    let height: CGFloat
    let isCompact: Bool
    let onCommit: (FlickEntry, FlickDirection) -> Void

    @State private var activeDirection: FlickDirection = .center
    @State private var isPressing = false

    private var cornerRadius: CGFloat { isCompact ? 12 : 14 }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressing { isPressing = true }
                let direction = direction(for: value.translation)
                if model.availableDirections.contains(direction) {
                    activeDirection = direction
                } else {
                    activeDirection = .center
                }
            }
            .onEnded { value in
                let direction = direction(for: value.translation)
                let targetDirection = model.availableDirections.contains(direction) ? direction : .center
                if let entry = model.entry(for: targetDirection) {
                    onCommit(entry, targetDirection)
                }
                DispatchQueue.main.async {
                    isPressing = false
                    activeDirection = .center
                }
            }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: 1)

            if let entry = model.entry(for: activeDirection) {
                Text(entry.label)
                    .font(font)
                    .fontWeight(model.kind == .functional ? .semibold : .bold)
                    .foregroundStyle(.primary)
            }

            hintOverlay
        }
        .frame(width: width, height: height)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .gesture(dragGesture)
    }

    private var backgroundColor: Color {
        if isPressing {
            return Color.accentColor.opacity(0.3)
        }
        return model.kind == .functional ? Color(UIColor.systemGray5) : Color(UIColor.secondarySystemBackground)
    }

    private var borderColor: Color {
        isPressing ? Color.accentColor : Color.gray.opacity(0.25)
    }

    private var font: Font {
        if model.kind == .functional {
            return isCompact ? .system(size: 13, weight: .semibold) : .system(size: 16, weight: .semibold)
        }
        let baseSize: CGFloat = isCompact ? 26 : 28
        return .system(size: baseSize, weight: .semibold)
    }

    private var hintOverlay: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if let up = directionLabel(for: .up) {
                    Text(up)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(activeDirection == .up ? 0 : 1)
                        .position(x: size.width / 2, y: 10)
                }
                if let down = directionLabel(for: .down) {
                    Text(down)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(activeDirection == .down ? 0 : 1)
                        .position(x: size.width / 2, y: size.height - 10)
                }
                if let left = directionLabel(for: .left) {
                    Text(left)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(activeDirection == .left ? 0 : 1)
                        .position(x: 12, y: size.height / 2)
                }
                if let right = directionLabel(for: .right) {
                    Text(right)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(activeDirection == .right ? 0 : 1)
                        .position(x: size.width - 12, y: size.height / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func directionLabel(for direction: FlickDirection) -> String? {
        guard direction != .center else { return nil }
        guard model.availableDirections.contains(direction) else { return nil }
        return model.entry(for: direction)?.label
    }

    private func direction(for translation: CGSize) -> FlickDirection {
        let threshold: CGFloat = 24
        let dx = translation.width
        let dy = translation.height

        if abs(dx) < threshold && abs(dy) < threshold {
            return .center
        }
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .down : .up
        }
    }
}
