import Foundation
import SwiftUI

struct KeySpec: Decodable {
    var a: Int?
    var w: Double?
}

struct KeyboardRow: Decodable {
    let items: [KeyboardItem]
}

enum KeyboardItem: Decodable {
    case keycap(String)
    case spec(KeySpec)

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer() {
            if let str = try? single.decode(String.self) {
                self = .keycap(str)
                return
            }
            if let spec = try? single.decode(KeySpec.self) {
                self = .spec(spec)
                return
            }
        }
        throw DecodingError.typeMismatch(KeyboardItem.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported item"))
    }
}

struct KeyModel: Identifiable {
    let id = UUID()
    let label: String
    let width: Double
}

struct ParsedKeyboardLayout {
    let rows: [[KeyModel]]
}

enum KeyboardLayoutLoader {
    static func loadFromBundle() -> ParsedKeyboardLayout? {
        guard let url = Bundle.main.url(forResource: "keyboard-layout", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try parse(data: data)
        } catch {
            print("Keyboard layout load error: \(error)")
            return nil
        }
    }

    static func parse(data: Data) throws -> ParsedKeyboardLayout {
        // The top-level is [[ item|string|spec ]]
        let raw = try JSONSerialization.jsonObject(with: data, options: [])
        guard let rows = raw as? [Any] else { throw NSError(domain: "layout", code: 1) }

        var parsedRows: [[KeyModel]] = []
        for row in rows {
            guard let items = row as? [Any] else { continue }
            var currentWidth: Double = 1.0
            var models: [KeyModel] = []
            for item in items {
                if let dict = item as? [String: Any] {
                    if let w = dict["w"] as? Double { currentWidth = w }
                    else if let wInt = dict["w"] as? Int { currentWidth = Double(wInt) }
                    // alignment 'a' ignored for now
                } else if let label = item as? String {
                    models.append(KeyModel(label: label, width: currentWidth))
                    currentWidth = 1.0 // one-shot width
                }
            }
            parsedRows.append(models)
        }
        return ParsedKeyboardLayout(rows: parsedRows)
    }
}

struct KeyButton: View {
    let model: KeyModel
    let unitWidth: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Full rectangular hit area
                Rectangle()
                    .fill(Color(UIColor.secondarySystemBackground))
                Rectangle()
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                VStack(spacing: 2) {
                    let parts = model.label.components(separatedBy: "\n")
                    if parts.count > 1 {
                        Text(parts[0]).font(.footnote)
                        Text(parts.last ?? "").font(.subheadline)
                    } else {
                        Text(model.label).font(.subheadline)
                    }
                }
                .foregroundColor(.primary)
                .padding(4)
            }
        }
        .buttonStyle(.plain)
        .frame(width: unitWidth * model.width, height: height)
    }
}

