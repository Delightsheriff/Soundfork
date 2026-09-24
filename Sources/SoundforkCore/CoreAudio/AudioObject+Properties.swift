import CoreAudio

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope,
                                _ element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    func hasProperty(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> Bool {
        var address = Self.address(selector, scope, element)
        return AudioObjectHasProperty(self, &address)
    }

    func isSettable(_ selector: AudioObjectPropertySelector,
                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> Bool {
        guard hasProperty(selector, scope: scope, element: element) else { return false }
        var address = Self.address(selector, scope, element)
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(self, &address, &settable) == noErr && settable.boolValue
    }

    /// Reads a fixed-size property (UInt32, pid_t, AudioStreamBasicDescription, ...).
    func read<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector,
                                  scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                  element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
                                  initial: T) throws -> T {
        var address = Self.address(selector, scope, element)
        var size = UInt32(MemoryLayout<T>.size)
        var value = initial
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0) }
        try check(status, "get \(fourCC(selector)) on \(self)")
        return value
    }

    /// Writes a fixed-size property.
    func write<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector,
                                   scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                   element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
                                   value: T) throws {
        var address = Self.address(selector, scope, element)
        var value = value
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectSetPropertyData(self, &address, 0, nil, UInt32(MemoryLayout<T>.size), $0)
        }
        try check(status, "set \(fourCC(selector)) on \(self)")
    }

    /// Reads a variable-length array property (device lists, process lists, ...).
    func readArray<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector,
                                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                       of _: T.Type) throws -> [T] {
        var address = Self.address(selector, scope, kAudioObjectPropertyElementMain)
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
        var address = Self.address(selector, scope, kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, &value), "get \(fourCC(selector)) on \(self)")
        return value?.takeRetainedValue() as String? ?? ""
    }

    /// Total channel count across all streams in a scope, from kAudioDevicePropertyStreamConfiguration.
    func channelCount(scope: AudioObjectPropertyScope) throws -> (buffers: Int, channels: Int) {
        var address = Self.address(kAudioDevicePropertyStreamConfiguration, scope, kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size), "size stream config on \(self)")
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, raw), "get stream config on \(self)")
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return (list.count, list.reduce(0) { $0 + Int($1.mNumberChannels) })
    }
}
