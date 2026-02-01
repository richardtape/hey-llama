# Milestone 0: Project Setup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the HeyLlama Xcode project as a menu bar application with all dependencies configured and project structure in place.

**Architecture:** SwiftUI menu bar app using MenuBarExtra scene. No dock icon (LSUIElement). AppDelegate handles lifecycle and permissions. Project structure follows the spec with groups for App, UI, Core, Services, Models, Storage, and Utilities.

**Tech Stack:** Swift 5.9+, SwiftUI, macOS 14+, xcodegen (for project generation), SPM dependencies (WhisperKit, FluidAudio)

---

## Pre-Flight Checks

Before starting, verify prerequisites:

```bash
# Check Xcode version (need 15+)
xcodebuild -version

# Check if xcodegen is installed (install if missing)
which xcodegen || brew install xcodegen
```

---

### Task 1: Initialize Git Repository

**Files:**
- Create: `.gitignore`

**Step 1: Initialize git repo**

Run: `git init`
Expected: `Initialized empty Git repository`

**Step 2: Create .gitignore**

```gitignore
# Xcode
build/
DerivedData/
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
*.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist

# Swift Package Manager
.build/
.swiftpm/

# macOS
.DS_Store
*.swp
*~

# App-specific
*.xcuserstate
```

**Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

### Task 2: Create Project Directory Structure

**Files:**
- Create directories under `HeyLlama/`

**Step 1: Create all directories**

Run:
```bash
mkdir -p HeyLlama/App
mkdir -p HeyLlama/UI/MenuBar
mkdir -p HeyLlama/UI/Settings
mkdir -p HeyLlama/UI/Enrollment
mkdir -p HeyLlama/UI/Components
mkdir -p HeyLlama/Core
mkdir -p HeyLlama/Services/Audio
mkdir -p HeyLlama/Services/Speech
mkdir -p HeyLlama/Services/Speaker
mkdir -p HeyLlama/Services/LLM
mkdir -p HeyLlama/Services/TTS
mkdir -p HeyLlama/Services/API
mkdir -p HeyLlama/Models
mkdir -p HeyLlama/Storage
mkdir -p HeyLlama/Utilities
mkdir -p HeyLlama/Resources
mkdir -p HeyLlamaTests/Mocks
```

**Step 2: Verify structure**

Run: `find HeyLlama HeyLlamaTests -type d | head -30`
Expected: All directories listed

---

### Task 3: Create App Entry Point

**Files:**
- Create: `HeyLlama/App/HeyLlamaApp.swift`

**Step 1: Write the app entry point**

```swift
import SwiftUI

@main
struct HeyLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar presence
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "waveform")
        }

        // Settings window (opened via Preferences menu item)
        Settings {
            SettingsView()
        }

        // Enrollment window (opens on demand)
        Window("Speaker Enrollment", id: "enrollment") {
            EnrollmentView()
        }
    }
}
```

---

### Task 4: Create AppDelegate

**Files:**
- Create: `HeyLlama/App/AppDelegate.swift`

**Step 1: Write the app delegate**

```swift
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Request permissions on launch
        Task {
            await requestMicrophonePermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup placeholder - will be implemented in later milestones
    }

    private func requestMicrophonePermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            // User denied - they'll need to enable in System Settings
            print("Microphone permission denied")
        }
    }
}
```

---

### Task 5: Create MenuBarView

**Files:**
- Create: `HeyLlama/UI/MenuBar/MenuBarView.swift`

**Step 1: Write the menu bar view**

```swift
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // App info
            Text("Hey Llama")
                .font(.headline)
            Text("v0.1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Status (placeholder - will be dynamic in M1)
            HStack {
                Image(systemName: "waveform")
                Text("Idle")
            }
            .foregroundColor(.secondary)

            Divider()

            // Preferences
            SettingsLink {
                Text("Preferences...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
        .frame(width: 200)
    }
}

#Preview {
    MenuBarView()
}
```

---

### Task 6: Create Placeholder SettingsView

**Files:**
- Create: `HeyLlama/UI/Settings/SettingsView.swift`

