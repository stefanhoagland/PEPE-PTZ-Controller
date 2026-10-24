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

For live video, turn on JPEG streaming in the camera's web settings (Video over IP). The app reads
`/cgi-bin/mjpeg?stream=1`, and falls back to fetching snapshots from `/cgi-bin/camera` if the stream isn't available.

## Using it

- **Grid** (toolbar) shows every camera's live feed. Click a feed to control that camera in the panel on the right,
  double-click to open it on its own, or press **1** to **9** to pick a camera by its number.
- **Single** shows one camera large, with its controls.
- Movement buttons work while held and stop when you let go.

No camera handy? Add a camera and turn on **Simulated camera** to try the controls.

## Requirements

- macOS 13 Ventura or newer
- Xcode 15 or newer (or the Swift 5.9+ toolchain)

## Download

Get the latest app from the [Releases page](https://github.com/stefanhoagland/PEPE-PTZ-Controller/releases/latest).
The release notes explain how to open it the first time, since it isn't notarized by Apple yet.

To publish a new version, open **Actions → Release → Run workflow** on GitHub and enter a version such as `0.2.0`
(or push a tag such as `v0.2.0`). GitHub builds the app and creates the release.

## Running from source

```sh
swift run PEPEPTZController
```

Or open `Package.swift` in Xcode and press Run.

## Tests

```sh
swift test
```
