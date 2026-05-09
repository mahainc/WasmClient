#if canImport(WebKit)
@_implementationOnly import FlowKit
import WebKit

extension WKWebView {
    /// Returns a `WKWebView` whose configuration bypasses any process-wide
    /// URLSession proxy installed by the WasmClient engine. Thin wrapper
    /// around FlowKit's `WKWebView.noProxy()` so consumers don't have to
    /// import FlowKit directly (which requires the merged-submodule build
    /// plugin and unsafe flags that ship with this package).
    public static func wasmClientNoProxy() -> WKWebView {
        WKWebView.noProxy()
    }
}
#endif
