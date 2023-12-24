import SwiftUI

struct StreamWizardNetworkSetupDirectSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var ingestError = ""

    private func nextDisabled() -> Bool {
        return model.wizardDirectIngest.isEmpty || model.wizardDirectStreamKey.isEmpty || !ingestError.isEmpty
    }

    private func twitchStreamKeyUrl() -> String {
        return "https://dashboard.twitch.tv/u/\(model.wizardTwitchChannelName.trim())/settings/stream"
    }

    private func updateIngestError() {
        let url = cleanUrl(url: model.wizardDirectIngest)
        if url.isEmpty {
            ingestError = ""
        } else {
            ingestError = isValidUrl(url: url) ?? ""
        }
    }

    var body: some View {
        Form {
            if model.wizardPlatform == .twitch {
                Section {
                    TextField("rtmp://arn03.contribute.live-video.net/app", text: $model.wizardDirectIngest)
                        .disableAutocorrection(true)
                        .onSubmit {
                            updateIngestError()
                        }
                } header: {
                    Text("Nearby ingest endpoint")
                } footer: {
                    VStack(alignment: .leading) {
                        FormFieldError(error: ingestError)
                        Text("""
                        Copy from \
                        https://help.twitch.tv/s/twitch-ingest-recommendation. Remove {stream_key}.
                        """)
                    }
                }
                Section {
                    TextField(
                        "live_48950233_okF4f455GRWEF443fFr23GRbt5rEv",
                        text: $model.wizardDirectStreamKey
                    )
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    HStack(spacing: 0) {
                        Text("Copy from ")
                        Link(twitchStreamKeyUrl(), destination: URL(string: twitchStreamKeyUrl())!)
                            .font(.footnote)
                        Text(" (requires login).")
                    }
                }
            } else if model.wizardPlatform == .kick {
                Section {
                    TextField(
                        "rtmps://fa723fc1b171.global-contribute.live-video.net",
                        text: $model.wizardDirectIngest
                    )
                    .disableAutocorrection(true)
                    .onSubmit {
                        updateIngestError()
                    }
                } header: {
                    Text("Stream URL")
                } footer: {
                    VStack(alignment: .leading) {
                        FormFieldError(error: ingestError)
                        Text(
                            "Copy from https://kick.com/dashboard/settings/stream (requires login)."
                        )
                    }
                }
                Section {
                    TextField(
                        "sk_us-west-2_okfef49k34k_34g59gGDDHGHSREj754gYJYTJERH",
                        text: $model.wizardDirectStreamKey
                    )
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    Text(
                        "Copy from https://kick.com/dashboard/settings/stream (requires login)."
                    )
                }
            }
            Section {
                NavigationLink(destination: StreamWizardGeneralSettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .direct
        }
        .navigationTitle("Direct")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}