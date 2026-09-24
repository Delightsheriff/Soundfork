import Foundation

/// Development flags, e.g. `open build/Soundfork.app --args --open`.
///   --open                   show the island right after launch
///   --snapshot <file.png>    render the open island to an image and quit
///   --page settings|welcome  which page the snapshot shows
///   --expand <bundle ID>     unfold that app's device picker in the snapshot
struct LaunchOptions {
    let openIsland: Bool
    let snapshotPath: String?
    let snapshotPage: IslandModel.Page?
    let expandedPicker: String?

    init(arguments: [String] = CommandLine.arguments) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        openIsland = arguments.contains("--open")
        snapshotPath = value(after: "--snapshot")
        snapshotPage = switch value(after: "--page") {
        case "settings": .settings
        case "welcome": .welcome
        default: nil
        }
        expandedPicker = value(after: "--expand")
    }
}
