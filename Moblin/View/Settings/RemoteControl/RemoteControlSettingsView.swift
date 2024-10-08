import SwiftUI

private struct InterfaceView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var image: String
    var ip: String

    private func streamUrl() -> String {
        return "ws://\(ip):\(port)"
    }

    var body: some View {
        HStack {
            Image(systemName: image)
            Text(streamUrl())
            Spacer()
            Button(action: {
                UIPasteboard.general.string = streamUrl()
                model.makeToast(title: "URL copied to clipboard")
            }, label: {
                Image(systemName: "doc.on.doc")
            })
        }
    }
}

private struct PasswordView: View {
    @EnvironmentObject var model: Model
    @State var value: String
    var onSubmit: (String) -> Void
    @State private var changed = false
    @State private var submitted = false
    @State private var message: String?

    private func submit() {
        value = value.trim()
        if isGoodPassword(password: value) {
            submitted = true
            onSubmit(value)
        }
    }

    private func createMessage() -> String? {
        if isGoodPassword(password: value) {
            return nil
        } else {
            return "Not long and random enough"
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("", text: $value)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onChange(of: value) { _ in
                            changed = true
                            message = createMessage()
                        }
                        .onSubmit {
                            submit()
                        }
                        .submitLabel(.done)
                        .onDisappear {
                            if changed && !submitted {
                                submit()
                            }
                        }
                    Button {
                        UIPasteboard.general.string = value
                        model.makeToast(title: "Password copied to clipboard")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            } footer: {
                if let message {
                    Text(message)
                        .foregroundColor(.red)
                        .bold()
                }
            }
            Section {
                Button {
                    value = randomGoodPassword()
                    submit()
                } label: {
                    HStack {
                        Spacer()
                        Text("Generate")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Password")
    }
}

struct RemoteControlSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitPassword(value: String) {
        model.database.remoteControl!.password = value.trim()
        model.reloadRemoteControlStreamer()
        model.reloadRemoteControlAssistant()
    }

    private func submitStreamerUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        model.database.remoteControl!.server.url = value
        model.reloadRemoteControlStreamer()
    }

    private func submitStreamerPreviewFps(value: Float) {
        model.database.remoteControl!.server.previewFps = value
        model.setLowFpsImage()
    }

    private func formatStreamerPreviewFps(value: Float) -> String {
        return String(Int(value))
    }

    private func submitAssistantPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.remoteControl!.client.port = port
        model.reloadRemoteControlAssistant()
    }

    var body: some View {
        Form {
            Section {
                Text("Control and monitor Moblin from another device.")
            }
            Section {
                NavigationLink(destination: PasswordView(
                    value: model.database.remoteControl!.password!,
                    onSubmit: submitPassword
                )) {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.remoteControl!.password!,
                        sensitive: true
                    )
                }
            } footer: {
                Text("Used by both streamer and assistant.")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.remoteControl!.server.enabled
                }, set: { value in
                    model.database.remoteControl!.server.enabled = value
                    model.reloadRemoteControlStreamer()
                })) {
                    Text("Enabled")
                }
                TextEditNavigationView(
                    title: String(localized: "Assistant URL"),
                    value: model.database.remoteControl!.server.url,
                    onSubmit: submitStreamerUrl,
                    footers: [
                        String(
                            localized: "Enter assistant's address and port. For example ws://132.23.43.43:2345."
                        ),
                    ],
                    keyboardType: .URL,
                    placeholder: "ws://32.143.32.12:2345"
                )
                HStack {
                    Text("Preview FPS")
                    SliderView(
                        value: model.database.remoteControl!.server.previewFps!,
                        minimum: 1,
                        maximum: 5,
                        step: 1,
                        onSubmit: submitStreamerPreviewFps,
                        width: 20,
                        format: formatStreamerPreviewFps
                    )
                }
            } header: {
                Text("Streamer")
            } footer: {
                Text("""
                Enable to allow an assistant to monitor and control this device from a \
                different device.
                """)
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.remoteControl!.client.enabled
                }, set: { value in
                    model.database.remoteControl!.client.enabled = value
                    model.reloadRemoteControlAssistant()
                })) {
                    Text("Enabled")
                }
                TextEditNavigationView(
                    title: String(localized: "Server port"),
                    value: String(model.database.remoteControl!.client.port),
                    onSubmit: submitAssistantPort,
                    keyboardType: .numbersAndPunctuation,
                    placeholder: "2345"
                )
            } header: {
                Text("Assistant")
            } footer: {
                Text("""
                Enable to let a streamer device connect to this device. Once connected, \
                this device can monitor and control the streamer device.
                """)
            }
            if model.database.remoteControl!.client.enabled {
                Section {
                    List {
                        ForEach(model.ipStatuses, id: \.name) { status in
                            InterfaceView(
                                port: model.database.remoteControl!.client.port,
                                image: urlImage(interfaceType: status.interfaceType),
                                ip: status.ip
                            )
                        }
                        InterfaceView(
                            port: model.database.remoteControl!.client.port,
                            image: "personalhotspot",
                            ip: personalHotspotLocalAddress
                        )
                    }
                } footer: {
                    VStack(alignment: .leading) {
                        Text("""
                        Enter one of the URLs as "Assistant URL" in the streamer device to \
                        connect to this device.
                        """)
                    }
                }
            }
        }
        .navigationTitle("Remote control")
    }
}
