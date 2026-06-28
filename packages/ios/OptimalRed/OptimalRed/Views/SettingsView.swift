import SwiftUI
import CloudKit

struct SettingsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
  @StateObject private var ckSync = CloudKitSyncService.shared

  var body: some View {
    NavigationStack {
      List {
        Section("Watch") {
          LabeledContent("Status") {
            HStack(spacing: 6) {
              Circle()
                .fill(watchConnectivityManager.isConnected ? Color.green : Color(.systemGray3))
                .frame(width: 8, height: 8)
              Text(watchConnectivityManager.isConnected ? "Connected" : "Disconnected")
                .foregroundStyle(watchConnectivityManager.isConnected ? .primary : .secondary)
                .font(.subheadline)
            }
          }
          .listRowBackground(Color(white: 0.12))
        }

        Section("iCloud Sync") {
          LabeledContent("iCloud Account") {
            Text(ckSync.accountStatus.label)
              .foregroundStyle(ckSync.accountStatus == .available ? .green : .red)
              .font(.subheadline)
          }

          if let last = ckSync.lastSyncDate {
            LabeledContent("Last Sync") {
              Text(last.formatted(.relative(presentation: .named)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }

          if ckSync.isSyncing {
            LabeledContent("Syncing…") {
              ProgressView(value: ckSync.syncProgress)
                .frame(width: 100)
            }
          } else {
            Button {
              ckSync.sync()
            } label: {
              Label("Sync Workouts to iCloud", systemImage: "icloud.and.arrow.up")
            }
            .disabled(ckSync.accountStatus != .available)
          }

          if let error = ckSync.syncError {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }
        .listRowBackground(Color(white: 0.12))

        Section("Health Data") {
          LabeledContent("HealthKit Access") {
            Text(healthKitManager.isAuthorized ? "Granted" : "Not granted")
              .foregroundStyle(healthKitManager.isAuthorized ? .green : .red)
              .font(.subheadline)
          }
          .listRowBackground(Color(white: 0.12))
        }

        Section("About") {
          LabeledContent("Version", value: "1.0")
          LabeledContent("Build", value: "16")
        }
        .listRowBackground(Color(white: 0.12))
      }
      .scrollContentBackground(.hidden)
      .background(Color.black)
      .navigationTitle("Settings")
      .toolbarBackground(.black, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .onAppear { ckSync.checkAccount() }
    }
    .background(Color.black)
  }
}

extension CKAccountStatus {
  var label: String {
    switch self {
    case .available:              return "Signed In"
    case .noAccount:              return "No Account"
    case .restricted:             return "Restricted"
    case .couldNotDetermine:      return "Unknown"
    case .temporarilyUnavailable: return "Temporarily Unavailable"
    @unknown default:             return "Unknown"
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(HealthKitManager())
    .environmentObject(WatchConnectivityManager())
}
