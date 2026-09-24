import CoreAudio
import Foundation

/// Sends one app's audio to one output device: process tap → private aggregate device → IOProc.
/// Create on the main thread; call `stop()` (or drop the last reference) to tear everything down.
public final class Route {
    public enum Source: Hashable, Sendable {
        /// Specific process objects, as listed by `AudioProcesses`.
        case processes([AudioObjectID])
        /// Bundle IDs (macOS 26+). Core Audio re-attaches the tap when those apps relaunch.
        case bundleIDs([String])
    }

    public struct Diagnostics: Sendable {
        public var tapFormat = AudioStreamBasicDescription()
        public var aggregateSampleRate: Double = 0
        public var aggregateInput = (buffers: 0, channels: 0)
        public var aggregateOutput = (buffers: 0, channels: 0)
        public var destinationInputBuffers = 0
    }

    public let source: Source
    public let destinationUID: String
    public let renderer: RouteRenderer
    public private(set) var diagnostics = Diagnostics()

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    public init(source: Source, destinationUID: String, volume: Float = 1) throws {
        self.source = source
        self.destinationUID = destinationUID
        guard let destination = try OutputDevices.all().first(where: { $0.uid == destinationUID }) else {
            throw CoreAudioError(call: "find output device \(destinationUID)", status: kAudioHardwareBadDeviceError)
        }
        let destinationInputs = try destination.objectID.channelCount(scope: kAudioObjectPropertyScopeInput)
        renderer = RouteRenderer(inputBufferOffset: destinationInputs.buffers, volume: volume)
        diagnostics.destinationInputBuffers = destinationInputs.buffers

        do {
            try start()
        } catch {
            stop()
            throw error
        }
    }

    deinit { stop() }

    private func start() throws {
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
        description.isPrivate = true

        try check(AudioHardwareCreateProcessTap(description, &tapID), "AudioHardwareCreateProcessTap")
        diagnostics.tapFormat = try tapID.read(kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Soundfork route",
            kAudioAggregateDeviceUIDKey: "com.delightsheriff.Soundfork.route.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: destinationUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: destinationUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "AudioHardwareCreateAggregateDevice")

        diagnostics.aggregateSampleRate = try aggregateID.read(kAudioDevicePropertyNominalSampleRate, initial: Float64(0))
        diagnostics.aggregateInput = try aggregateID.channelCount(scope: kAudioObjectPropertyScopeInput)
        diagnostics.aggregateOutput = try aggregateID.channelCount(scope: kAudioObjectPropertyScopeOutput)

        let clientData = Unmanaged.passUnretained(renderer).toOpaque()
        try check(AudioDeviceCreateIOProcID(aggregateID, routeIOProc, clientData, &ioProcID), "AudioDeviceCreateIOProcID")
        try check(AudioDeviceStart(aggregateID, ioProcID), "AudioDeviceStart")
    }

    /// Tears down in the only safe order. Idempotent. Returns any failures (they can't be recovered from, only reported).
    @discardableResult
    public func stop() -> [CoreAudioError] {
        var errors: [CoreAudioError] = []
        func attempt(_ status: OSStatus, _ call: String) {
            if status != noErr { errors.append(CoreAudioError(call: call, status: status)) }
        }
        if let ioProcID {
            attempt(AudioDeviceStop(aggregateID, ioProcID), "AudioDeviceStop")
            attempt(AudioDeviceDestroyIOProcID(aggregateID, ioProcID), "AudioDeviceDestroyIOProcID")
            self.ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            attempt(AudioHardwareDestroyAggregateDevice(aggregateID), "AudioHardwareDestroyAggregateDevice")
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            attempt(AudioHardwareDestroyProcessTap(tapID), "AudioHardwareDestroyProcessTap")
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        return errors
    }
}
