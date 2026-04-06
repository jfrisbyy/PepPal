import SwiftUI

struct NumberInputView: View {
    @Binding var value: String
    let isWeight: Bool
    let onDone: () -> Void
    let onIncrement: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FrisTheme.textSecondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            HStack(spacing: 0) {
                Text(value.isEmpty ? "0" : value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(FrisTheme.textPrimary)

                Text(isWeight ? " lbs" : " reps")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(FrisTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            HStack(spacing: 10) {
                incrementButton(label: "-10", amount: -10)
                incrementButton(label: "-5", amount: -5)
                incrementButton(label: "+5", amount: 5)
                incrementButton(label: "+10", amount: 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(1...9, id: \.self) { digit in
                    numpadButton("\(digit)")
                }
                numpadButton(".")
                numpadButton("0")
                Button {
                    if !value.isEmpty { value.removeLast() }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FrisTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)

            Button(action: onDone) {
                Text("Done")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FrisTheme.cyan)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 8)
        .background(FrisTheme.cardSurface)
    }

    private func incrementButton(label: String, amount: Double) -> some View {
        Button { onIncrement(amount) } label: {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(amount > 0 ? FrisTheme.cyan : FrisTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(amount > 0 ? FrisTheme.cyan.opacity(0.12) : FrisTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func numpadButton(_ digit: String) -> some View {
        Button {
            if digit == "." {
                if isWeight && !value.contains(".") {
                    value += value.isEmpty ? "0." : "."
                }
            } else {
                value += digit
            }
        } label: {
            Text(digit)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(FrisTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(FrisTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
        }
    }
}
