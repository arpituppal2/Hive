import Foundation

/// Canonical route contract for the embedded Polar AgentApp.
///
/// The handler owns the generated payloads; this pure policy owns the URL
/// normalization, allowlist, and MIME contract so route regressions are
/// testable from HiveCore without constructing CEF.
public enum PolarAssetRoutePolicy: Equatable, Sendable {
    case index
    case stylesheet
    case javascript(name: String)
    case inviteImage
    case font(name: String)

    public var mimeType: String {
        switch self {
        case .index: return "text/html"
        case .stylesheet: return "text/css"
        case .javascript: return "application/javascript"
        case .inviteImage: return "image/png"
        case .font(let name):
            if name.hasSuffix(".woff2") { return "font/woff2" }
            if name.hasSuffix(".woff") { return "font/woff" }
            return "font/ttf"
        }
    }

    public var generatedAssetName: String? {
        switch self {
        case .index: return "polarIndex"
        case .stylesheet: return "polarCSS"
        case .javascript(let name): return "polar\(name)Base64"
        case .inviteImage: return "polarInvitePNGBase64"
        case .font: return nil
        }
    }

    /// Resolves a Polar-relative route such as `/assets/index-QWD3Wno1.js`.
    /// Unknown paths fail closed; no arbitrary file path can reach the bundle.
    public static func resolve(_ path: String) -> Self? {
        let normalized: String
        if path.isEmpty || path == "/" {
            normalized = "/index.html"
        } else if path.hasPrefix("/polar") {
            let suffix = String(path.dropFirst(6))
            normalized = suffix.isEmpty || suffix == "/" ? "/index.html" : suffix
        } else {
            normalized = path.hasPrefix("/") ? path : "/\(path)"
        }

        switch normalized {
        case "/index.html": return .index
        case "/assets/index-BY6JzNer.css": return .stylesheet
        case "/assets/index-QWD3Wno1.js": return .javascript(name: "AppJS")
        case "/assets/agentSurface-TavgROI7.js": return .javascript(name: "AgentSurfaceJS")
        case "/assets/CommandPanelPage-CQPc9sFE.js": return .javascript(name: "CommandPanelJS")
        case "/assets/ModalAgentAppPage-DT0g5KTd.js": return .javascript(name: "ModalJS")
        case "/assets/WindowAgentAppPage-CzJKotYB.js": return .javascript(name: "WindowJS")
        case "/assets/docx-preview-ChFBTZoq.js": return .javascript(name: "DocxJS")
        case "/assets/mermaid-GHXKKRXX-D0lw7t8a.js": return .javascript(name: "MermaidJS")
        case "/assets/xlsx-CkFp8p6R.js": return .javascript(name: "XlsxJS")
        case "/assets/highlighted-body-OFNGDK62-BsqO-kRD.js": return .javascript(name: "HighlightedBodyJS")
        case "/assets/ReferralCardPreviewPage-CDEMiD_U.js": return .javascript(name: "ReferralCardJS")
        case "/assets/ReferralMilestoneCard-DwOWE_LT.js": return .javascript(name: "ReferralMilestoneJS")
        case "/assets/invite-envelope-n37wvGqS.png": return .inviteImage
        default:
            guard normalized.hasPrefix("/assets/KaTeX_"),
                  normalized.hasSuffix(".woff2") || normalized.hasSuffix(".woff") || normalized.hasSuffix(".ttf") else {
                return nil
            }
            let filename = String(normalized.dropFirst("/assets/".count))
            return .font(name: filename)
        }
    }
}
