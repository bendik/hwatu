import Cocoa; import WebKit
let app=NSApplication.shared; app.setActivationPolicy(.prohibited)
// probes: cookie persistence, offscreen input events, rAF/animation ticking while offscreen
class D:NSObject,WKNavigationDelegate{ var cb:(()->Void)?
 func webView(_ w:WKWebView,didFinish n:WKNavigation!){cb?()} }
let d=D()
let cfg=WKWebViewConfiguration()
cfg.websiteDataStore = .default()
let win=NSWindow(contentRect:NSMakeRect(-10000,-10000,800,600),styleMask:[.borderless],backing:.buffered,defer:false)
let wv=WKWebView(frame:NSMakeRect(0,0,800,600),configuration:cfg); wv.navigationDelegate=d
win.contentView=wv; win.orderBack(nil)
d.cb={
  // does requestAnimationFrame tick while window is offscreen/not visible?
  wv.evaluateJavaScript("""
   new Promise(r=>{let n=0,t0=performance.now();
     function f(){n++; if(performance.now()-t0>500){r(n)} else requestAnimationFrame(f)}
     requestAnimationFrame(f)})
  """){v,e in print("rAF frames in 500ms offscreen: \(String(describing:v)) err=\(String(describing:e))")
    // synthetic click via JS+native event
    wv.evaluateJavaScript("document.body.innerHTML='<button id=b onclick=\"document.title=\\'clicked\\'\">go</button>';document.getElementById('b').getBoundingClientRect().x"){_,_ in
      wv.evaluateJavaScript("document.getElementById('b').click(); document.title"){t,_ in
        print("js click title=\(String(describing:t))")
        let store=cfg.websiteDataStore.httpCookieStore
        store.getAllCookies{cs in print("cookies visible: \(cs.count)"); exit(0)}
      }
    }
  }
}
wv.load(URLRequest(url:URL(string:"https://example.com")!))
app.run()
