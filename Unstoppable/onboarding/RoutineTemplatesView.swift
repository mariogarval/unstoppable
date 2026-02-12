import SwiftUI

// MARK: - Public template models

struct TemplateTask: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let duration: Int
}

struct RoutineTemplate: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let tasks: [TemplateTask]
}

// MARK: - Template data

extension RoutineTemplate {
    static let all: [RoutineTemplate] = [
        RoutineTemplate(
            name: "5AM CEO",
            emoji: "\u{1F4BC}",
            tasks: [
                TemplateTask(title: "Wake at 5am", icon: "alarm.fill", duration: 1),
                TemplateTask(title: "Cold shower", icon: "drop.fill", duration: 5),
                TemplateTask(title: "Journaling", icon: "pencil.line", duration: 10),
                TemplateTask(title: "Deep work", icon: "brain.head.profile.fill", duration: 60),
                TemplateTask(title: "Workout", icon: "figure.run", duration: 30)
            ]
        ),
        RoutineTemplate(
            name: "That Girl",
            emoji: "\u{1F338}",
            tasks: [
                TemplateTask(title: "Skincare", icon: "sparkles", duration: 10),
                TemplateTask(title: "Meditation", icon: "brain.head.profile.fill", duration: 10),
                TemplateTask(title: "Healthy breakfast", icon: "fork.knife", duration: 15),
                TemplateTask(title: "Gratitude journal", icon: "heart.text.clipboard", duration: 5),
                TemplateTask(title: "Pilates", icon: "figure.pilates", duration: 30)
            ]
        ),
        RoutineTemplate(
            name: "Minimalist",
            emoji: "\u{1F343}",
            tasks: [
                TemplateTask(title: "Make bed", icon: "bed.double.fill", duration: 2),
                TemplateTask(title: "Drink water", icon: "drop.fill", duration: 1),
                TemplateTask(title: "10min meditation", icon: "brain.head.profile.fill", duration: 10),
                TemplateTask(title: "No phone 1hr", icon: "iphone.slash", duration: 60)
            ]
        ),
        RoutineTemplate(
            name: "Gym Bro",
            emoji: "\u{1F4AA}",
            tasks: [
                TemplateTask(title: "Pre-workout", icon: "bolt.heart", duration: 5),
                TemplateTask(title: "Gym session", icon: "dumbbell.fill", duration: 60),
                TemplateTask(title: "Protein shake", icon: "cup.and.saucer.fill", duration: 5),
                TemplateTask(title: "Meal prep", icon: "fork.knife", duration: 30)
            ]
        ),
        RoutineTemplate(
            name: "Student Grind",
            emoji: "\u{1F4DA}",
            tasks: [
                TemplateTask(title: "Review notes", icon: "book.fill", duration: 20),
                TemplateTask(title: "Coffee", icon: "cup.and.saucer.fill", duration: 5),
                TemplateTask(title: "Focus session", icon: "brain.head.profile.fill", duration: 45),
                TemplateTask(title: "Exercise break", icon: "figure.walk", duration: 15)
            ]
        )
    ]
}

// MARK: - Templates View

struct RoutineTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: ([TemplateTask]) -> Void
    let onCreateCustom: () -> Void

    @State private var selectedTemplate: RoutineTemplate?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(RoutineTemplate.all) { template in
                        TemplateCard(template: template) {
                            selectedTemplate = template
                        }
                    }

                    // Create Custom card
                    CreateCustomCard {
                        dismiss()
                        onCreateCustom()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                TemplateDetailSheet(template: template) { tasks in
                    dismiss()
                    onSelect(tasks)
                }
            }
        }
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: RoutineTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Text(template.emoji)
                    .font(.system(size: 36))
                    .frame(width: 56, height: 56)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(template.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(template.tasks.count) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
    }
}

// MARK: - Create Custom Card

private struct CreateCustomCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 56, height: 56)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("Do It Yourself")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Your rules")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(Color(.systemGray4))
            )
        }
    }
}

// MARK: - Template Detail Sheet

private struct TemplateDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: RoutineTemplate
    let onUse: ([TemplateTask]) -> Void

    private var totalMinutes: Int {
        template.tasks.reduce(0) { $0 + $1.duration }
    }

    private var durationText: String {
        if totalMinutes >= 60 {
            let hrs = totalMinutes / 60
            let mins = totalMinutes % 60
            return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
        }
        return "\(totalMinutes) min"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Text(template.emoji)
                            .font(.system(size: 56))

                        Text(template.name)
                            .font(.title.bold())

                        HStack(spacing: 16) {
                            Label("\(template.tasks.count) tasks", systemImage: "checklist")
                            Label(durationText, systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.orange.opacity(0.05))

                    // Task list
                    VStack(spacing: 0) {
                        ForEach(Array(template.tasks.enumerated()), id: \.element.id) { index, task in
                            HStack(spacing: 14) {
                                Image(systemName: task.icon)
                                    .font(.body)
                                    .foregroundStyle(.orange)
                                    .frame(width: 32, height: 32)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.body)
                                    Text("\(task.duration) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("\(index + 1)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                            .padding(.horizontal, 20)
                            .frame(minHeight: 56)

                            if index < template.tasks.count - 1 {
                                Divider()
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onUse(template.tasks)
                } label: {
                    Text("Lock This In")
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [.orange, .yellow.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    RoutineTemplatesView(
        onSelect: { _ in },
        onCreateCustom: {}
    )
}
