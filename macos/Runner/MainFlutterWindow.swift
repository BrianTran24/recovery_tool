import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame

    // Ensure initial size respects minSize
    let minWidth: CGFloat = 1024
    let minHeight: CGFloat = 720

    if windowFrame.size.width < minWidth || windowFrame.size.height < minHeight {
        windowFrame.size = NSSize(width: max(windowFrame.size.width, minWidth),
                                height: max(windowFrame.size.height, minHeight))
        self.setFrame(windowFrame, display: true)
    }

    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.minSize = NSSize(width: minWidth, height: minHeight)

    // Center the window on screen if it was resized to min
    self.center()

    super.awakeFromNib()
  }
}
