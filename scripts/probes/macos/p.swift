import Cocoa
import WebKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)   // no dock icon, no focus steal

class D: NSObject, WKNavigationDelegate {
    var done = false
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        let cfg = WKSnapshotConfiguration()
        let t0 = Date()
        w.takeSnapshot(with: cfg) { img, err in
            if let img = img {
                let r = NSBitmapImageRep(data: img.tiffRepresentation!)!
                let png = r.representation(using: .png, properties: [:])!
                try? png.write(to: URL(fileURLWithPath: "/tmp/wkprobe/shot.png"))
                print("snapshot ok \(Int(img.size.width))x\(Int(img.size.height)) in \(Int(Date().timeIntervalSince(t0)*1000))ms")
            } else { print("snapshot err \(String(describing: err))") }
            w.evaluateJavaScript("document.title") { v, _ in
                print("title=\(String(describing: v))")
                self.done = true
                exit(0)
            }
        }
    }
}

let win = NSWindow(contentRect: NSMakeRect(-10000, -10000, 1024, 768), styleMask: [.borderless], backing: .buffered, defer: false)
let wv = WKWebView(frame: NSMakeRect(0,0,1024,768))
let d = D()
wv.navigationDelegate = d
win.contentView = wv
win.orderBack(nil)   // in hierarchy, offscreen
let t = Date()
wv.load(URLRequest(url: URL(string: CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "https://example.com")!))
print("start")
app.run()
