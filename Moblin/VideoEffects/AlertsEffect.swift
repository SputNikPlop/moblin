import AVFoundation
import Collections
import MetalPetal
import SDWebImage
import SwiftUI
import Vision
import WrappingHStack

private let lockQueue = DispatchQueue(label: "com.eerimoq.Moblin.Alerts")

private struct Word: Identifiable {
    let id: UUID = .init()
    let text: String
}

enum AlertsEffectAlert {
    case twitchFollow(TwitchEventSubNotificationChannelFollowEvent)
    case twitchSubscribe(TwitchEventSubNotificationChannelSubscribeEvent)
}

protocol AlertsEffectDelegate: AnyObject {
    func alertsPlayerRegisterVideoEffect(effect: VideoEffect)
}

private enum MediaItem {
    case bundledName(String)
    case customUrl(URL)
}

private class Medias {
    var images: [CIImage] = []
    var soundUrl: URL?
    var fps: Double = 1.0

    func updateSoundUrl(sound: MediaItem) {
        switch sound {
        case let .bundledName(name):
            soundUrl = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "mp3")
        case let .customUrl(url):
            if (try? url.checkResourceIsReachable()) == true {
                soundUrl = url
            } else {
                soundUrl = nil
            }
        }
    }

    func updateImages(image: MediaItem, loopCount: Int) {
        DispatchQueue.global().async {
            var images: [CIImage] = []
            switch image {
            case let .bundledName(name):
                if let url = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "gif") {
                    images = self.loadImages(url: url, loopCount: loopCount)
                }
            case let .customUrl(url):
                images = self.loadImages(url: url, loopCount: loopCount)
            }
            lockQueue.sync {
                self.images = images
            }
        }
    }

    private func loadImages(url: URL, loopCount: Int) -> [CIImage] {
        var fpsTime = 0.0
        var gifTime = 0.0
        var images: [CIImage] = []
        for _ in 0 ..< loopCount {
            if let data = try? Data(contentsOf: url), let animatedImage = SDAnimatedImage(data: data) {
                for index in 0 ..< animatedImage.animatedImageFrameCount {
                    if let cgImage = animatedImage.animatedImageFrame(at: index)?.cgImage {
                        gifTime += animatedImage.animatedImageDuration(at: index)
                        let image = CIImage(cgImage: cgImage)
                        while fpsTime < gifTime {
                            images.append(image)
                            fpsTime += 1 / fps
                        }
                    }
                }
            }
        }
        return images
    }
}

final class AlertsEffect: VideoEffect {
    private var images: [CIImage] = []
    private var imageIndex: Int = 0
    private var messageImage: CIImage?
    private var audioPlayer: AVAudioPlayer?
    private var rate: Float = 0.4
    private var volume: Float = 1.0
    private var synthesizer = AVSpeechSynthesizer()
    private var alertsQueue: Deque<AlertsEffectAlert> = .init()
    private weak var delegate: (any AlertsEffectDelegate)?
    private var toBeRemoved: Bool = true
    private var isPlaying: Bool = false
    private var settings: SettingsWidgetAlerts
    private var x: Double = 0
    private var y: Double = 0
    private let mediaStorage: AlertMediaStorage
    private var twitchFollow = Medias()
    private var twitchSubscribe = Medias()
    private let bundledImages: [SettingsAlertsMediaGalleryItem]
    private let bundledSounds: [SettingsAlertsMediaGalleryItem]

    init(
        settings: SettingsWidgetAlerts,
        fps: Int,
        delegate: AlertsEffectDelegate,
        mediaStorage: AlertMediaStorage,
        bundledImages: [SettingsAlertsMediaGalleryItem],
        bundledSounds: [SettingsAlertsMediaGalleryItem]
    ) {
        self.settings = settings
        self.delegate = delegate
        self.mediaStorage = mediaStorage
        self.bundledImages = bundledImages
        self.bundledSounds = bundledSounds
        twitchFollow.fps = Double(fps)
        twitchSubscribe.fps = Double(fps)
        audioPlayer = nil
        super.init()
        setSettings(settings: settings)
    }

    private func getMediaItems(alert: SettingsWidgetAlertsTwitchAlert) -> (MediaItem, Int, MediaItem) {
        let image: MediaItem
        if let bundledImage = bundledImages.first(where: { $0.id == alert.imageId }) {
            image = .bundledName(bundledImage.name)
        } else {
            image = .customUrl(mediaStorage.makePath(id: alert.imageId))
        }
        let sound: MediaItem
        if let bundledSound = bundledSounds.first(where: { $0.id == alert.soundId }) {
            sound = .bundledName(bundledSound.name)
        } else {
            sound = .customUrl(mediaStorage.makePath(id: alert.soundId))
        }
        return (image, alert.imageLoopCount!, sound)
    }

