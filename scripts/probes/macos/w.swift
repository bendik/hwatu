import Cocoa
import WebKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
var wvs:[WKWebView]=[]; var wins:[NSWindow]=[]
let N = 8
let pool = WKProcessPool()
class D: NSObject, WKNavigationDelegate {
  var cb: (()->Void)?
  func webView(_ w: WKWebView, didFinish n: WKNavigation!) { cb?() }
}
var ds:[D]=[]
let t0=Date()
var loaded=0
for i in 0..<N {
  let cfg=WKWebViewConfiguration(); cfg.processPool=pool
  let win=NSWindow(contentRect:NSMakeRect(-10000,-10000,1024,768),styleMask:[.borderless],backing:.buffered,defer:false)
  let wv=WKWebView(frame:NSMakeRect(0,0,1024,768),configuration:cfg)
  let d=D(); ds.append(d); wv.navigationDelegate=d
  win.contentView=wv; win.orderBack(nil)
  wins.append(win); wvs.append(wv)
  d.cb={ loaded+=1
    if loaded==N {
      print("8 parallel loads (example.com) in \(Int(Date().timeIntervalSince(t0)*1000))ms")
      // warm loop timings on webview 0
      let w=wvs[0]
      let te=Date()
      w.evaluateJavaScript("document.title"){_,_ in
        print("warm eval \(Int(Date().timeIntervalSince(te)*1000))ms")
        let ts=Date()
        w.takeSnapshot(with:WKSnapshotConfiguration()){img,_ in
          print("warm snapshot \(Int(Date().timeIntervalSince(ts)*1000))ms")
          let tn=Date()
          ds[0].cb={ print("warm nav+load \(Int(Date().timeIntervalSince(tn)*1000))ms"); exit(0) }
          w.load(URLRequest(url:URL(string:"https://example.com/?x=2")!))
        }
      }
    }
  }
  wv.load(URLRequest(url:URL(string:"https://example.com/?i=\(i)")!))
}
app.run()
