# Zign

<p align="center">
  <img src="zign-banner.png" alt="Zign banner" width="100%">
</p>

A native iOS IPA signing and management toolkit.

Zign (Zenith Sign) is an open-source iOS application project focused on IPA inspection, code signing, certificate management, and provisioning profile management.

Built with Swift and SwiftUI, Zign aims to provide a clean, modern interface for managing iOS application packages directly from an iPhone or iPad.

## Features

Planned

* [ ]	Import IPA files through the iOS Files app.
* [ ]	Inspect IPA package contents and metadata.
* [ ]	Display bundle identifiers and application versions.
* [ ]	Inspect embedded provisioning profiles.
* [ ]	Import and manage signing certificates.
* [ ]	Inspect certificate validity and expiration.
* [ ]	Analyze entitlements and signing compatibility.
* [ ]	Sign compatible IPA packages.
* [ ]	Export signed IPA files.
* [ ]	Maintain a local signing history.

## Technology

* Language: Swift
* Interface: SwiftUI
* Platform: iOS and iPadOS
* Package format: IPA
* Development: Xcode
* Automation: GitHub Actions

## Project Goals

Zign is being developed with the following principles:

* Local-first: Keep package processing and certificate management on-device wherever possible.
* Privacy: Avoid unnecessary data collection and external dependencies.
* Simplicity: Make complex signing workflows accessible through a straightforward interface.
* Reliability: Prioritize accurate package inspection and signing validation.
* Open source: Keep development transparent and accessible to contributors.

## Compatibility

Zign is intended for modern iOS and iPadOS devices.

Actual signing and installation capabilities depend on Apple’s code-signing requirements, available certificates, provisioning profiles, entitlements, and platform restrictions.

Zign does not promise unrestricted IPA installation or bypass of Apple’s platform security.

## Development Roadmap

| Phase | Feature | Status |
|---|---|---|
| 1 | Project setup and architecture | In progress |
| 2 | IPA importing and inspection | Planned |
| 3 | Certificate management | Planned |
| 4 | Provisioning profile inspection | Planned |
| 5 | Entitlements analysis | Planned |
| 6 | IPA signing engine | Planned |
| 7 | Signed IPA export | Planned |
| 8 | Signing history | Planned |
| 9 | Testing and optimization | Planned |

## Security

Security is a core development priority.

* Private signing keys should remain protected.
* Certificate and provisioning profile handling should be validated.
* Signing operations should report errors clearly.
* Dependencies should be reviewed and kept up to date.

Please report security vulnerabilities responsibly rather than publishing sensitive exploit details.

## License

This project is licensed under the MIT License.

⸻

## Zign — Zenith Sign

An independent approach to iOS application signing.
