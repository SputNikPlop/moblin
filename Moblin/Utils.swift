import AVKit
import SwiftUI

let firstReconnectTime = 5.0
let buttonSize: CGFloat = 40

func nextReconnectTime(_ reconnectTime: Double) -> Double {
    return min(reconnectTime * 1.3, 60)
}

extension String: Error {}

extension String {
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension UIImage {
    func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize
        )
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero,
                size: scaledImageSize
            ))
        }
        return scaledImage
    }
}

func makeRtmpUri(url: String) -> String {
    guard var url = URL(string: url) else {
        return ""
    }
    var components = url.pathComponents
    if components.count < 2 {
        return ""
    }
    components.removeFirst()
    components.removeLast()
    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    let path = components.joined(separator: "/")
    urlComponents.path = "/\(path)"
    url = urlComponents.url!
    return "\(url)"
}

func makeRtmpStreamName(url: String) -> String {
    let parts = url.split(separator: "/")
    if parts.isEmpty {
        return ""
    }
    return String(parts[parts.count - 1])
}

func isValidRtmpUrl(url: String) -> String? {
    if makeRtmpUri(url: url) == "" {
        return String(localized: "Malformed RTMP URL")
    }
    if makeRtmpStreamName(url: url) == "" {
        return String(localized: "RTMP stream name missing")
    }
    return nil
}

func isValidSrtUrl(url: String) -> String? {
    guard let url = URL(string: url) else {
        return String(localized: "Malformed SRT(LA) URL")
    }
    if url.port == nil {
        return String(localized: "SRT(LA) port number missing")
    }
    return nil
}

func cleanUrl(url value: String) -> String {
    let stripped = value.replacingOccurrences(of: " ", with: "")
    guard var components = URLComponents(string: stripped) else {
        return stripped
    }
    components.scheme = components.scheme?.lowercased()
    return components.string!
}

func isValidUrl(url value: String) -> String? {
    guard let url = URL(string: value) else {
        return String(localized: "Malformed URL")
    }
    if url.host() == nil {
        return String(localized: "Host missing")
    }
    guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
        return String(localized: "Malformed URL")
    }
    switch url.scheme {
    case "rtmp":
        if let message = isValidRtmpUrl(url: value) {
            return message
        }
    case "rtmps":
        if let message = isValidRtmpUrl(url: value) {
            return message
        }
    case "srt":
        if let message = isValidSrtUrl(url: value) {
            return message
        }
    case "srtla":
        if let message = isValidSrtUrl(url: value) {
            return message
        }
    case nil:
        return String(localized: "Scheme missing")
    default:
        return String(localized: "Unsupported scheme \(url.scheme!)")
    }
    return nil
}

func isValidWebSocketUrl(url value: String) -> String? {
    if value.isEmpty {
        return nil
    }
    guard let url = URL(string: value) else {
        return String(localized: "Malformed URL")
    }
    if url.host() == nil {
        return String(localized: "Host missing")
    }
    guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
        return String(localized: "Malformed URL")
    }
    switch url.scheme {
    case "ws":
        break
    case "wss":
        break
    case nil:
        return String(localized: "Scheme missing")
    default:
        return String(localized: "Unsupported scheme \(url.scheme!)")
    }
    return nil
}

func schemeAndAddress(url: String) -> String {
    guard var url = URL(string: url) else {
        return ""
    }
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
        return ""
    }
    urlComponents.path = "/"
    urlComponents.query = nil
    url = urlComponents.url!
    return "\(url)..."
}

func replaceSensitive(value: String, sensitive: Bool) -> String {
    if sensitive {
        return value.replacing(/./, with: "*")
    } else {
        return value
    }
}

func widgetImage(widget: SettingsWidget) -> String {
    switch widget.type {
    case .image:
        return "photo"
    case .videoEffect:
        return "camera.filters"
    case .browser:
        return "photo.stack"
    case .time:
        return "calendar.badge.clock"
    }
}

var countFormatter: IntegerFormatStyle<Int> {
    return IntegerFormatStyle<Int>().notation(.compactName)
}

var sizeFormatter: ByteCountFormatter {
    let formatter = ByteCountFormatter()
    formatter.allowsNonnumericFormatting = false
    formatter.countStyle = .decimal
    return formatter
}

func formatBytesPerSecond(speed: Int64) -> String {
    var speed = sizeFormatter.string(fromByteCount: speed)
    speed = speed.replacingOccurrences(of: "bytes", with: "b")
    speed = speed.replacingOccurrences(of: "byte", with: "b")
    return speed.replacingOccurrences(of: "B", with: "b") + "ps"
}

var uptimeFormatter: DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.zeroFormattingBehavior = .pad
    return formatter
}

var digitalClockFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}

extension ProcessInfo.ThermalState {
    func string() -> String {
        switch self {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        default:
            return "unknown"
        }
    }
}

extension Data {
    func getUInt32Be(offset: Int = 0) -> UInt32 {
        return withUnsafeBytes { data in
            data.load(fromByteOffset: offset, as: UInt32.self)
        }.bigEndian
    }

    func getUInt16Be(offset: Int = 0) -> UInt16 {
        return withUnsafeBytes { data in
            data.load(fromByteOffset: offset, as: UInt16.self)
        }.bigEndian
    }

    mutating func setUInt16Be(value: UInt16, offset: Int = 0) {
        withUnsafeMutableBytes { data in data.storeBytes(
            of: value.bigEndian,
            toByteOffset: offset,
            as: UInt16.self
        ) }
    }

