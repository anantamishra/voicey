import AppKit
import SwiftUI

// MARK: - Shared building blocks for the settings and setup screens

struct IconTile: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
    }
}

extension View {
    /// Liquid Glass on macOS 26+, frosted material before that.
    @ViewBuilder func glassCard(radius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }.glassCard()
    }
}

struct Separator: View {
    var body: some View {
        Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 0.5).padding(.leading, 42)
    }
}

struct Row<Trailing: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol)
            Text(title).font(.system(size: 13))
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
    }
}

struct SwitchRow: View {
    let symbol: String
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol)
            Text(title).font(.system(size: 13))
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
    }
}

struct MenuPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]
    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options.indices, id: \.self) { Text(options[$0].label).tag(options[$0].value) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }
}

struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 12).padding(.top, 14).padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Footer: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.top, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 20, weight: .bold)).padding(.bottom, 10)
                content
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 34)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
