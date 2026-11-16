# Android port of airControl

This folder is the handoff point for building the Android counterpart of the current native iOS app. The iOS app remains the working product and interaction reference. The React/Capacitor prototype in `../src` and shell in `../android` remain available as a shared-code starting point; neither should be mistaken for a complete Android port.

## How to port a screen

1. Capture the iOS screen and record its states, navigation, and actions in `SCREEN-MAP.md`.
2. Trace each action to its controller and Linkplay SDK call in `FEATURE-LOGIC-MAP.md`.
3. Prefer an already verified HTTPAPI/UPnP operation in the Protocol KB for the Android implementation. Preserve device/firmware-specific differences.
4. Implement the Android screen and connect it to a protocol/service layer. Reuse `../src/linkplay.js` and `../src/deezer.js` only where their transport and security assumptions fit Android.
5. Compare results on real A31 and A98 units. A matching screenshot is not evidence that a control works.

Screenshots specify visual layout, text, and visible states. The iOS source, SDK headers, protocol KB, and hardware captures specify behavior and wire format. Use both to reproduce each flow.

## Safety and protocol notes

- Keep account passwords out of logs and source control. Do not reuse user-supplied service credentials in test fixtures.
- Do not assume a command exists on all chip families. Read device capability/status and, for UPnP, the device's SCPD before invoking an action.
- Linkplay Music Kit is an iOS SDK. Its Objective-C calls cannot be compiled into Android; port the underlying verified protocol or use an authorized Android SDK if available.
- Android local-network permission, cleartext HTTP policy, background discovery, and app lifecycle need native Android handling.

## References

- Screen inventory: `SCREEN-MAP.md`
- iOS behavior to Android logic: `FEATURE-LOGIC-MAP.md`
- Shared React/Capacitor prototype: `../src/`, `../android/`
- iOS source snapshot: `../ios-native/`
- Protocol evidence: [airControl Protocol KB](https://github.com/keshman74/airControl-Protocol-KB/pull/8)
