# PEPE PTZ Controller

An all-in-one Mac app for controlling Panasonic PTZ cameras on the local network, with live video from each camera.

## Status

Early development. Planned steps:

1. App shell and camera list (add cameras by IP, name and login)
2. Camera control: pan, tilt, zoom, focus, speed and presets
3. Live view for each camera
4. Multi-camera grid: click a feed to take control

## Supported cameras

Built and tested against the Panasonic **AW-UE160**, using Panasonic's HTTP control protocol
(`/cgi-bin/aw_ptz` and `/cgi-bin/aw_cam`). Other Panasonic PTZ models that use the same protocol should work too.

On the camera's web page, make sure IP control is allowed. If the camera asks for a login, enter the same
username and password in the app.

No camera handy? Add a camera and turn on **Simulated camera** to try the controls.

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
