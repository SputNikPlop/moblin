import Foundation

struct Sender: Decodable {
    var username: String
}

struct ChatMessage: Decodable {
    var content: String
    var sender: Sender
}

func decodeEvent(message: String) throws -> (String, String) {
    if let jsonData = message.data(using: String.Encoding.utf8) {
        let data = try JSONSerialization.jsonObject(
            with: jsonData,
            options: JSONSerialization.ReadingOptions.mutableContainers
        )
        if let jsonResult: NSDictionary = data as? NSDictionary {
            if let type: String = jsonResult["event"] as? String {
                if let data: String = jsonResult["data"] as? String {
                    return (type, data)
                }
            }
        }
    }
    throw "Failed to get message event type"
}

func decodeChatMessage(data: String) throws -> ChatMessage {
    return try JSONDecoder().decode(
        ChatMessage.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private var url =
    URL(
        string: "wss://ws-us2.pusher.com/app/eb1d5f283081a78b932c?protocol=7&client=js&version=7.6.0&flash=false"
    )!

func removeEmote(message: String) -> String {
    return message.replacingOccurrences(
        of: "\\[emote:\\d+:(.*?)]",
        with: "$1",
        options: .regularExpression
    )
}

final class KickPusher: NSObject, URLSessionWebSocketDelegate {
    private var model: Model
    private var webSocket: URLSessionWebSocketTask
    private var channelId: String
    private var reconnectTimer: Timer?
    private var reconnectTime = firstReconnectTime
    private var running = true

    init(model: Model, channelId: String) {
        self.model = model
        self.channelId = channelId
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        reconnectTime = firstReconnectTime
        setupWebsocket()
    }

    func stop() {
        webSocket.cancel()
        reconnectTimer?.invalidate()
        running = false
    }

    func isConnected() -> Bool {
        return webSocket.state == .running
    }

    func setupWebsocket() {
        reconnectTimer?.invalidate()
        let session = URLSession(configuration: .default,
                                 delegate: self,
                                 delegateQueue: OperationQueue.main)
        webSocket = session.webSocketTask(with: url)
        webSocket.resume()
        readMessage()
    }

    func handleResponse(message: String) throws {
        _ = try decodeResponse(message: message)
    }

    func handleChatMessageEvent(data: String) throws {
        let message = try decodeChatMessage(data: data)
        let messageNoEmote = removeEmote(message: message.content)
        model.appendChatMessage(user: message.sender.username, message: messageNoEmote)
    }

    func handleStringMessage(message: String) {
        do {
            let (type, data) = try decodeEvent(message: message)
            if type == "App\\Events\\ChatMessageEvent" {
                try handleChatMessageEvent(data: data)
            } else {
                logger.debug("kick: pusher: \(channelId): Unsupported type: \(type)")
            }
        } catch {
            logger
                .error(
                    "kick: pusher: \(channelId): Failed to process message \"\(message)\" with error \(error)"
                )
        }
    }

    func reconnect() {
        webSocket.cancel()
        reconnectTimer?.invalidate()
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.warning("kick: pusher: \(self.channelId): Reconnecting")
                self.setupWebsocket()
                self.reconnectTime = nextReconnectTime(self.reconnectTime)
            }
    }

    func readMessage() {
        webSocket.receive { result in
            switch result {
            case .failure:
                self.reconnect()
                return
            case let .success(message):
                switch message {
                case let .string(text):
                    self.handleStringMessage(message: text)
                case let .data(data):
                    logger
                        .error(
                            "kick: pusher: \(self.channelId): Received binary message: \(data)"
                        )
                @unknown default:
                    logger
                        .warning(
                            "kick: pusher: \(self.channelId): Unknown message type"
                        )
                }
                self.readMessage()
            }
        }
    }

    func sendMessage(message: String) {
        logger.debug("kick: pusher: \(channelId): Sending \(message)")
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocket.send(message) { error in
            if let error {
                logger
                    .error(
                        "kick: pusher: \(self.channelId): Failed to send message to server with error \(error)"
                    )
                self.reconnect()
            }
        }
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didOpenWithProtocol _: String?
    ) {
        logger.info("kick: pusher: \(channelId): Connected to \(url)")
        reconnectTime = firstReconnectTime
        sendMessage(
            message: """
            {\"event\":\"pusher:subscribe\",
             \"data\":{\"auth\":\"\",\"channel\":\"chatrooms.\(channelId).v2\"}}
            """
        )
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        logger
            .warning(
                """
                kick: pusher: \(channelId): Disconnected from server with close \
                code \(closeCode) and reason \(String(describing: reason))
                """
            )
        reconnect()
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didCompleteWithError _: Error?
    ) {
        if running {
            logger.info("kick: pusher: \(channelId): Completed")
            reconnect()
        } else {
            logger.info("kick: pusher: \(channelId): Completed by us")
        }
    }
}