**Step 1: Write the settings view placeholder**

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            Text("Audio settings coming in Milestone 1")
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            Text("Speakers settings coming in Milestone 3")
                .tabItem {
                    Label("Speakers", systemImage: "person.2")
                }

            Text("API settings coming in Milestone 5")
                .tabItem {
                    Label("API", systemImage: "network")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General settings will be added in Milestone 6")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
```

---

### Task 7: Create Placeholder EnrollmentView

**Files:**
- Create: `HeyLlama/UI/Enrollment/EnrollmentView.swift`

**Step 1: Write the enrollment view placeholder**

```swift
import SwiftUI

struct EnrollmentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Speaker Enrollment")
                .font(.title)

            Text("Speaker enrollment will be implemented in Milestone 3")
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

#Preview {
    EnrollmentView()
}
```

---

### Task 8: Create Asset Catalog

**Files:**
- Create: `HeyLlama/Resources/Assets.xcassets/Contents.json`
- Create: `HeyLlama/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `HeyLlama/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Step 1: Create Assets.xcassets structure**

Run:
```bash
mkdir -p HeyLlama/Resources/Assets.xcassets/AccentColor.colorset
mkdir -p HeyLlama/Resources/Assets.xcassets/AppIcon.appiconset
```

**Step 2: Write Assets.xcassets/Contents.json**

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 3: Write AccentColor.colorset/Contents.json**

```json
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 4: Write AppIcon.appiconset/Contents.json**

```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

---

### Task 9: Create Entitlements File

**Files:**
- Create: `HeyLlama/HeyLlama.entitlements`

**Step 1: Write entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

Note: Sandbox is disabled for development. For App Store distribution, enable sandbox and configure appropriately.

---

### Task 10: Create Info.plist

**Files:**
- Create: `HeyLlama/Info.plist`

**Step 1: Write Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Hey Llama needs microphone access to listen for voice commands.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

---

### Task 11: Create xcodegen Project Spec

**Files:**
- Create: `project.yml`

**Step 1: Write xcodegen spec**

```yaml
name: HeyLlama
options:
  bundleIdPrefix: com.heyllama
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    SWIFT_STRICT_CONCURRENCY: complete
    MACOSX_DEPLOYMENT_TARGET: "14.0"

packages:
  WhisperKit:
    url: https://github.com/argmaxinc/WhisperKit.git
    from: "0.9.0"
  FluidAudio:
    url: https://github.com/FluidInference/FluidAudio.git
    from: "0.10.0"

targets:
  HeyLlama:
    type: application
    platform: macOS
    sources:
      - path: HeyLlama
        excludes:
          - "**/*.entitlements"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.heyllama.HeyLlama
        INFOPLIST_FILE: HeyLlama/Info.plist
        CODE_SIGN_ENTITLEMENTS: HeyLlama/HeyLlama.entitlements
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: ""
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    dependencies:
      - package: WhisperKit
      - package: FluidAudio
    entitlements:
      path: HeyLlama/HeyLlama.entitlements

  HeyLlamaTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: HeyLlamaTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.heyllama.HeyLlamaTests
    dependencies:
      - target: HeyLlama
```

---

### Task 12: Create Test Placeholder

**Files:**
- Create: `HeyLlamaTests/HeyLlamaTests.swift`

**Step 1: Write test placeholder**

```swift
import XCTest
@testable import HeyLlama

final class HeyLlamaTests: XCTestCase {

    func testPlaceholder() throws {
        // Placeholder test to verify test target builds
        // Real tests will be added in subsequent milestones
        XCTAssertTrue(true, "Test infrastructure is working")
    }
}
```

---

### Task 13: Generate Xcode Project

**Step 1: Verify xcodegen is installed**

Run: `which xcodegen`
Expected: Path to xcodegen (e.g., `/opt/homebrew/bin/xcodegen`)

If not installed:
Run: `brew install xcodegen`

**Step 2: Generate the project**

Run: `xcodegen generate`
Expected:
```
Loaded project:
  Name: HeyLlama
  Targets:
    HeyLlama: application
    HeyLlamaTests: bundle.unit-test
