import CoreMedia

extension CMTime {
    static let millisecondTimescale: CMTimeScale = 1000

    init(ms: Int64) {
        self.init(value: CMTimeValue(ms), timescale: CMTime.millisecondTimescale)
    }

    var ms: Int64 {
        guard isNumeric else { return 0 }
        return Int64((seconds * 1000).rounded())
    }
}
