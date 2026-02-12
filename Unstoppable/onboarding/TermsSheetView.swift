import SwiftUI

struct TermsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var didAccept: Bool

    @State private var agreeAll = false
    @State private var isOver16 = false
    @State private var agreeMarketing = false

    private var canProceed: Bool { isOver16 }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Handle the paperwork")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
                .padding(.horizontal, 20)

            Divider()
                .padding(.top, 16)

            // Agree to All
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        let newValue = !agreeAll
                        agreeAll = newValue
                        isOver16 = newValue
                        agreeMarketing = newValue
                    }
                } label: {
                    HStack(spacing: 14) {
                        CheckboxIcon(isChecked: agreeAll)
                        Text("Agree to All")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 20)
                }

                Divider()
                    .padding(.leading, 54)

                // Over 16
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isOver16.toggle()
                        syncAgreeAll()
                    }
                } label: {
                    HStack(spacing: 14) {
                        CheckboxIcon(isChecked: isOver16)
                        HStack(spacing: 0) {
                            Text("I am over 16 years old")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(" (Required)")
                                .font(.body)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 20)
                }

                Divider()
                    .padding(.leading, 54)

                // Marketing
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        agreeMarketing.toggle()
                        syncAgreeAll()
                    }
                } label: {
                    HStack(spacing: 14) {
                        CheckboxIcon(isChecked: agreeMarketing)
                        Text("Agree to marketing use")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            // View marketing terms
                        } label: {
                            Text("View")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 20)
                }
            }

            Spacer()

            Button {
                didAccept = true
                dismiss()
            } label: {
                Text("Done. Move on.")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(canProceed ? .blue : Color(.systemGray4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canProceed)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .interactiveDismissDisabled()
    }

    private func syncAgreeAll() {
        agreeAll = isOver16 && agreeMarketing
    }
}

private struct CheckboxIcon: View {
    let isChecked: Bool

    var body: some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isChecked ? .blue : Color(.systemGray3))
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            TermsSheetView(didAccept: .constant(false))
        }
}
