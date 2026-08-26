import Cocoa; import WebKit
let app=NSApplication.shared; app.setActivationPolicy(.prohibited)
class D:NSObject,WKNavigationDelegate{var cb:(()->Void)?
 func webView(_ w:WKWebView,didFinish n:WKNavigation!){cb?()}}
let d=D()
let win=NSWindow(contentRect:NSMakeRect(-10000,-10000,800,600),styleMask:[.borderless],backing:.buffered,defer:false)
let wv=WKWebView(frame:NSMakeRect(0,0,800,600)); wv.navigationDelegate=d
win.contentView=wv; win.orderBack(nil)
d.cb={
 wv.evaluateJavaScript("window.__n=0;(function f(){window.__n++;requestAnimationFrame(f)})();window.__n"){_,_ in
  DispatchQueue.main.asyncAfter(deadline:.now()+1.0){
   wv.evaluateJavaScript("window.__n"){v,e in print("rAF frames in 1s, window orderBack offscreen:",String(describing:v))
     // now try making window visible-but-offscreen via orderFrontRegardless at negative coords
     win.orderFrontRegardless()
     wv.evaluateJavaScript("window.__n=0"){_,_ in
      DispatchQueue.main.asyncAfter(deadline:.now()+1.0){
       wv.evaluateJavaScript("window.__n"){v2,_ in print("rAF frames in 1s, orderFrontRegardless offscreen:",String(describing:v2)); exit(0)}
      }}
   }}
 }
}
wv.load(URLRequest(url:URL(string:"https://example.com")!))
app.run()
