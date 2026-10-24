# PEPE PTZ Controller

An all-in-one Mac app for controlling Panasonic PTZ cameras on the local network, with live video from each camera.

## Status

Early development. Planned steps:

1. App shell and camera list (add cameras by IP, name and login)
2. Camera control: pan, tilt, zoom, focus, speed and presets
3. Live view for each camera
4. Multi-camera grid: click a feed to take control

## Requirements

- macOS 13 Ventura or newer
- Xcode 15 or newer (or the Swift 5.9+ toolchain)

## Running it

```sh
swift run PEPEPTZController
```

Or open `Package.swift` in Xcode and press Run.

## Tests

```sh
swift test
```
