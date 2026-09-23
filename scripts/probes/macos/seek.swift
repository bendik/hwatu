import Cocoa; import WebKit
let app=NSApplication.shared; app.setActivationPolicy(.prohibited)
class D:NSObject,WKNavigationDelegate{var cb:(()->Void)?
 func webView(_ w:WKWebView,didFinish n:WKNavigation!){cb?()}}
let d=D()
let win=NSWindow(contentRect:NSMakeRect(-10000,-10000,400,200),styleMask:[.borderless],backing:.buffered,defer:false)
let wv=WKWebView(frame:NSMakeRect(0,0,400,200)); wv.navigationDelegate=d
win.contentView=wv; win.orderBack(nil)
func shot(_ tag:String,_ next:@escaping()->Void){
 wv.takeSnapshot(with:WKSnapshotConfiguration()){img,_ in
  if let i=img, let r=NSBitmapImageRep(data:i.tiffRepresentation!),
     let p=r.representation(using:.png,properties:[:]) {
    try? p.write(to:URL(fileURLWithPath:"/tmp/wkprobe/seek-\(tag).png")); print("wrote seek-\(tag).png",p.count,"bytes")}
  next()}
}
d.cb={
 wv.evaluateJavaScript("""
  const a=document.getElementById('x').getAnimations();
  a.forEach(an=>{an.pause();an.currentTime=0});
  a.length
 """){v,e in print("animations:",String(describing:v),String(describing:e))
  shot("t0"){
   wv.evaluateJavaScript("document.getElementById('x').getAnimations().forEach(a=>a.currentTime=1000);getComputedStyle(document.getElementById('x')).transform"){t,_ in
    print("transform@1000ms:",String(describing:t))
    shot("t1000"){ exit(0) }
   }}
 }
}
let html="<style>@keyframes m{from{transform:translateX(0)}to{transform:translateX(300px)}}#x{width:50px;height:50px;background:red;animation:m 2s linear infinite}</style><div id=x></div>"
wv.loadHTMLString(html,baseURL:URL(string:"https://example.com"))
app.run()
