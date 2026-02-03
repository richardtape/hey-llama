import SwiftUI

struct SkillsSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var config: AssistantConfig
    @State private var saveError: String?
    @State private var permissionStatuses: [SkillPermission: Permissions.PermissionStatus] = [:]

    private let configStore: ConfigStore
    private let skillsRegistry = SkillsRegistry()
    private let permissionManager = SkillPermissionManager()

    init() {
        let store = ConfigStore()
        self.configStore = store
        self._config = State(initialValue: store.loadConfig())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Skills allow the assistant to perform actions like checking weather or adding reminders. Enable the skills you want to use.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                // Error message if save failed
                if let error = saveError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                // Skills list
                ForEach(skillsRegistry.allSkills, id: \.id) { skill in
                    SkillRow(
                        skill: skill,
                        isEnabled: config.skills.enabledSkillIds.contains(skill.id),
                        permissionStatuses: permissionStatuses,
                        permissionManager: permissionManager,
                        onToggle: { enabled in
                            toggleSkill(skill.id, enabled: enabled)
                        },
                        onPermissionUpdate: { permission, status in
                            permissionStatuses[permission] = status
                        }
                    )
                }
            }
            .padding(16)
        }
        .task {
            await loadPermissionStatuses()
        }
    }

    private func loadPermissionStatuses() async {
        for permission in SkillPermission.allCases {
            let status = await permissionManager.checkPermissionStatus(permission)
            await MainActor.run {
                permissionStatuses[permission] = status
            }
        }
    }

    private func toggleSkill(_ skillId: String, enabled: Bool) {
        // Update local state
        if enabled {
            if !config.skills.enabledSkillIds.contains(skillId) {
                config.skills.enabledSkillIds.append(skillId)
            }
        } else {
            config.skills.enabledSkillIds.removeAll { $0 == skillId }
        }

        // Auto-save
        saveError = nil
        do {
            try configStore.saveConfig(config)
            Task {
                await appState.reloadConfig()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Skill Row

struct SkillRow: View {
    let skill: RegisteredSkill
    let isEnabled: Bool
    let permissionStatuses: [SkillPermission: Permissions.PermissionStatus]
    let permissionManager: SkillPermissionManager
    let onToggle: (Bool) -> Void
    let onPermissionUpdate: (SkillPermission, Permissions.PermissionStatus) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skill.name)
                            .font(.headline)

                        Text(skill.skillDescription)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { newValue in
                            if newValue {
                                // Request permissions before enabling
                                requestPermissionsIfNeeded()
                            }
                            onToggle(newValue)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                // Permission indicators
                if !skill.requiredPermissions.isEmpty {
                    Divider()

                    HStack(spacing: 12) {
                        Text("Requires:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(skill.requiredPermissions, id: \.rawValue) { permission in
                            PermissionBadge(
                                permission: permission,
                                status: permissionStatuses[permission] ?? .undetermined
                            )
                        }

                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func requestPermissionsIfNeeded() {
        Task {
            for permission in skill.requiredPermissions {
                let currentStatus = await permissionManager.checkPermissionStatus(permission)
                if currentStatus == .undetermined {
                    let granted = await permissionManager.requestPermission(permission)
                    let newStatus: Permissions.PermissionStatus = granted ? .granted : .denied
                    await MainActor.run {
                        onPermissionUpdate(permission, newStatus)
                    }
                }
            }
        }
    }
}

// MARK: - Permission Badge

struct PermissionBadge: View {
    let permission: SkillPermission
    let status: Permissions.PermissionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)

            Text(permission.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(4)
        .onTapGesture {
            if status == .denied {
                Permissions.openSystemSettingsForPermission(permission)
            }
        }
        .help(helpText)
    }

    private var statusIcon: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .undetermined:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        }
    }

    private var helpText: String {
        switch status {
        case .granted:
            return "\(permission.displayName) permission granted"
        case .denied:
            return "Click to open System Settings and grant \(permission.displayName) permission"
        case .undetermined:
            return "\(permission.displayName) permission not yet requested"
        }
    }
}

#Preview {
    SkillsSettingsView()
        .environmentObject(AppState())
        .frame(width: 480, height: 400)
}
