# Nexus App Store Plan

## Current CasaOS-Compatible Model

Nexus Cloud currently inherits the CasaOS app model. App Store entries describe
Docker Compose applications, and the frontend asks the CasaOS app-management API
to install or update those definitions. On a deployed machine, installed
application data and Compose definitions live under `/var/lib/casaos/apps`.

The dashboard app grid is rendered by `UI/src/components/Apps/AppSection.vue`.
Individual installed applications are rendered by `AppCard.vue`. The App Store
modal, categories, recommendations, details, and install actions are handled by
`AppPanel.vue`. Third-party App Store source registration is handled by
`AppStoreSourceManagement.vue`.

## Ports

A Compose application maps host ports to container ports. For example, a browser
container might expose its internal web interface on port `6901` and publish that
as host port `6901`. The dashboard can then open the mapped host address. This is
compatible with CasaOS, but it is not yet the intended long-term Nexus user
experience.

## Curated Nexus Categories

A future Nexus-compatible catalog should organize CasaOS-compatible definitions
into:

- Browser
- Office
- Files
- Developer
- Business
- AI

The catalog should remain compatible with existing Compose app definitions so it
does not require changes to CasaOS installation APIs.

## Future Direction

Build a curated Nexus App Store from CasaOS-compatible Compose definitions. Add
optional setup profiles for Basic Computer, Developer Workstation, Business
Server, and AI Workstation. Profiles should select recommended apps; they should
not create a separate installation format.
