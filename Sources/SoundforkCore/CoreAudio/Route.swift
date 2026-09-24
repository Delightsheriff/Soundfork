import CoreAudio

/// Sends one app's audio to one output device (see `TapAggregate`), with the app's volume applied in the IOProc.
/// Create on the main thread; call `stop()` (or drop the last reference) to tear everything down.
public final class Route {
    public enum Source: Hashable, Sendable {
        /// Specific process objects, as listed by `AudioProcesses`.
        case processes([AudioObjectID])
        /// Bundle IDs (macOS 26+). Core Audio re-attaches the tap when those apps relaunch.
        case bundleIDs([String])
    }

    /// What Core Audio negotiated for this route; read on demand (TapSpike logs it).
    public struct Diagnostics: Sendable {
        public let tapFormat: AudioStreamBasicDescription
        public let aggregateSampleRate: Double
        public let aggregateInput: (buffers: Int, channels: Int)
        public let aggregateOutput: (buffers: Int, channels: Int)
        public let skippedInputBuffers: Int
    }

    public let source: Source
    public let destinationUID: String
    /// The bundle IDs this route taps (empty for process-object taps).
    var tapBundleIDs: [String] {
        if case .bundleIDs(let ids) = source { ids } else { [] }
    }
    public let renderer: RouteRenderer
    private let skippedInputBuffers: Int
    private var tapAggregate: TapAggregate?

    public init(source: Source, destination: OutputDevice, volume: Float = 1) throws {
        self.source = source
        destinationUID = destination.uid
        // The aggregate's input buffers start with the destination's own inputs (if any); the tap follows them.
        skippedInputBuffers = try destination.objectID.channelCount(scope: kAudioObjectPropertyScopeInput).buffers
        renderer = RouteRenderer(inputBufferOffset: skippedInputBuffers, volume: volume)

        let description = CATapDescription(stereoMixdownOfProcesses: [])
        switch source {
        case .processes(let ids):
            description.processes = ids
        case .bundleIDs(let ids):
            description.bundleIDs = ids
            description.isProcessRestoreEnabled = true
        }
        description.name = "Soundfork tap"
        description.muteBehavior = .mutedWhenTapped
        tapAggregate = try TapAggregate(tap: description, outputUID: destination.uid, name: "Soundfork route",
                                        destinationInputStreams: skippedInputBuffers,
                                        ioProc: routeIOProc, clientData: Unmanaged.passUnretained(renderer).toOpaque())
    }

    /// The IOProc holds an unretained pointer to `renderer`; stop it before the renderer can be released.
    deinit { stop() }

    public func diagnostics() throws -> Diagnostics? {
        guard let tapAggregate else { return nil }
        let aggregate = tapAggregate.aggregateID
        return Diagnostics(
            tapFormat: try tapAggregate.tapID.read(kAudioTapPropertyFormat, initial: AudioStreamBasicDescription()),
            aggregateSampleRate: try aggregate.read(kAudioDevicePropertyNominalSampleRate, initial: Float64(0)),
            aggregateInput: try aggregate.channelCount(scope: kAudioObjectPropertyScopeInput),
            aggregateOutput: try aggregate.channelCount(scope: kAudioObjectPropertyScopeOutput),
            skippedInputBuffers: skippedInputBuffers
        )
    }

    /// Idempotent. Returns any teardown failures.
    @discardableResult
    public func stop() -> [CoreAudioError] {
        defer { tapAggregate = nil }
        return tapAggregate?.stop() ?? []
    }
}
