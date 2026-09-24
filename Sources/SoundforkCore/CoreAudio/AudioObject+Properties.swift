import CoreAudio

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func hasProperty(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectHasProperty(self, &address)
    }

    /// Reads a fixed-size property (UInt32, pid_t, AudioStreamBasicDescription, ...).
    func read<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector,
                                  scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                  initial: T) throws -> T {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<T>.size)
        var value = initial
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0) }
        try check(status, "get \(fourCC(selector)) on \(self)")
        return value
    }

    /// Reads a variable-length array property (device lists, process lists, ...).
    func readArray<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector,
                      scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                      of _: T.Type) throws -> [T] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size), "size \(fourCC(selector)) on \(self)")
        let count = Int(size) / MemoryLayout<T>.stride
        guard count > 0 else { return [] }
        return try [T](unsafeUninitializedCapacity: count) { buffer, initialized in
            try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, buffer.baseAddress!), "get \(fourCC(selector)) on \(self)")
            initialized = Int(size) / MemoryLayout<T>.stride
        }
    }

    /// Reads a CFString property. Core Audio hands back a +1 reference.
    func readString(_ selector: AudioObjectPropertySelector,
                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> String {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, &value), "get \(fourCC(selector)) on \(self)")
        return value?.takeRetainedValue() as String? ?? ""
    }

    /// Total channel count across all streams in a scope, from kAudioDevicePropertyStreamConfiguration.
    func channelCount(scope: AudioObjectPropertyScope) throws -> (buffers: Int, channels: Int) {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size), "size stream config on \(self)")
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, raw), "get stream config on \(self)")
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return (list.count, list.reduce(0) { $0 + Int($1.mNumberChannels) })
    }
}