    func setSettings(settings: SettingsWidgetAlerts) {
        let twitch = settings.twitch!
        var (image, imageLoopCount, sound) = getMediaItems(alert: twitch.follows)
        twitchFollow.updateImages(image: image, loopCount: imageLoopCount)
        twitchFollow.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: twitch.subscriptions)
        twitchSubscribe.updateImages(image: image, loopCount: imageLoopCount)
        twitchSubscribe.updateSoundUrl(sound: sound)
        self.settings = settings
    }

    func setPosition(x: Double, y: Double) {
        lockQueue.sync {
            self.x = x
            self.y = y
        }
    }

    @MainActor
    func play(alert: AlertsEffectAlert) {
        alertsQueue.append(alert)
        tryPlayNextAlert()
    }

    func shoudRegisterEffect() -> Bool {
        return lockQueue.sync { !toBeRemoved }
    }

    @MainActor
    private func tryPlayNextAlert() {
        guard !isPlaying else {
            return
        }
        guard let alert = alertsQueue.popFirst() else {
            return
        }
        switch alert {
        case let .twitchFollow(event):
            playTwitchFollow(event: event)
        case let .twitchSubscribe(event):
            playTwitchSubscribe(event: event)
        }
    }

    @MainActor
    private func playTwitchFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        guard settings.twitch!.follows.enabled else {
            return
        }
        play(
            medias: twitchFollow,
            username: event.user_name,
            message: String(localized: "just followed!"),
            settings: settings.twitch!.follows
        )
    }

    @MainActor
    private func playTwitchSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        guard settings.twitch!.subscriptions.enabled else {
            return
        }
        play(
            medias: twitchSubscribe,
            username: event.user_name,
            message: String(localized: "just subscribed!"),
            settings: settings.twitch!.subscriptions
        )
    }

    @MainActor
    private func play(
        medias: Medias,
        username: String,
        message: String,
        settings: SettingsWidgetAlertsTwitchAlert
    ) {
        isPlaying = true
        let messageImage = renderMessage(username: username, message: message, settings: settings)
        lockQueue.sync {
            self.images = medias.images
            imageIndex = 0
            self.messageImage = messageImage
            toBeRemoved = false
        }
        delegate?.alertsPlayerRegisterVideoEffect(effect: self)
        if let soundUrl = medias.soundUrl {
            audioPlayer = try? AVAudioPlayer(contentsOf: soundUrl)
            audioPlayer?.play()
        }
        if settings.textToSpeechEnabled! {
            say(username: username, message: message, settings: settings)
        }
    }

    private func say(username: String, message: String, settings: SettingsWidgetAlertsTwitchAlert) {
        guard let voice = getVoice(settings: settings) else {
            return
        }
        let utterance = AVSpeechUtterance(string: "\(username) \(message)")
        utterance.rate = rate
        utterance.pitchMultiplier = 0.8
        utterance.volume = volume
        utterance.voice = voice
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.textToSpeechDelay!) {
            self.synthesizer.speak(utterance)
        }
    }

    private func getVoice(settings: SettingsWidgetAlertsTwitchAlert) -> AVSpeechSynthesisVoice? {
        guard let language = Locale.current.language.languageCode?.identifier else {
            return nil
        }
        if let voiceIdentifier = settings.textToSpeechLanguageVoices![language] {
            return AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else if let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter({ $0.language.starts(with: language) }).first
        {
            return AVSpeechSynthesisVoice(identifier: voice.identifier)
        }
        return nil
    }

    @MainActor
    private func renderMessage(username: String, message: String,
                               settings: SettingsWidgetAlertsTwitchAlert) -> CIImage?
    {
        let words = message.split(separator: " ").map { Word(text: String($0)) }
        let message = WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Text("\(username) ")
                .foregroundColor(settings.accentColor.color())
            ForEach(words) { word in
                Text("\(word.text) ")
                    .foregroundColor(settings.textColor.color())
            }
        }
        .font(.system(
            size: CGFloat(settings.fontSize),
            weight: settings.fontWeight.toSystem(),
            design: settings.fontDesign.toSystem()
        ))
        .shadow(color: .black, radius: 0, x: 1, y: 0)
        .shadow(color: .black, radius: 0, x: -1, y: 0)
        .shadow(color: .black, radius: 0, x: 0, y: 1)
        .shadow(color: .black, radius: 0, x: 0, y: -1)
        .shadow(color: .black, radius: 0, x: -2, y: -2)
        .frame(width: 1000)
        let renderer = ImageRenderer(content: message)
        guard let image = renderer.uiImage else {
            return nil
        }
        return CIImage(image: image)
    }

    override func getName() -> String {
        return "Alert widget"
    }

    private func getNext(image: CIImage) -> (CIImage, CIImage?, Double, Double) {
        guard imageIndex < images.count else {
            toBeRemoved = true
            return (image, nil, x, y)
        }
        defer {
            imageIndex += 1
            toBeRemoved = imageIndex == images.count
        }
        return (images[imageIndex], messageImage, x, y)
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        let (alertImage, messageImage, x, y) = lockQueue.sync {
            getNext(image: image)
        }
        guard let messageImage else {
            return image
        }
        let xPos = toPixels(x, image.extent.width)
        let yPos = image.extent.height - toPixels(y, image.extent.height) - alertImage.extent.height
        return messageImage
            .transformed(by: CGAffineTransform(
                translationX: -(messageImage.extent.width - alertImage.extent.width) / 2,
                y: -messageImage.extent.height
            ))
            .composited(over: alertImage)
            .transformed(by: CGAffineTransform(translationX: xPos, y: yPos))
            .composited(over: image)
            .cropped(to: image.extent)
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        return lockQueue.sync {
            guard imageIndex < images.count else {
                self.toBeRemoved = true
                return image
            }
            defer {
                self.imageIndex += 1
                self.toBeRemoved = imageIndex == images.count
            }
            return image
        }
    }

    override func shouldRemove() -> Bool {
        return toBeRemoved
    }

    override func removed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isPlaying = false
            self.tryPlayNextAlert()
        }
    }
}
