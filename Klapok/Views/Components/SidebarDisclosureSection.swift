//
//  SidebarDisclosureSection.swift
//  Klapok
//
//  Shared collapsible section for editor sidebars.
//

import SwiftUI

#if os(macOS)
import AppKit

@MainActor
private final class SidebarDisclosureSectionHoverState: ObservableObject {
    @Published var isHovering = false
}

struct SidebarScrollContainer<Content: View>: NSViewRepresentable {
    private let content: Content
    private let fillsAvailableWidth: Bool
    private let leadingInset: CGFloat
    private let trailingInset: CGFloat

    init(
        fillsAvailableWidth: Bool = false,
        leadingInset: CGFloat = SidebarStyle.sidebarLeadingInset,
        trailingInset: CGFloat = SidebarStyle.sidebarTrailingInset,
        @ViewBuilder content: () -> Content
    ) {
        self.fillsAvailableWidth = fillsAvailableWidth
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SidebarScrollHostView {
        let view = SidebarScrollHostView(
            rootView: AnyView(hostedContent),
            fillsAvailableWidth: fillsAvailableWidth
        )
        context.coordinator.hostView = view
        return view
    }

    func updateNSView(_ nsView: SidebarScrollHostView, context: Context) {
        nsView.update(rootView: AnyView(hostedContent), fillsAvailableWidth: fillsAvailableWidth)
    }

    private var paddedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.top, SidebarStyle.sidebarTopInset)
        .padding(.bottom, SidebarStyle.sidebarBottomInset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var hostedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            paddedContent
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    final class Coordinator {
        var hostView: SidebarScrollHostView?
    }
}

final class SidebarScrollHostView: NSView {
    private struct PendingScrollPosition {
        let distanceFromTop: CGFloat
    }

    private let scrollView = NSScrollView()
    private let hostingView: NSHostingView<AnyView>
    private var rootContent: AnyView
    private var fillsAvailableWidth: Bool
    private var appliedContentWidth: CGFloat = 0
    private var pendingScrollPosition: PendingScrollPosition?

    init(rootView: AnyView, fillsAvailableWidth: Bool) {
        self.rootContent = rootView
        self.fillsAvailableWidth = fillsAvailableWidth
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.rootContent = AnyView(EmptyView())
        self.fillsAvailableWidth = false
        self.hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        super.init(coder: coder)
        setup()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    func update(rootView: AnyView, fillsAvailableWidth: Bool) {
        pendingScrollPosition = captureScrollPosition()
        rootContent = rootView
        self.fillsAvailableWidth = fillsAvailableWidth
        appliedContentWidth = 0
        if fillsAvailableWidth {
            applyRootContent(width: scrollView.contentView.bounds.width)
        } else {
            hostingView.rootView = rootView
        }
        hostingView.invalidateIntrinsicContentSize()
        hostingView.needsLayout = true
        needsLayout = true
    }

    override func layout() {
        super.layout()
        layoutDocument()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        configure(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = []
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        scrollView.documentView = hostingView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configure(_ scrollView: NSScrollView) {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.scrollerKnobStyle = .default
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.needsLayout = true
        scrollView.needsDisplay = true
    }

    private func layoutDocument() {
        let viewportSize = scrollView.contentView.bounds.size
        guard viewportSize.width > 0 else {
            return
        }

        let width = max(1, viewportSize.width)
        if fillsAvailableWidth {
            applyRootContent(width: width)
        }

        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: max(1, hostingView.frame.height)
        )
        hostingView.layoutSubtreeIfNeeded()

        let fittingHeight = hostingView.fittingSize.height
        let height = max(viewportSize.height, fittingHeight)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        restorePendingScrollOrigin()
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func applyRootContent(width: CGFloat) {
        guard width > 0, abs(appliedContentWidth - width) > 0.5 else {
            return
        }

        appliedContentWidth = width
        hostingView.rootView = AnyView(
            rootContent
                .frame(width: width, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
        hostingView.invalidateIntrinsicContentSize()
    }

    private func restorePendingScrollOrigin() {
        guard let pendingScrollPosition else { return }

        let restoredOrigin = CGPoint(
            x: 0,
            y: verticalOrigin(forDistanceFromTop: pendingScrollPosition.distanceFromTop)
        )

        scrollView.contentView.scroll(to: restoredOrigin)
        self.pendingScrollPosition = nil
    }

    private func captureScrollPosition() -> PendingScrollPosition {
        PendingScrollPosition(distanceFromTop: currentDistanceFromTop())
    }

    private func currentDistanceFromTop() -> CGFloat {
        let maxY = maximumScrollOriginY
        let originY = scrollView.contentView.bounds.origin.y

        if hostingView.isFlipped {
            return min(max(originY, 0), maxY)
        }

        return min(max(maxY - originY, 0), maxY)
    }

    private func verticalOrigin(forDistanceFromTop distanceFromTop: CGFloat) -> CGFloat {
        let maxY = maximumScrollOriginY
        let clampedDistance = min(max(distanceFromTop, 0), maxY)

        if hostingView.isFlipped {
            return clampedDistance
        }

        return maxY - clampedDistance
    }

    private var maximumScrollOriginY: CGFloat {
        max(0, hostingView.frame.height - scrollView.contentView.bounds.height)
    }
}

struct SidebarDisclosureSection<Content: View>: View {
    private let id: String
    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let content: Content

    @AppStorage private var isExpanded: Bool
    @StateObject private var hoverState = SidebarDisclosureSectionHoverState()

    init(
        id: String,
        title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        defaultExpanded: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
        self._isExpanded = AppStorage(
            wrappedValue: defaultExpanded,
            "sidebar.section.\(id).expanded"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 16)
                    }

                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(headerBackground)
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(subtitle ?? title)
            .onHover { hovering in
                hoverState.isHovering = hovering
            }

            if isExpanded {
                SidebarContentCard {
                    content
                }
                .padding(.horizontal, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var headerBackground: Color {
        if hoverState.isHovering {
            return Color.primary.opacity(0.055)
        }

        return .clear
    }
}

struct SidebarContentCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SidebarStyle.sectionFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SidebarStyle.sectionStroke, lineWidth: 0.7)
        }
    }
}

struct SidebarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.075))
            .frame(height: 0.7)
            .padding(.leading, 28)
            .padding(.vertical, 2)
    }
}

