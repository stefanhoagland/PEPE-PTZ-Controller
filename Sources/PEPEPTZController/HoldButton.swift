import SwiftUI

/// A button that acts while held: `onPress` when pressed, `onRelease` when let go.
/// Used for camera movement, which must stop as soon as the button is released.
struct HoldButton<Label: View>: View {
    let onPress: () -> Void
    let onRelease: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label()
            .frame(minWidth: 44, minHeight: 36)
            .padding(.horizontal, 6)
            .background(
                isPressed ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else { return }
                        isPressed = true
                        onPress()
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        onRelease()
                    }
            )
            .onDisappear {
                if isPressed {
                    isPressed = false
                    onRelease()
                }
            }
    }
}
