#if canImport(WebKit)
    @_implementationOnly import FlowKit
    import WebKit

    extension WKWebView {
        public static func wasmClientNoProxy() -> WKWebView {
            WKWebView.noProxy()
        }
    }
#endif
