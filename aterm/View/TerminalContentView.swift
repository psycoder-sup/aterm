import SwiftUI
import AppKit

struct TerminalContentView: NSViewRepresentable {
    let core: TerminalCore

    func makeNSView(context: Context) -> TerminalHostView {
        TerminalHostView(core: core)
    }

    func updateNSView(_ nsView: TerminalHostView, context: Context) {
        let gen = core.outputGeneration
        nsView.appendChunkIfNew(core.latestChunk, generation: gen)
    }
}

final class TerminalHostView: NSView {
    private let textView: TerminalInputTextView
    private let scrollView: NSScrollView
    private var lastGeneration: UInt64 = 0

    private static let outputAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor.white,
    ]

    init(core: TerminalCore) {
        self.scrollView = NSScrollView()
        self.textView = TerminalInputTextView()

        super.init(frame: .zero)

        setupViews()

        textView.onInput = { [weak core] text in
            core?.sendInput(text)
        }
        textView.onBytes = { [weak core] bytes in
            core?.sendBytes(bytes)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(textView)
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(textView)
    }

    func appendChunkIfNew(_ chunk: String, generation: UInt64) {
        guard generation != lastGeneration, !chunk.isEmpty else { return }
        lastGeneration = generation
        textView.textStorage?.append(
            NSAttributedString(string: chunk, attributes: Self.outputAttributes)
        )
        textView.scrollToEndOfDocument(nil)
    }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = .terminalBackground
        textView.textColor = .white
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 4, height: 4)

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
