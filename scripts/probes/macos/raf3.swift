import Cocoa; import WebKit
let app=NSApplication.shared; app.setActivationPolicy(.prohibited)
class D:NSObject,WKNavigationDelegate{var cb:(()->Void)?
 func webView(_ w:WKWebView,didFinish n:WKNavigation!){cb?()}}
let d=D()
// onscreen but fully transparent + non-activating panel: never steals focus, but composited
let win=NSPanel(contentRect:NSMakeRect(0,0,800,600),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
win.alphaValue=0.001
win.ignoresMouseEvents=true
win.level=NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
let wv=WKWebView(frame:NSMakeRect(0,0,800,600)); wv.navigationDelegate=d
win.contentView=wv; win.orderFrontRegardless()
d.cb={
 wv.evaluateJavaScript("window.__n=0;(function f(){window.__n++;requestAnimationFrame(f)})();0"){_,_ in
  DispatchQueue.main.asyncAfter(deadline:.now()+1.0){
   wv.evaluateJavaScript("window.__n"){v,_ in print("rAF frames/1s, transparent desktop-level panel:",String(describing:v))
     let t=Date(); wv.takeSnapshot(with:WKSnapshotConfiguration()){img,e in
       print("snapshot:",img != nil ? "ok" : "FAIL \(String(describing:e))", Int(Date().timeIntervalSince(t)*1000),"ms"); exit(0)}
   }}
 }
}
wv.load(URLRequest(url:URL(string:"https://example.com")!))
app.run()
