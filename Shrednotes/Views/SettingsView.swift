import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var visibleTrickTypes: Set<TrickType>
    @State private var notificationAccessGranted: Bool = UserDefaults.standard.bool(forKey: "NotificationAccessGranted")
    @State private var locationAccessGranted: Bool = UserDefaults.standard.bool(forKey: "LocationAccessGranted")
    @AppStorage("HideRecommendations") private var hideRecommendations: Bool = false
    @AppStorage("HideJournal") private var hideJournal: Bool = false
    @State private var showDebug: Bool = false
    @State private var isFetching = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Settings")
                    .fontWidth(.expanded)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.leading)

                List {
                    Section(header: Text("Customisation").fontWeight(.regular).fontWidth(.expanded).textScale(.secondary).textCase(.uppercase)) {
                        Menu {
                            ForEach(TrickType.allCases, id: \.self) { type in
                                Button(action: {
                                    if visibleTrickTypes.contains(type) {
                                        visibleTrickTypes.remove(type)
                                    } else {
                                        visibleTrickTypes.insert(type)
                                    }
                                    saveVisibleTrickTypes()
                                }) {
                                    HStack {
                                        Text(type.displayName)
                                        Spacer()
                                        if visibleTrickTypes.contains(type) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Label("Active Types", systemImage: "list.bullet")
                                Spacer()
                                HStack {
                                    Text("\(visibleTrickTypes.count)")
                                    Image(systemName: "chevron.right")
                                        .imageScale(.small)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                        Toggle(isOn: $hideRecommendations) {
                            Label("Hide Recommendations", systemImage: "sparkles.rectangle.stack")
                        }
                        .tint(.indigo)
                        .onChange(of: hideRecommendations) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "HideRecommendations")
                        }
                        Toggle(isOn: $hideJournal) {
                            Label("Hide Journal", systemImage: "book")
                        }
                        .tint(.indigo)
                        .onChange(of: hideJournal) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "HideJournal")
                        }
                    }
                    .listRowSeparator(.hidden)
                    
                    Section(header: Text("Permissions").fontWeight(.regular).fontWidth(.expanded).textScale(.secondary).textCase(.uppercase)) {
                        Button {
                            if let url = URL(string: "x-apple-health://") {
                                if UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        } label: {
                            HStack {
                                Label("Apple Health Sync", systemImage: "heart")
                                Spacer()
                                HStack {
                                    Text("Update")
                                    Image(systemName: "chevron.right")
                                        .imageScale(.small)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            if notificationAccessGranted, let bundleIdentifier = Bundle.main.bundleIdentifier,
                               let url = URL(string: "app-settings:root=\(bundleIdentifier)") {
                                if UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                } else {
                                    requestNotificationAuthorization()
                                }
                            }
                        } label: {
                            HStack {
                                Label("Manage Notifications", systemImage: "app.badge")
                                Spacer()
                                HStack {
                                    Text("Update")
                                    Image(systemName: "chevron.right")
                                        .imageScale(.small)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            if locationAccessGranted, let bundleIdentifier = Bundle.main.bundleIdentifier,
                               let url = URL(string: "app-settings:root=\(bundleIdentifier)") {
                                if UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                } else {
                                    locationManager.requestLocationAuthorization()
                                }
                            }
                        } label: {
                            HStack {
                                Label("Manage Location", systemImage: "location")
                                Spacer()
                                HStack {
                                    Text("Update")
                                    Image(systemName: "chevron.right")
                                        .imageScale(.small)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    
                    Section(header: Text("Support Shrednotes").fontWeight(.regular).fontWidth(.expanded).textScale(.secondary).textCase(.uppercase)) {
                        Link(destination: URL(string: "https://apps.apple.com/app/id6648789549?action=write-review")!) {
                            Label("Leave a Review", systemImage: "star")
                        }
                        ShareLink(
                            item: "https://apps.apple.com/app/id6648789549",
                            subject: Text("Check out this app!"),
                            message: Text("I wanted to share this link with you."),
                            preview: SharePreview("Shrednotes", image: Image("preview-image"))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .listRowSeparator(.hidden)
                    
                    Section(header: Text("More").fontWeight(.regular).fontWidth(.expanded).textScale(.secondary).textCase(.uppercase)) {
                        Link(destination: URL(string: "https://apps.apple.com/us/developer/karl-koch/id1518887592?itsct=apps_box_link&itscg=30200")!) {
                            Label("My Other Apps", systemImage: "person.crop.rectangle.stack")
                        }
                        Link(destination: URL(string: "mailto:karl+shrednotes@kejk.tech?subject=Feedback%20from%20Shrednotes%20app%20link")!) {
                            Label("Get in Touch", systemImage: "envelope")
                        }
                    }
                    .listRowSeparator(.hidden)
    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("All data is stored on your device and backed up to your iCloud account. No one else has access to it.")
                        Text("Made in the UK")
                    }
                    .textScale(.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .listRowSeparator(.hidden)
                    .onTapGesture(count: 3) {
                        self.showDebug = true
                    }
                }
                .listStyle(.plain)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .tint(.secondary)
                }
            }
        }
    }
    
    private func saveVisibleTrickTypes() {
        let encodedData = try? JSONEncoder().encode(visibleTrickTypes)
        UserDefaults.standard.set(encodedData, forKey: "visibleTrickTypes")
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                notificationAccessGranted = granted
                UserDefaults.standard.set(notificationAccessGranted, forKey: "NotificationAccessGranted")
            }
        }
    }
}
