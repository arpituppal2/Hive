//
//  BrowserState+Reader.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Reader Mode
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Reader

@MainActor
extension BrowserState {


    // MARK: - Reader Mode
    // Safari-style: injects CSS/JS that hides non-content elements and applies
    // clean typography to the page in-place. No text extraction needed.

    func toggleReaderMode() {
        if isReaderMode {
            // Exit reader mode — reload the original page through the
            // tab-scoped navigation boundary so an older load cannot win.
            isReaderMode = false
            reload()
            return
        }
        guard let model = activeModel else { return }
        // Inject reader mode CSS + element hiding
        model.executeJavaScript(readerModeJS())
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isReaderMode = true
        }
    }


    func readerModeJS() -> String {
        // Safari-style reader: hide everything except the main content area,
        // then apply clean typography. Targets article, main, and common content
        // containers. Falls back to body with nav/aside/footer stripped.
        """
        (function() {
            if (document.getElementById('hive-reader-style')) {
                // Already applied — remove reader mode
                var s = document.getElementById('hive-reader-style');
                if (s) s.remove();
                document.querySelectorAll('[data-hive-hidden]').forEach(function(el) {
                    el.style.display = '';
                    el.removeAttribute('data-hive-hidden');
                });
                document.body.style.overflow = '';
                return;
            }
            var style = document.createElement('style');
            style.id = 'hive-reader-style';
            style.textContent = [
                '* { background: #faf9f7 !important; color: #1a1a1a !important; }',
                '@media (prefers-color-scheme: dark) { * { background: #1a1a1c !important; color: #e4e4e8 !important; } }',
                'body { max-width: 720px !important; margin: 0 auto !important; padding: 48px 24px !important; }',
                'p, li, blockquote, pre, code, h1, h2, h3, h4, h5, h6 {',
                '  font-family: -apple-system, "Georgia", "Times New Roman", serif !important;',
                '  font-size: 19px !important; line-height: 1.7 !important;',
                '}',
                'h1 { font-size: 32px !important; font-weight: 700 !important; margin-top: 0 !important; }',
                'h2 { font-size: 24px !important; font-weight: 600 !important; margin-top: 36px !important; }',
                'img, video, svg, canvas { max-width: 100% !important; height: auto !important; }',
                'a { color: #2563eb !important; text-decoration: underline !important; }',
                '@media (prefers-color-scheme: dark) { a { color: #60a5fa !important; } }',
                'pre, code { font-family: "SF Mono", monospace !important; font-size: 14px !important; }',
        ].join('\\n');
            document.head.appendChild(style);

            // Hide navigation, sidebars, ads, comments, and non-article elements
            var selectors = [
                'nav', 'header', 'footer', 'aside',
                '.nav', '.navbar', '.navigation', '.sidebar', '.side-bar',
                '.footer', '.site-footer', '.page-footer',
                '.header', '.site-header', '.page-header',
                '.ad', '.ads', '.advertisement', '.banner',
                '.comments', '.comment-section', '#comments',
                '.related-posts', '.recommended', '.sidebar-widget',
                '.social-share', '.share-buttons',
                '.newsletter', '.subscribe', '.popup', '.modal'
            ];
            selectors.forEach(function(sel) {
                document.querySelectorAll(sel).forEach(function(el) {
                    if (!el.hasAttribute('data-hive-hidden')) {
                        el.setAttribute('data-hive-hidden', '1');
                        el.style.display = 'none';
                    }
                });
            });

            // Try to find the main content and show only that
            var content = document.querySelector('article, [role="main"], main, .post-content, .article-content, .entry-content, .markdown-body, .prose');
            if (content) {
                // Hide siblings that aren't the content
                var parent = content.parentElement;
                if (parent) {
                    Array.from(parent.children).forEach(function(child) {
                        if (child !== content && !child.hasAttribute('data-hive-hidden')) {
                            child.setAttribute('data-hive-hidden', '1');
                            child.style.display = 'none';
                        }
                    });
                }
            }

            document.body.style.overflow = 'auto';
            window.scrollTo(0, 0);
        })();
        """
    }


    func sendGeminiMessage(_ text: String, referencedTabIDs: Set<String> = []) {
        let userMsg = GeminiMessage(role: .user, text: text)
        geminiMessages.append(userMsg)

        // Use the Swarm agent pipeline with hot memory context.
        // Thread explicit @tab references through so the orchestrator
        // actually receives the referenced tabs' context (Dia-parity).
        generateOrchestratedResponse(
            role: .summarizer,
            intent: text,
            maxTokens: 512,
            explicitTabIDs: referencedTabIDs
        )
    }
}
