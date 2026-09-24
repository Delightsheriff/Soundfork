import Testing
@testable import AudioRouterCore

@Test func helpersBelongToTheirApp() {
    #expect(AudioApps.owner(ofProcess: "com.google.Chrome.helper") == "com.google.Chrome")
    #expect(AudioApps.owner(ofProcess: "com.hnc.Discord.helper.Renderer") == "com.hnc.Discord")
    #expect(AudioApps.owner(ofProcess: "com.apple.WebKit.GPU") == "com.apple.Safari")
    #expect(AudioApps.owner(ofProcess: "com.spotify.client") == "com.spotify.client")
    #expect(AudioApps.owner(ofProcess: "") == nil)
}

@Test func groupingMergesHelpersAndPlayingState() {
    let processes = [
        AudioProcess(objectID: 1, pid: 1, bundleID: "com.google.Chrome.helper", isRunningOutput: false),
        AudioProcess(objectID: 2, pid: 2, bundleID: "com.google.Chrome.helper", isRunningOutput: true),
        AudioProcess(objectID: 3, pid: 3, bundleID: "com.spotify.client", isRunningOutput: false),
        AudioProcess(objectID: 4, pid: 4, bundleID: "dev.local.AudioRouter", isRunningOutput: true),
    ]
    let apps = AudioApps.group(processes, excludingPrefix: "dev.local.AudioRouter")
    #expect(apps == [
        AudioApp(bundleID: "com.google.Chrome", tapBundleIDs: ["com.google.Chrome", "com.google.Chrome.helper"], isPlaying: true),
        AudioApp(bundleID: "com.spotify.client", tapBundleIDs: ["com.spotify.client"], isPlaying: false),
    ])
}
