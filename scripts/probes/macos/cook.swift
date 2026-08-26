import Cocoa; import WebKit
let app=NSApplication.shared; app.setActivationPolicy(.prohibited)
class D:NSObject,WKNavigationDelegate{var cb:(()->Void)?
 func webView(_ w:WKWebView,didFinish n:WKNavigation!){cb?()}}
let d=D()
let win=NSWindow(contentRect:NSMakeRect(-10000,-10000,400,200),styleMask:[.borderless],backing:.buffered,defer:false)
let wv=WKWebView(frame:NSMakeRect(0,0,400,200)); wv.navigationDelegate=d
win.contentView=wv; win.orderBack(nil)
let mode=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "read"
d.cb={
 let store=WKWebsiteDataStore.default().httpCookieStore
 if mode=="write" {
  let c=HTTPCookie(properties:[.domain:"example.com",.path:"/",.name:"hwatu_probe",.value:"v1",.expires:Date().addingTimeInterval(86400)])!
  store.setCookie(c){ store.getAllCookies{cs in print("wrote; now",cs.map{$0.name}); exit(0)} }
 } else {
  store.getAllCookies{cs in print("read cookies:",cs.map{"\($0.domain)/\($0.name)"}); exit(0)}
 }
}
wv.load(URLRequest(url:URL(string:"https://example.com")!))
app.run()
