//
//  MarkdownWebView.swift
//  selectedai
//

import SwiftUI
import WebKit
import OSLog

private let log = Logger(subsystem: "ai.selected", category: "MarkdownWebView")

/// Renders Markdown using WKWebView with streaming append support.
struct MarkdownWebView: NSViewRepresentable {
    @Binding var markdownText: String
    var colorScheme: ColorScheme

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(Self.buildHTML(scheme: colorScheme), baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.pendingMarkdown = markdownText
        coordinator.pendingTheme = colorScheme == .dark ? "dark" : "light"
        coordinator.flushIfReady(webView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - HTML template (inline marked.js lite + highlight)

    static func buildHTML(scheme: ColorScheme) -> String {
        let isDark = scheme == .dark
        let bg = isDark ? "transparent" : "transparent"
        let fg = isDark ? "#e6edf3" : "#1f2328"
        let codeBg = isDark ? "#161b22" : "#f6f8fa"
        let linkColor = isDark ? "#58a6ff" : "#0969da"
        let blockquoteColor = isDark ? "#8b949e" : "#656d76"
        let blockquoteBorder = isDark ? "#30363d" : "#d0d7de"

        return """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8">
        <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;font-size:14px;
             line-height:1.65;padding:12px 16px;color:\(fg);background:\(bg)}
        p{margin-bottom:8px}
        h1,h2,h3,h4{margin:12px 0 6px;font-weight:600}
        ul,ol{padding-left:20px;margin-bottom:8px}
        li{margin-bottom:2px}
        pre{background:\(codeBg);border-radius:6px;padding:12px;overflow-x:auto;margin-bottom:8px}
        code{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:12.5px}
        p>code{background:\(codeBg);padding:1px 4px;border-radius:3px}
        a{color:\(linkColor);text-decoration:none}
        blockquote{border-left:3px solid \(blockquoteBorder);padding-left:12px;
                   color:\(blockquoteColor);margin-bottom:8px}
        hr{border:none;border-top:1px solid \(blockquoteBorder);margin:12px 0}
        strong{font-weight:600}em{font-style:italic}
        table{border-collapse:collapse;margin-bottom:8px;width:100%}
        th,td{border:1px solid \(blockquoteBorder);padding:6px 10px;text-align:left}
        th{background:\(codeBg)}
        </style>
        </head><body>
        <div id="c"></div>
        <script>
        // Minimal Markdown parser (no external dependencies)
        function md2html(s){
          // Escape HTML
          function esc(t){return t.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
          // Code blocks
          s=s.replace(/```([\\w]*)\\n?([\\s\\S]*?)```/g,(_,lang,code)=>
            '<pre><code>'+(esc(code.trim()))+'</code></pre>');
          // Headings
          s=s.replace(/^#{1,6} (.+)$/gm,(m,t)=>{
            var n=m.indexOf(' ');return '<h'+n+'>'+t+'</h'+n+'>'});
          // HR
          s=s.replace(/^---+$/gm,'<hr>');
          // Blockquote
          s=s.replace(/^> (.+)$/gm,'<blockquote>$1</blockquote>');
          // Unordered list
          s=s.replace(/^[\\*\\-] (.+)$/gm,'<li>$1</li>');
          s=s.replace(/(<li>.*<\\/li>)/gs,'<ul>$1</ul>');
          // Bold/italic
          s=s.replace(/\\*\\*(.+?)\\*\\*/g,'<strong>$1</strong>');
          s=s.replace(/\\*(.+?)\\*/g,'<em>$1</em>');
          // Inline code
          s=s.replace(/`([^`]+)`/g,'<code>'+esc('$1')+'</code>');
          // Links
          s=s.replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g,'<a href="$2">$1</a>');
          // Paragraphs (double newline separated blocks not already wrapped)
          var blocks=s.split(/\\n\\n+/);
          s=blocks.map(b=>{
            b=b.trim();
            if(!b) return '';
            if(/^<(h[1-6]|ul|ol|li|pre|blockquote|hr)/.test(b)) return b;
            return '<p>'+b.replace(/\\n/g,'<br>')+'</p>';
          }).join('\\n');
          return s;
        }
        function updateContent(md){
          document.getElementById('c').innerHTML=md2html(md);
          document.querySelectorAll('a').forEach(a=>{
            a.addEventListener('click',e=>{e.preventDefault();window.open(a.href,'_blank')});
          });
        }
        function setTheme(t){document.body.setAttribute('data-theme',t)}
        </script>
        </body></html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var isReady = false
        var pendingMarkdown: String = ""
        var pendingTheme: String = "light"

        func flushIfReady(_ webView: WKWebView) {
            guard isReady else { return }
            let escaped = pendingMarkdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("updateContent(`\(escaped)`);") { _, err in
                if let err { log.error("updateContent JS error: \(err.localizedDescription)") }
            }
            webView.evaluateJavaScript("setTheme('\(pendingTheme)');", completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            log.info("WebView didFinish loading, isReady=true")
            isReady = true
            flushIfReady(webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
