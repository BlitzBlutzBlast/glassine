import AppKit
import Foundation

/// A look: the page and what lies behind it, kept together.
///
/// A theme sets the colours of the page and the glass; a backdrop puts folds
/// of colour behind the glass; frost, drift and grain tune the backdrop.
/// None of them reads right alone — a backdrop takes its lightness from the
/// theme, the theme's tint veils the backdrop — so the unit a person picks,
/// saves and shares is the pair with its tuning: a look. The built-in looks
/// pair built-in themes with the quiet sets; a look of the user's own is a
/// snapshot of whatever the page is wearing, under a name. Settings → Look.
struct Look: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var isBuiltIn: Bool = false
    var themeID: String
    var backdropID: String
    var drift: Bool = true
    var frost: Double = 0.2
    var grain: Double = 0.085

    /// Whether the page is wearing this look, to the eye: the same theme and
    /// backdrop, drifting or not the same way, frost and grain within a hair.
    func matches(themeID t: String, backdropID b: String, drift d: Bool, frost f: Double, grain g: Double) -> Bool {
        themeID == t && backdropID == b && drift == d && abs(frost - f) < 0.011 && abs(grain - g) < 0.0026
    }
}

extension Look {
    /// What the app comes with: Soft Sky, and six more in its spirit — one
    /// quiet set over the theme it was made for. Linen is the light one.
    static let softSky = Look(id: "softsky", name: "Soft Sky", isBuiltIn: true, themeID: "midnight", backdropID: BackdropPreset.softSkyID)
    static let slate = Look(id: "slate", name: "Slate", isBuiltIn: true, themeID: "graphite", backdropID: "slate")
    static let deepWater = Look(id: "deepwater", name: "Deep Water", isBuiltIn: true, themeID: "ocean", backdropID: "deepwater")
    static let pine = Look(id: "pine", name: "Pine", isBuiltIn: true, themeID: "moss", backdropID: "pine")
    static let plum = Look(id: "plum", name: "Plum", isBuiltIn: true, themeID: "dusk", backdropID: "plum")
    static let umber = Look(id: "umber", name: "Umber", isBuiltIn: true, themeID: "sepia-night", backdropID: "umber")
    static let linen = Look(id: "linen", name: "Linen", isBuiltIn: true, themeID: "paper", backdropID: "linen", frost: 0.35, grain: 0.06)
    /// The desktop through the glass, the way the first versions looked.
    static let desktop = Look(id: "desktop", name: "Desktop", isBuiltIn: true, themeID: "dusk", backdropID: BackdropPreset.desktopID, frost: 0.3, grain: 0.08)

    static let builtIns: [Look] = [softSky, slate, deepWater, pine, plum, umber, linen, desktop]

    /// A line about the look, for the tile's help.
    var blurb: String {
        switch id {
        case "softsky": return "Midnight over Soft Sky: a cool page on a deep violet-blue night. The look the app comes with."
        case "slate": return "Graphite over Slate: warm text and a copper accent on the quietest grey."
        case "deepwater": return "Ocean over Deep Water: blues and teals, deep."
        case "pine": return "Moss over Pine: green-black, with a lime accent."
        case "plum": return "Dusk over Plum: violet glass over violet folds, with a cyan accent."
        case "umber": return "Sepia Night over Umber: warm darks, a terracotta accent."
        case "linen": return "Paper over Linen: a light page on warm, pale folds."
        case "desktop": return "Dusk over the desktop: the wallpaper, blurred, behind the glass."
        default: return ""
        }
    }
}

/// The looks of the user's own, kept beside the custom themes and backdrops.
final class LookStore: ObservableObject {
    static let defaultsKey = "glassine.customLooks.v1"

    @Published var custom: [Look] {
        didSet {
            persist()
            let before = oldValue
            guard before != custom else { return }
            let byID = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let nowByID = Dictionary(custom.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let keys = Set(byID.keys).union(nowByID.keys).filter { byID[$0] != nowByID[$0] }
            SettingsUndo.shared.note(keys: Set(keys.map { "look." + $0 })) { [weak self] in self?.custom = before }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: LookStore.defaultsKey),
           let decoded = try? JSONDecoder().decode([Look].self, from: data) {
            custom = decoded
        } else {
            custom = []
        }
    }

    var all: [Look] { Look.builtIns + custom }

    func look(id: String) -> Look? { all.first { $0.id == id } }

    func add(_ look: Look) {
        var l = look
        l.isBuiltIn = false
        if all.contains(where: { $0.id == l.id }) { l.id = UUID().uuidString }
        custom.append(l)
    }

    func update(_ look: Look) {
        guard !look.isBuiltIn, let i = custom.firstIndex(where: { $0.id == look.id }) else { return }
        custom[i] = look
    }

    func delete(_ look: Look) {
        custom.removeAll { $0.id == look.id }
    }

    /// Looks whose theme or backdrop has gone (deleted from Mine) point at
    /// nothing; they go too.
    func prune(themes: ThemeStore, backdrops: BackdropStore) {
        let kept = custom.filter { l in
            themes.all.contains { $0.id == l.themeID } && backdrops.all.contains { $0.id == l.backdropID }
        }
        if kept.count != custom.count { custom = kept }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: LookStore.defaultsKey)
        }
    }
}

/// A look on disk — `.glassinelook` — carrying its theme and its backdrop
/// whole, so that a file sent to someone else brings everything the look
/// needs, whatever is on their Mac.
struct LookFile: Codable {
    var format = "glassine-look"
    var version = 1
    var look: Look
    var theme: Theme
    var backdrop: BackdropPreset

    static let fileExtension = "glassinelook"

    static func write(look: Look, theme: Theme, backdrop: BackdropPreset, to url: URL) throws {
        var l = look
        l.isBuiltIn = false
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(LookFile(look: l, theme: theme, backdrop: backdrop)).write(to: url)
    }

    static func read(from url: URL) throws -> LookFile {
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(LookFile.self, from: data)
        guard file.format == "glassine-look" else {
            throw NSError(domain: "Glassine", code: 1, userInfo: [NSLocalizedDescriptionKey: "That file isn't a Glassine look."])
        }
        return file
    }
}
