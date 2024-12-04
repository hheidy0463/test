import SwiftUI
import FamilyControls

@main
struct ScreenTimeApp: App {
    
    let center = AuthorizationCenter.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    do {
                        try await center.requestAuthorization(for: .individual)
                    } catch {
                        print("Failed to get authorization: \(error)")
                    }
                }
        }
    }
}

import SwiftUI
import FamilyControls
import ManagedSettings

class ShieldManager: ObservableObject {
    @Published var discouragedSelections = FamilyActivitySelection()
    
    private let store = ManagedSettingsStore()
    
    func shieldActivities() {
        // Clear to reset previous settings
        store.clearAllSettings()
                     
        let applications = discouragedSelections.applicationTokens
        let categories = discouragedSelections.categoryTokens
        
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }
}

import SwiftUI
import FamilyControls

struct ShieldView: View {
    
    @StateObject private var manager = ShieldManager()
    @State private var showActivityPicker = false
    
    var body: some View {
        VStack {
            Button {
                showActivityPicker = true
            } label: {
                Label("Configure activities", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            Button("Apply Shielding") {
                manager.shieldActivities()
            }
            .buttonStyle(.bordered)
        }
        .familyActivityPicker(isPresented: $showActivityPicker, selection: $manager.discouragedSelections)
    }
}

**import Foundation
import ManagedSettings

struct ApplicationProfile: Codable, Hashable {
    let id: UUID
    let applicationToken: ApplicationToken
    
    init(id: UUID = UUID(), applicationToken: ApplicationToken) {
        self.applicationToken = applicationToken
        self.id = id
    }
}**

import Foundation

struct DataBase {
    private let defaults = UserDefaults(suiteName: "group.com.pedro.ScreenTimeApp.data")
    private let applicationProfileKey = "ApplicationProfile"
    
    func getApplicationProfiles() -> [UUID: ApplicationProfile] {
        guard let data = defaults?.data(forKey: applicationProfileKey) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([UUID: ApplicationProfile].self, from: data) else { return [:] }
        return decoded
    }
    
    func getApplicationProfile(id: UUID) -> ApplicationProfile? {
        return getApplicationProfiles()[id]
    }
    
    func addApplicationProfile(_ application: ApplicationProfile) {
        var applications = getApplicationProfiles()
        applications.updateValue(application, forKey: application.id)
        saveApplicationProfiles(applications)
    }
    
    func saveApplicationProfiles(_ applications: [UUID: ApplicationProfile]) {
        guard let encoded = try? JSONEncoder().encode(applications) else { return }
        defaults?.set(encoded, forKey: applicationProfileKey)
    }
    
    func removeApplicationProfile(_ application: ApplicationProfile) {
        var applications = getApplicationProfiles()
        applications.removeValue(forKey: application.id)
        saveApplicationProfiles(applications)
    }
}

override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the shield as needed for applications.
        ShieldConfiguration(
            backgroundColor: .systemCyan,
            title: ShieldConfiguration.Label(text: "Do you really need to use this app?", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Like are you sure?", color: .systemBrown),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Unlock", color: .label),
            primaryButtonBackgroundColor: .systemGreen,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Don't unlock.", color: .label)
        )
    }

import ManagedSettings
import DeviceActivity
import Foundation

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    
    var applicationProfile: ApplicationProfile!
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        switch action {
        case .primaryButtonPressed:
            createApplicationProfile(for: application)
            startMonitoring()
            unlockApp()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            fatalError()
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
    
    func createApplicationProfile(for application: ApplicationToken) {
        applicationProfile = ApplicationProfile(applicationToken: application)
        let dataBase = DataBase()
        dataBase.addApplicationProfile(applicationProfile)
    }
    
		// Start a device activity for this particular application
    func startMonitoring() {
        let unlockTime = 2
        let event: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name(applicationProfile.id.uuidString) : DeviceActivityEvent(
                applications: Set<ApplicationToken>([applicationProfile.applicationToken]),
                threshold: DateComponents(minute: unlockTime)
            )
        ]
        
        let intervalEnd = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: Calendar.current.date(byAdding: .minute, value: unlockTime, to: Date.now) ?? Date.now
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: intervalEnd,
            repeats: false
        )
         
        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(DeviceActivityName(applicationProfile.id.uuidString), during: schedule, events: event)
        } catch {
            print("Error monitoring schedule: \(error)")
        }
    }
    
		// remove the shield of this application
    func unlockApp() {
        let store = ManagedSettingsStore()
        store.shield.applications?.remove(applicationProfile.applicationToken)
    }
}

import DeviceActivity
import Foundation
import ManagedSettings

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Handle the end of the interval.
        let database = DataBase()
        guard let activityId = UUID(uuidString: activity.rawValue) else { return }
        guard let application = database.getApplicationProfile(id: activityId) else { return }
        let store = ManagedSettingsStore()
        store.shield.applications?.insert(application.applicationToken)
        database.removeApplicationProfile(application)
    }
}