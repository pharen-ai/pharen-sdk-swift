# Localization and branding

Part of the [PharenSDK guides](../README.md#guides).

## Localization

The SDK's own end-user surfaces — the feedback sheet and its refusals, and the covers app
notices draw — ship in 21 languages, Simplified and Traditional Chinese among them, and follow
the reader's own language preference, the way system UI does: an app localized only into English
still shows the sheet in the language its user reads. `PharenConfig.uiLocale` pins the surface
to one language for apps where the language is chosen in-app;
`Bundle.main.preferredLocalizations.first` pins it to the app's own UI language. Every string
can be overridden key by key: define the key in a `Pharen.strings` table in your app bundle, and
your copy wins for that key while the package's copy serves the rest. The one exception is the
platform mark at the foot of the sheet, which is not a key: it reads in the language the sheet
does, in every language the SDK ships, and English otherwise.

## Remote app brand

On a plan that includes it, the SDK applies the app brand served with your configuration to its
feedback and survey forms, rating question, notice covers and developer panels. A presentation
keeps its opening brand while appearance and text accessibility settings continue to adapt.
Colors fall back to readable native roles, and unavailable local fonts fall back to the system
face; the SDK downloads no fonts. UIKit confirmation alerts accept tint styling and keep their
native font, background and corners. System/store dialogs, permissions, keyboards and photo
pickers keep their system appearance.

The platform mark is a separate served decision. An offline install keeps its last successful
configuration, so remote removals and plan changes take effect after a successful refresh. Hosted
report pages and widgets use the separate brand on their publishable key.