Generated project at HeyLlama.xcodeproj
```

**Step 3: Verify project was created**

Run: `ls -la *.xcodeproj`
Expected: `HeyLlama.xcodeproj` directory exists

---

### Task 14: Resolve Package Dependencies

**Step 1: Resolve SPM packages**

Run: `xcodebuild -resolvePackageDependencies -project HeyLlama.xcodeproj -scheme HeyLlama`
Expected: Packages download and resolve successfully (may show warnings, but no errors)

Note: This step may take several minutes as WhisperKit and FluidAudio download.

---

### Task 15: Build Verification

**Step 1: Build the app**

Run: `xcodebuild build -project HeyLlama.xcodeproj -scheme HeyLlama -configuration Debug | tail -20`
Expected: `BUILD SUCCEEDED` at the end

**Step 2: Build the test target**

Run: `xcodebuild build-for-testing -project HeyLlama.xcodeproj -scheme HeyLlama -configuration Debug | tail -20`
Expected: `BUILD SUCCEEDED`

---

### Task 16: Runtime Verification

**Step 1: Run the app**

Run: `open HeyLlama.xcodeproj`
Then in Xcode: Product > Run (or Cmd+R)

**Step 2: Manual verification checklist**

- [ ] App launches without crash
- [ ] Menu bar icon appears (waveform icon)
- [ ] No dock icon appears (LSUIElement working)
- [ ] Click menu bar icon - dropdown appears with:
  - [ ] "Hey Llama" header with version
  - [ ] "Idle" status
  - [ ] "Preferences..." menu item
  - [ ] "Quit" menu item
- [ ] Click "Preferences..." - Settings window opens
- [ ] Click "Quit" - App terminates cleanly

---

### Task 17: Dependency Import Verification

**Files:**
- Create: `HeyLlamaTests/DependencyImportTests.swift`

**Step 1: Write import verification tests**

```swift
import XCTest
import WhisperKit
import FluidAudio
@testable import HeyLlama

final class DependencyImportTests: XCTestCase {

    func testWhisperKitImports() throws {
        // If this compiles, WhisperKit is properly linked
        XCTAssertTrue(true, "WhisperKit imports successfully")
    }

    func testFluidAudioImports() throws {
        // If this compiles, FluidAudio is properly linked
        XCTAssertTrue(true, "FluidAudio imports successfully")
    }
}
```

**Step 2: Run tests**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -destination 'platform=macOS' | grep -E "(Test Case|passed|failed)"`
Expected: All tests pass

---

### Task 18: Final Commit

**Step 1: Stage all files**

Run: `git status`
Review the list of files to be committed.

**Step 2: Commit**

```bash
git add .
git commit -m "Milestone 0: Project setup with menu bar app shell

- Create HeyLlama Xcode project with SwiftUI
- Configure as menu bar app (LSUIElement)
- Add WhisperKit and FluidAudio dependencies via SPM
- Set up project group structure per spec
- Implement HeyLlamaApp with MenuBarExtra, Settings, Window scenes
- Implement AppDelegate with accessory activation policy
- Implement basic MenuBarView with Quit/Preferences
- Configure entitlements for mic and network
- Add placeholder Settings and Enrollment views
- Add test target with import verification tests

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Verification Summary

After completing all tasks, verify:

| Check | Command/Action | Expected |
|-------|----------------|----------|
| Build succeeds | `xcodebuild build -scheme HeyLlama` | BUILD SUCCEEDED |
| Tests pass | `xcodebuild test -scheme HeyLlama` | All tests pass |
| App launches | Run from Xcode | No crash |
| Menu bar icon | Visual check | Waveform icon visible |
| No dock icon | Visual check | No icon in dock |
| Menu dropdown | Click menu bar icon | Shows menu items |
| Preferences | Click "Preferences..." | Settings window opens |
| Quit | Click "Quit" | App terminates |

---

## Next Steps

After completing this milestone:
1. Update `docs/milestones/00-project-setup.md` - check off completed items
2. Proceed to [Milestone 1: Audio Foundation](../milestones/01-audio-foundation.md)
