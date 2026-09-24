import CoreAudio
import Testing
@testable import SoundforkCore

/// Owns the sample memory behind a hand-built AudioBufferList.
private final class Buffers {
    let list: UnsafeMutableAudioBufferListPointer
    private var storage: [UnsafeMutablePointer<Float>] = []

    /// One buffer per entry: (interleaved channels, frames, fill(frame, channel) -> sample).
    init(_ layout: [(channels: Int, frames: Int, fill: (Int, Int) -> Float)]) {
        list = AudioBufferList.allocate(maximumBuffers: layout.count)
        for (index, buffer) in layout.enumerated() {
            let samples = UnsafeMutablePointer<Float>.allocate(capacity: buffer.channels * buffer.frames)
            for frame in 0..<buffer.frames {
                for channel in 0..<buffer.channels { samples[frame * buffer.channels + channel] = buffer.fill(frame, channel) }
            }
            storage.append(samples)
            list[index] = AudioBuffer(mNumberChannels: UInt32(buffer.channels),
                                      mDataByteSize: UInt32(buffer.channels * buffer.frames * MemoryLayout<Float>.size),
                                      mData: samples)
        }
    }

    func sample(buffer: Int, frame: Int, channel: Int) -> Float {
        let channels = Int(list[buffer].mNumberChannels)
        return storage[buffer][frame * channels + channel]
    }

    deinit {
        storage.forEach { $0.deallocate() }
        free(list.unsafeMutablePointer)
    }
}

private let frames = 8

/// Stereo tap: left = 1, right = -1 on every frame.
private func stereoTap() -> (channels: Int, frames: Int, fill: (Int, Int) -> Float) {
    (2, frames, { _, channel in channel == 0 ? 1 : -1 })
}

private func silentOutput(channels: Int = 2) -> Buffers {
    Buffers([(channels, frames, { _, _ in 99 })]) // garbage the renderer must overwrite
}

@Test func firstBufferFadesInFromSilenceToTheTargetGain() {
    let renderer = RouteRenderer(inputBufferOffset: 0, volume: 0.5)
    let input = Buffers([stereoTap()])
    let output = silentOutput()
    renderer.render(input: input.list.unsafePointer, output: output.list.unsafeMutablePointer)

    // Linear ramp 0 → 0.5 across 8 frames: frame f gets 0.5 * (f + 1) / 8.
    #expect(output.sample(buffer: 0, frame: 0, channel: 0) == 0.5 / 8)
    #expect(output.sample(buffer: 0, frame: frames - 1, channel: 0) == 0.5)
    #expect(output.sample(buffer: 0, frame: frames - 1, channel: 1) == -0.5)
}

@Test func steadyGainAfterTheRampScalesEveryFrame() {
    let renderer = RouteRenderer(inputBufferOffset: 0, volume: 0.25)
    let input = Buffers([stereoTap()])
    let warmUp = silentOutput()
    withExtendedLifetime(warmUp) { renderer.render(input: input.list.unsafePointer, output: warmUp.list.unsafeMutablePointer) }

    let output = silentOutput()
    renderer.render(input: input.list.unsafePointer, output: output.list.unsafeMutablePointer)
    for frame in 0..<frames {
        #expect(output.sample(buffer: 0, frame: frame, channel: 0) == 0.25)
        #expect(output.sample(buffer: 0, frame: frame, channel: 1) == -0.25)
    }
}

@Test func destinationInputBuffersBeforeTheTapAreSkipped() {
    let renderer = RouteRenderer(inputBufferOffset: 1, volume: 1)
    // Buffer 0 is the destination's own microphone (must be ignored), buffer 1 is the tap.
    let input = Buffers([(1, frames, { _, _ in 7 }), stereoTap()])
    let warmUp = silentOutput()
    withExtendedLifetime(warmUp) { renderer.render(input: input.list.unsafePointer, output: warmUp.list.unsafeMutablePointer) }
    let output = silentOutput()
    renderer.render(input: input.list.unsafePointer, output: output.list.unsafeMutablePointer)
    #expect(output.sample(buffer: 0, frame: 3, channel: 0) == 1)
    #expect(output.sample(buffer: 0, frame: 3, channel: 1) == -1)
}

@Test func outputChannelsBeyondStereoAreSilent() {
    let renderer = RouteRenderer(inputBufferOffset: 0, volume: 1)
    let input = Buffers([stereoTap()])
    let output = silentOutput(channels: 4)
    renderer.render(input: input.list.unsafePointer, output: output.list.unsafeMutablePointer)
    for frame in 0..<frames {
        #expect(output.sample(buffer: 0, frame: frame, channel: 2) == 0)
        #expect(output.sample(buffer: 0, frame: frame, channel: 3) == 0)
    }
}

@Test func shortInputIsPaddedWithSilence() {
    let renderer = RouteRenderer(inputBufferOffset: 0, volume: 1)
    let input = Buffers([(2, frames / 2, { _, _ in 1 })])
    let output = silentOutput()
    renderer.render(input: input.list.unsafePointer, output: output.list.unsafeMutablePointer)
    #expect(output.sample(buffer: 0, frame: frames / 2 - 1, channel: 0) != 0)
    for frame in (frames / 2)..<frames {
        #expect(output.sample(buffer: 0, frame: frame, channel: 0) == 0)
    }
}

@Test func mutingRampsDownToSilence() {
    let renderer = RouteRenderer(inputBufferOffset: 0, volume: 1)
    let input = Buffers([stereoTap()])
    let warmUp = silentOutput()
    withExtendedLifetime(warmUp) { renderer.render(input: input.list.unsafePointer, output: warmUp.list.unsafeMutablePointer) }

    renderer.volume = 0
    let fading = silentOutput()
    renderer.render(input: input.list.unsafePointer, output: fading.list.unsafeMutablePointer)
    #expect(fading.sample(buffer: 0, frame: 0, channel: 0) > 0)       // ramps rather than cutting off
    #expect(fading.sample(buffer: 0, frame: frames - 1, channel: 0) == 0)

    let silent = silentOutput()
    renderer.render(input: input.list.unsafePointer, output: silent.list.unsafeMutablePointer)
    #expect((0..<frames).allSatisfy { silent.sample(buffer: 0, frame: $0, channel: 0) == 0 })
}