    mutating func setUInt32Be(value: UInt32, offset: Int = 0) {
        withUnsafeMutableBytes { data in data.storeBytes(
            of: value.bigEndian,
            toByteOffset: offset,
            as: UInt32.self
        ) }
    }
}

extension Data {
    static func random(length: Int) -> Data {
        return Data((0 ..< length).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
    }
}

extension AVCaptureSession.InterruptionReason {
    func toString() -> String {
        switch self {
        case .videoDeviceNotAvailableInBackground:
            return "videoDeviceNotAvailableInBackground"
        case .audioDeviceInUseByAnotherClient:
            return "audioDeviceInUseByAnotherClient"
        case .videoDeviceInUseByAnotherClient:
            return "videoDeviceInUseByAnotherClient"
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            return "videoDeviceNotAvailableWithMultipleForegroundApps"
        case .videoDeviceNotAvailableDueToSystemPressure:
            return "videoDeviceNotAvailableDueToSystemPressure"
        default:
            return "unknown"
        }
    }
}

func version() -> String {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
}

func formatAsInt(_ value: CGFloat) -> String {
    return String(format: "%d", Int(value))
}

func formatOneDecimal(value: Float) -> String {
    return String(format: "%.01f", value)
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

func bitrateToMbps(bitrate: UInt32) -> Float {
    return Float(bitrate) / 1_000_000
}

func bitrateFromMbps(bitrate: Float) -> UInt32 {
    return UInt32(bitrate * 1_000_000)
}

extension RgbColor {
    private func colorScale(_ color: Int) -> Double {
        return Double(color) / 255
    }

    func color() -> Color {
        return Color(
            red: colorScale(red),
            green: colorScale(green),
            blue: colorScale(blue)
        )
    }
}

func getOrientation() -> UIDeviceOrientation {
    let orientation = UIDevice.current.orientation
    if orientation != .unknown {
        return orientation
    }
    let interfaceOrientation = UIApplication.shared.connectedScenes
        .first(where: { $0 is UIWindowScene })
        .flatMap { $0 as? UIWindowScene }?.interfaceOrientation
    switch interfaceOrientation {
    case .landscapeLeft:
        return .landscapeRight
    case .landscapeRight:
        return .landscapeLeft
    default:
        return .unknown
    }
}

func radiansToDegrees(_ number: Double) -> Int {
    return Int(number * 180 / .pi)
}

func diffAngles(_ one: Double, _ two: Double) -> Int {
    let diff = abs(radiansToDegrees(one - two))
    return min(diff, 360 - diff)
}

extension URLResponse {
    var http: HTTPURLResponse? {
        return self as? HTTPURLResponse
    }
}

extension HTTPURLResponse {
    var isSuccessful: Bool {
        return 200 ... 299 ~= statusCode
    }

    var isNotFound: Bool {
        return statusCode == 404
    }
}

func httpGet(from: URL) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await URLSession.shared.data(from: from)
    if let response = response.http {
        // logger.info("\(from) \(response.statusCode) \(data.count)")
        return (data, response)
    } else {
        throw "Not an HTTP response"
    }
}

let smallFont = Font.system(size: 13)

extension AVCaptureDevice {
    func getZoomFactorScale(hasUltraWideCamera: Bool) -> Float {
        if hasUltraWideCamera {
            switch deviceType {
            case .builtInTripleCamera, .builtInDualWideCamera, .builtInUltraWideCamera:
                return 0.5
            case .builtInTelephotoCamera:
                return (virtualDeviceSwitchOverVideoZoomFactors.last?.floatValue ?? 10.0) / 2
            default:
                return 1.0
            }
        } else {
            switch deviceType {
            case .builtInTelephotoCamera:
                return virtualDeviceSwitchOverVideoZoomFactors.last?.floatValue ?? 2.0
            default:
                return 1.0
            }
        }
    }

    func getUIZoomRange(hasUltraWideCamera: Bool) -> (Float, Float) {
        let factor = getZoomFactorScale(hasUltraWideCamera: hasUltraWideCamera)
        return (Float(minAvailableVideoZoomFactor) * factor, Float(maxAvailableVideoZoomFactor) * factor)
    }
}

func cameraName(device: AVCaptureDevice?) -> String {
    guard let device else {
        return ""
    }
    switch device.deviceType {
    case .builtInTripleCamera:
        return String(localized: "Triple (auto)")
    case .builtInDualCamera:
        return String(localized: "Dual (auto)")
    case .builtInDualWideCamera:
        return String(localized: "Wide dual (auto)")
    case .builtInUltraWideCamera:
        return String(localized: "Ultra wide")
    case .builtInWideAngleCamera:
        return String(localized: "Wide")
    case .builtInTelephotoCamera:
        return String(localized: "Telephoto")
    default:
        return ""
    }
}

func hasUltraWideCamera() -> Bool {
    return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
}

func getBestBackCameraDevice() -> AVCaptureDevice? {
    var device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
    if device == nil {
        device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
    }
    return device
}

func getBestBackCameraType() -> SettingsCameraType {
    guard let device = getBestBackCameraDevice() else {
        return .dual
    }
    switch device.deviceType {
    case .builtInTripleCamera:
        return .triple
    case .builtInDualCamera:
        return .dual
    default:
        return .dual
    }
}
