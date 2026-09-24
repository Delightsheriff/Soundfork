import CoreAudio
import Synchronization

/// The part of a route that runs on Core Audio's real-time thread.
/// Everything here must stay allocation-free and lock-free: atomics and raw buffer copies only.
public final class RouteRenderer: Sendable {
    private let volumeBits = Atomic<UInt32>(Float(1).bitPattern)
    private let callbacks = Atomic<UInt64>(0)
    private let peakBits = Atomic<UInt32>(0)
    /// Gain actually applied at the end of the last buffer; only the IOProc writes it. Starts at 0 so routes fade in.
    private let appliedGainBits = Atomic<UInt32>(Float(0).bitPattern)
    /// The aggregate's input buffers start with the destination device's own inputs (if any); the tap comes after.
    private let inputBufferOffset: Int

    init(inputBufferOffset: Int, volume: Float) {
        self.inputBufferOffset = inputBufferOffset
        volumeBits.store(volume.bitPattern, ordering: .relaxed)
    }

    public var volume: Float {
        get { Float(bitPattern: volumeBits.load(ordering: .relaxed)) }
        set { volumeBits.store(max(0, min(newValue, 1)).bitPattern, ordering: .relaxed) }
    }

    /// IOProc call count so far, and the peak output level since the previous call.
    public func takeSnapshot() -> (callbacks: UInt64, peak: Float) {
        (callbacks.load(ordering: .relaxed), Float(bitPattern: peakBits.exchange(0, ordering: .relaxed)))
    }

    func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        callbacks.add(1, ordering: .relaxed)
        // Ramp linearly from the last applied gain to the target across this buffer: no zipper noise or pops.
        let startGain = Float(bitPattern: appliedGainBits.load(ordering: .relaxed))
        let targetGain = self.volume
        let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outs = UnsafeMutableAudioBufferListPointer(output)
        var peak: Float = 0
        var outChannel = 0

        for buffer in outs {
            let stride = Int(buffer.mNumberChannels)
            guard let data = buffer.mData, stride > 0 else { continue }
            let out = data.assumingMemoryBound(to: Float.self)
            let frames = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * stride)
            let gainStep = frames > 0 ? (targetGain - startGain) / Float(frames) : 0

            for channel in 0..<stride {
                var written = 0
                if let source = sourceChannel(outChannel + channel, in: ins) {
                    written = min(frames, source.frames)
                    for frame in 0..<written {
                        let gain = startGain + gainStep * Float(frame + 1)
                        let sample = source.samples[frame * source.stride] * gain
                        out[frame * stride + channel] = sample
                        peak = max(peak, abs(sample))
                    }
                }
                for frame in written..<frames { out[frame * stride + channel] = 0 }
            }
            outChannel += stride
        }
        appliedGainBits.store(targetGain.bitPattern, ordering: .relaxed)
        raisePeak(to: peak)
    }

    /// Finds tap channel `index` across the (possibly interleaved) tap buffers. Output channels beyond the tap's are silent.
    private func sourceChannel(_ index: Int, in ins: UnsafeMutableAudioBufferListPointer)
        -> (samples: UnsafePointer<Float>, stride: Int, frames: Int)? {
        var remaining = index
        var bufferIndex = inputBufferOffset
        while bufferIndex < ins.count {
            let buffer = ins[bufferIndex]
            let channels = Int(buffer.mNumberChannels)
            if remaining < channels {
                guard let data = buffer.mData else { return nil }
                let samples = UnsafePointer(data.assumingMemoryBound(to: Float.self)) + remaining
                return (samples, channels, Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channels))
            }
            remaining -= channels
            bufferIndex += 1
        }
        return nil
    }

    private func raisePeak(to peak: Float) {
        var current = peakBits.load(ordering: .relaxed)
        // Non-negative floats order the same as their bit patterns.
        while peak.bitPattern > current {
            let (exchanged, original) = peakBits.compareExchange(expected: current, desired: peak.bitPattern, ordering: .relaxed)
            if exchanged { return }
            current = original
        }
    }
}

/// C entry point for the IOProc; `clientData` is an unretained `RouteRenderer` kept alive by its `Route`.
func routeIOProc(_: AudioObjectID,
                 _: UnsafePointer<AudioTimeStamp>,
                 _ input: UnsafePointer<AudioBufferList>,
                 _: UnsafePointer<AudioTimeStamp>,
                 _ output: UnsafeMutablePointer<AudioBufferList>,
                 _: UnsafePointer<AudioTimeStamp>,
                 _ clientData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let clientData else { return noErr }
    Unmanaged<RouteRenderer>.fromOpaque(clientData)._withUnsafeGuaranteedRef { $0.render(input: input, output: output) }
    return noErr
}
