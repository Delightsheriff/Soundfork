// Phase 1 spike: route one app to one output device and log what happens.
//
//   open -W --stdout build/spike.log --stderr build/spike.log build/TapSpike.app --args [options]
//
//   --list                 print output devices and audio processes, then exit
//   --source <bundleID>    app to route (default com.spotify.client); helpers with that prefix are included
//   --dest <text>          destination device: UID or part of its name (default: first Bluetooth device)
//   --by-bundle            tap by bundle ID (macOS 26 API) instead of by process object
//   --seconds <n>          stop after n seconds (default: run until SIGINT/SIGTERM)
//   --volume <0...1>       route volume (default 1)

import AudioRouterCore
import CoreAudio
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

func log(_ message: String) {
    let time = Date.now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
    print("[\(time)] \(message)")
}

func describe(_ format: AudioStreamBasicDescription) -> String {
    let isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
    let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
    return "\(format.mSampleRate) Hz, \(format.mChannelsPerFrame) ch, \(format.mBitsPerChannel)-bit \(isFloat ? "float" : "int"), \(interleaved ? "interleaved" : "non-interleaved")"
}

struct Options {
    var list = false
    var source = "com.spotify.client"
    var dest: String?
    var byBundle = false
    var seconds: Double?
    var volume: Float = 1

    init(_ args: [String]) {
        var it = args.makeIterator()
        while let arg = it.next() {
            switch arg {
            case "--list": list = true
            case "--source": source = it.next() ?? source
            case "--dest": dest = it.next()
            case "--by-bundle": byBundle = true
            case "--seconds": seconds = it.next().flatMap(Double.init)
            case "--volume": volume = it.next().flatMap(Float.init) ?? 1
            default: log("ignoring unknown argument \(arg)")
            }
        }
    }
}

@MainActor
final class Spike {
    let options: Options
    var route: Route?
    var started = Date.now
    var lastCallbacks: UInt64 = 0

    init(options: Options) { self.options = options }

    func listEverything() throws {
        let defaultUID = try OutputDevices.defaultOutput()?.uid
        log("OUTPUT DEVICES")
        for device in try OutputDevices.all() {
            log("  \(device.uid == defaultUID ? "*" : " ") \(device.name) [\(device.kind)] \(device.channels) ch @ \(device.sampleRate) Hz  uid=\(device.uid)")
        }
        log("AUDIO PROCESSES (▶ = currently outputting)")
        for process in try AudioProcesses.all().sorted(by: { $0.bundleID < $1.bundleID }) {
            log("  \(process.isRunningOutput ? "▶" : " ") \(process.bundleID.isEmpty ? "(no bundle id)" : process.bundleID) pid=\(process.pid) object=\(process.objectID)")
        }
    }

    func destination() throws -> OutputDevice? {
        let devices = try OutputDevices.all()
        guard let dest = options.dest else { return devices.first { $0.kind == .bluetooth } }
        return devices.first { $0.uid == dest } ?? devices.first { $0.name.localizedCaseInsensitiveContains(dest) }
    }

    func source() throws -> Route.Source? {
        if options.byBundle { return .bundleIDs([options.source]) }
        let ids = try AudioProcesses.all()
            .filter { $0.bundleID == options.source || $0.bundleID.hasPrefix(options.source + ".") }
            .map(\.objectID)
        return ids.isEmpty ? nil : .processes(ids)
    }

    func start() throws {
        try listEverything()
        guard let device = try destination() else {
            log("no destination device found (dest=\(options.dest ?? "first Bluetooth"))")
            exit(1)
        }
        guard let source = try source() else {
            log("\(options.source) has no audio process yet. Start playback in it, then re-run.")
            exit(1)
        }
        log("ROUTE \(source) → \(device.name) (\(device.uid)) volume=\(options.volume)")
        let route = try Route(source: source, destinationUID: device.uid, volume: options.volume)
        let d = route.diagnostics
        log("tap format:        \(describe(d.tapFormat))")
        log("aggregate:         \(d.aggregateSampleRate) Hz, in \(d.aggregateInput.buffers) buf/\(d.aggregateInput.channels) ch, out \(d.aggregateOutput.buffers) buf/\(d.aggregateOutput.channels) ch")
        log("destination:       \(device.sampleRate) Hz, \(d.destinationInputBuffers) input buffer(s) skipped")
        self.route = route
        started = .now
    }

    func tick() {
        guard let route else { return }
        let (callbacks, peak) = route.renderer.takeSnapshot()
        let db = peak > 0 ? String(format: "%.1f dBFS", 20 * log10(peak)) : "silent"
        log("callbacks/s=\(callbacks - lastCallbacks) peak=\(db)")
        lastCallbacks = callbacks
        if let seconds = options.seconds, Date.now.timeIntervalSince(started) >= seconds { shutdown() }
    }

    func shutdown() {
        log("stopping route")
        let errors = route?.stop() ?? []
        errors.forEach { log("teardown error: \($0)") }
        route = nil
        log(errors.isEmpty ? "clean teardown" : "teardown had \(errors.count) error(s)")
        exit(errors.isEmpty ? 0 : 2)
    }
}

let spike = Spike(options: Options(Array(CommandLine.arguments.dropFirst())))

do {
    if spike.options.list {
        try spike.listEverything()
        exit(0)
    }
    try spike.start()
} catch {
    log("FAILED: \(error)")
    exit(1)
}

var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { MainActor.assumeIsolated { spike.shutdown() } }
    source.resume()
    signalSources.append(source)
}

Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    MainActor.assumeIsolated { spike.tick() }
}
RunLoop.main.run()
