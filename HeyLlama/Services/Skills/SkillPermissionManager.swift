import Foundation

/// Manages permission checking and requesting for skills
actor SkillPermissionManager {

    /// Check the status of a specific permission
    func checkPermissionStatus(_ permission: SkillPermission) async -> Permissions.PermissionStatus {
        switch permission {
        case .reminders:
            let status = Permissions.checkRemindersStatus()
            print("[Permissions] \(permission.rawValue) status: \(status)")
            return status
        case .location:
            let status = await MainActor.run { Permissions.checkLocationStatus() }
            print("[Permissions] \(permission.rawValue) status: \(status)")
            return status
        }
    }

    /// Request a specific permission
    func requestPermission(_ permission: SkillPermission) async -> Bool {
        switch permission {
        case .reminders:
            let granted = await Permissions.requestRemindersAccess()
            print("[Permissions] \(permission.rawValue) request result: \(granted)")
            return granted
        case .location:
            let granted = await Permissions.requestLocationAccess()
            print("[Permissions] \(permission.rawValue) request result: \(granted)")
            return granted
        }
    }

    /// Check if all required permissions for a skill are granted
    func hasAllPermissions(for skill: RegisteredSkill) async -> Bool {
        for permission in skill.requiredPermissions {
            let status = await checkPermissionStatus(permission)
            if status != .granted {
                return false
            }
        }
        return true
    }

    /// Check all permissions from an array, returns true if all granted or array is empty
    func checkAllPermissions(forPermissions permissions: [SkillPermission]) async -> Bool {
        if permissions.isEmpty {
            return true
        }
        for permission in permissions {
            let status = await checkPermissionStatus(permission)
            if status != .granted {
                return false
            }
        }
        return true
    }

    /// Get list of missing permissions for a skill
    func missingPermissions(for skill: RegisteredSkill) async -> [SkillPermission] {
        var missing: [SkillPermission] = []
        for permission in skill.requiredPermissions {
            let status = await checkPermissionStatus(permission)
            if status != .granted {
                missing.append(permission)
            }
        }
        return missing
    }

    /// Request all missing permissions for a skill
    /// Returns true if all permissions were granted
    func requestAllMissingPermissions(for skill: RegisteredSkill) async -> Bool {
        let missing = await missingPermissions(for: skill)

        for permission in missing {
            let granted = await requestPermission(permission)
            if !granted {
                return false
            }
        }

        return true
    }
}
