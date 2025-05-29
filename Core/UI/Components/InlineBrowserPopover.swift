import DesignSystem
import SwiftUI
import WebKit

/// A popover that displays web content inline for quick access to external resources.
///
/// InlineBrowserPopover provides:
/// - GitHub repository browsing with direct integration
/// - Documentation and help content display
/// - Quick access to external links without leaving the app
/// - Responsive sizing for different content types
struct InlineBrowserPopover: View {
    let url: URL
    let title: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and controls
            if let title {
                HStack {
                    Text(title)
                        .font(Typography.headline())
                        .foregroundColor(ColorPalette.text)

                    Spacer()

                    Button("Open in Browser") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(Spacing.medium)
                .background(ColorPalette.backgroundSecondary)

                DSDivider()
            }

            // Web content
            WebView(url: url)
                .frame(width: 600, height: 400)
        }
    }

    // MARK: - Factory Methods

    static func github(url: URL) -> InlineBrowserPopover {
        InlineBrowserPopover(
            url: url,
            title: "GitHub Repository"
        )
    }

    static func documentation(url: URL) -> InlineBrowserPopover {
        InlineBrowserPopover(
            url: url,
            title: "Documentation"
        )
    }

    static func web(url: URL, title: String? = nil) -> InlineBrowserPopover {
        InlineBrowserPopover(
            url: url,
            title: title
        )
    }
}

// MARK: - WebView

private struct WebView: NSViewRepresentable {
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow the initial load, but open external links in default browser
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }

    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_: WKWebView, context _: Context) {
        // No updates needed for static content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

#if DEBUG
    struct InlineBrowserPopover_Previews: PreviewProvider {
        static var previews: some View {
            InlineBrowserPopover.github(
                url: URL(string: "https://github.com/steipete/CodeLooper")!
            )
            .withDesignSystem()
        }
    }
#endif
