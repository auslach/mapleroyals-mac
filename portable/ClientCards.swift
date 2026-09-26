import AppKit

final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

private final class ClientCard: NSView {
    init(number: Int) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        let title = NSTextField(labelWithString: "Client \(number)")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let status = NSTextField(labelWithString: "Open")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, status])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// Uses only the launcher's existing process tracking. No window inspection,
// screen capture, permission request, or refresh timer is needed.
final class ClientCards: NSView {
    private let rows = NSStackView()
    private var order = [UUID]()

    override init(frame: NSRect) {
        super.init(frame: frame)
        let title = NSTextField(labelWithString: "Open clients")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 10
        let stack = NSStackView(views: [title, rows])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            rows.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setClients(_ clients: [GameClients.Client]) {
        precondition(Thread.isMainThread)
        let ordered = clients.sorted { $0.number < $1.number }
        let ids = ordered.map(\.id)
        guard ids != order else { return }
        order = ids
        for row in rows.arrangedSubviews { rows.removeArrangedSubview(row); row.removeFromSuperview() }
        for offset in stride(from: 0, to: ordered.count, by: 2) {
            let first = ClientCard(number: ordered[offset].number)
            let second: NSView = offset + 1 < ordered.count ? ClientCard(number: ordered[offset + 1].number) : NSView()
            let row = NSStackView(views: [first, second])
            row.orientation = .horizontal; row.alignment = .top; row.spacing = 12
            row.distribution = .fillEqually
            rows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        isHidden = ids.isEmpty
    }
}
