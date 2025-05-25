# macOS Permissions Resetting on Rebuild (TCC Issues)

## The Problem

When developing macOS applications that require special permissions – such as Accessibility, Screen Recording, Input Monitoring, etc. (managed by macOS's Transparency, Consent, and Control - TCC framework) – you might notice that these permissions are reset every time you rebuild the application from Xcode or via a script.

This happens because TCC permissions are tied to the application's **code signature hash**. 

By default, for debug builds, Xcode often uses an "automatic ad-hoc" signing method. This means that each time you build, a new, unique ad-hoc signature is generated. Consequently, macOS sees the newly built app as a *completely different application* from the one that was previously granted permissions, and therefore, it revokes the permissions.

This leads to the extremely inconvenient workflow of having to re-grant these permissions in System Settings after almost every build.

## The Solution: Stable Debug Signing

The most effective way to solve this is to sign your debug builds with a **stable development certificate** instead of an ad-hoc one. By using your Apple Development certificate, the code signature hash will remain consistent across rebuilds (as long as the bundle ID and team don't change).

This tells macOS that it's still the same application, just a new version, and it will retain the TCC permissions you've already granted.

### How to Implement

#### 1. In Xcode (Manual Setup Reference)

If you were configuring this directly in Xcode, you would:
1.  Go to your **Target** settings.
2.  Navigate to **Signing & Capabilities**.
3.  Select your **Team** (e.g., "Peter Steinberger").
4.  Ensure "Automatically manage signing" is checked.
5.  For the **Signing Certificate** field, ensure it's set to your development certificate (e.g., "Apple Development: Your Name (TEAM_ID)") for the **Debug** configuration. You might need to expand build settings or check different configuration levels to ensure this applies specifically to Debug.

#### 2. With Tuist (Project Automation)

Since this project uses Tuist, these settings need to be configured in the `Project.swift` file. This involves specifying the development team and ensuring that debug builds use the appropriate Apple Development certificate. This will be updated in the project's `Project.swift`.

By implementing this, you should find that TCC permissions persist across your debug builds, significantly streamlining your development workflow. 