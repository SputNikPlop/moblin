import SwiftUI

struct StreamWizardNetworkSetupBelaboxSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return model.wizardBelaboxUrl.trim().isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: model.wizardBelaboxUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["srt", "srtla"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    "srtla://uk.srt.belabox.net:5000?streamid=jO4ijfFgrlpv4m2375msdoG3DDr2",
                    text: $model.wizardBelaboxUrl
                )
                .disableAutocorrection(true)
                .onSubmit {
                    updateUrlError()
                }
            } header: {
                Text("Ingest URL")
            } footer: {
                VStack(alignment: .leading) {
                    FormFieldError(error: urlError)
                    Text("""
                    Copy from https://cloud.belabox.net SRT(LA) relays (requires login). \
                    See image below for example. Replace srt:// with srtla:// and change port \
                    to use SRTLA instead of SRT.
                    """)
                }
            }
            Section {
                HStack {
                    Spacer()
                    Image("BelaboxCloudIngest")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Spacer()
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
            model.wizardNetworkSetup = .belaboxCloudObs
        }
        .navigationTitle("BELABOX cloud and OBS")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}