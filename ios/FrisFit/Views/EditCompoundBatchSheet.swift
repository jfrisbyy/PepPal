import SwiftUI

struct EditCompoundBatchSheet: View {
    let compound: ProtocolCompound
    let onSave: (_ vendor: String?, _ batch: String?, _ manufacture: Date?, _ expiration: Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vendorName: String = ""
    @State private var batchNumber: String = ""
    @State private var hasManufactureDate: Bool = false
    @State private var manufactureDate: Date = Date()
    @State private var hasExpirationDate: Bool = false
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Source")
                            inputField(
                                icon: "shippingbox.fill",
                                color: PepTheme.teal,
                                placeholder: "Vendor (e.g. Amino Asylum)",
                                text: $vendorName
                            )
                            inputField(
                                icon: "barcode",
                                color: PepTheme.violet,
                                placeholder: "Batch / Lot number",
                                text: $batchNumber
                            )
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Dates")
                            dateToggleRow(
                                icon: "calendar.badge.plus",
                                color: PepTheme.blue,
                                label: "Manufacture date",
                                hasDate: $hasManufactureDate,
                                date: $manufactureDate
                            )
                            Divider().overlay(PepTheme.separatorColor)
                            dateToggleRow(
                                icon: "calendar.badge.exclamationmark",
                                color: PepTheme.amber,
                                label: "Expiration",
                                hasDate: $hasExpirationDate,
                                date: $expirationDate
                            )
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("Tracked privately on your protocol so you can recall it for refills, recall checks, and AI guidance.")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Batch & Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .onAppear(perform: loadCurrentValues)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "barcode.viewfinder")
                    .font(.title3)
                    .foregroundStyle(PepTheme.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(compound.compoundName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Track the vendor, batch, and dates for this compound.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(PepTheme.textSecondary)
            .tracking(0.5)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderBottom.opacity(0.5), lineWidth: 0.5)
            )
    }

    private func inputField(icon: String, color: Color, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 22)
            TextField(placeholder, text: text)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func dateToggleRow(icon: String, color: Color, label: String, hasDate: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                    .frame(width: 22)
                Text(label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Toggle("", isOn: hasDate)
                    .labelsHidden()
                    .tint(PepTheme.teal)
            }
            if hasDate.wrappedValue {
                DatePicker("", selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 32)
            }
        }
    }

    private func loadCurrentValues() {
        vendorName = compound.vendorName ?? ""
        batchNumber = compound.batchNumber ?? ""
        if let m = compound.manufactureDate {
            manufactureDate = m
            hasManufactureDate = true
        }
        if let e = compound.expirationDate {
            expirationDate = e
            hasExpirationDate = true
        }
    }

    private func save() {
        let trimmedVendor = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBatch = batchNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(
            trimmedVendor.isEmpty ? nil : trimmedVendor,
            trimmedBatch.isEmpty ? nil : trimmedBatch,
            hasManufactureDate ? manufactureDate : nil,
            hasExpirationDate ? expirationDate : nil
        )
        dismiss()
    }
}