struct SidebarControlRow<Accessory: View>: View {
    let title: String
    let systemImage: String?
    let accessory: Accessory

    init(
        title: String,
        systemImage: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            Text(title)
                .font(SidebarStyle.bodyFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 10)

            accessory
                .font(SidebarStyle.bodyFont)
                .controlSize(.small)
                .layoutPriority(0)
        }
        .frame(minHeight: 29)
    }
}

struct SidebarValueRow: View {
    let title: String
    let value: String
    let systemImage: String?

    init(title: String, value: String, systemImage: String? = nil) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
    }

    var body: some View {
        SidebarControlRow(title: title, systemImage: systemImage) {
            SidebarValuePill(value)
                .textSelection(.enabled)
        }
    }
}

struct SidebarStackedValueRow: View {
    let title: String
    let value: String
    let systemImage: String?

    init(title: String, value: String, systemImage: String? = nil) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 9) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                }

                Text(title)
                    .font(SidebarStyle.bodyFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }

            HStack {
                Spacer(minLength: 0)
                SidebarValuePill(value, minWidth: 0)
            }
                .padding(.leading, systemImage == nil ? 0 : 27)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SidebarSliderControl: View {
    let title: String
    let valueText: String
    let systemImage: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    init(
        title: String,
        valueText: String,
        systemImage: String? = nil,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) {
        self.title = title
        self.valueText = valueText
        self.systemImage = systemImage
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SidebarControlRow(title: title, systemImage: systemImage) {
                SidebarValuePill(valueText)
            }

            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
                .padding(.leading, systemImage == nil ? 0 : 27)
        }
    }
}

struct SidebarValuePill: View {
    let value: String
    let minWidth: CGFloat

    init(_ value: String, minWidth: CGFloat = 54) {
        self.value = value
        self.minWidth = minWidth
    }

    var body: some View {
        Text(value)
            .font(SidebarStyle.valueFont)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(0.88)
            .allowsTightening(true)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(minWidth: minWidth, maxWidth: 150, alignment: .trailing)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            }
    }
}

struct SidebarSubheading: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.4)
            .padding(.top, 2)
    }
}

struct SidebarHintText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(SidebarStyle.bodyFont)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
    }
}

struct SidebarChevronButtonLabel: View {
    var width: CGFloat = SidebarStyle.actionButtonSize.width
    var height: CGFloat = SidebarStyle.actionButtonSize.height

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, height: height)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
    }
}

enum SidebarStyle {
    static let bodyFont = Font.system(size: 13, weight: .medium)
    static let valueFont = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let sectionFill = Color.primary.opacity(0.055)
    static let sectionStroke = Color.primary.opacity(0.07)
    static let actionButtonSize = CGSize(width: 34, height: 24)
    static let sidebarLeadingInset: CGFloat = 20
    static let sidebarTrailingInset: CGFloat = 18
    static let sidebarTopInset: CGFloat = 10
    static let sidebarBottomInset: CGFloat = 38
}

#endif
