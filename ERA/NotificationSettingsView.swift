import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    enum Mode {
        case loading
        case permissionPrompt
        case timePicker
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasConfiguredNotificationTimes") private var hasConfiguredNotificationTimes: Bool = false
    @AppStorage("hasAcceptedNotifications") private var hasAcceptedNotifications: Bool = false
    @EnvironmentObject private var pm: PurchaseManager

    @State private var mode: Mode = .loading
    @State private var glowRotation: Angle = .degrees(0)
    @State private var timeSlots: [Date] = [Date()]

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .task { await loadState() }

                case .permissionPrompt:
                    PermissionPromptView(
                        glowRotation: $glowRotation,
                        onRequest: { await requestNotifications() },
                        onSkip: {
                            dismiss()
                        }
                    )
                    .onAppear {
                        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                            glowRotation = .degrees(360)
                        }
                    }

                case .timePicker:
                    TimePickerView(
                        timeSlots: $timeSlots,
                        glowRotation: $glowRotation,
                        onSave: {
                            Task {
                                await scheduleDailyNotifications(for: timeSlots)
                                hasConfiguredNotificationTimes = true
                                dismiss()
                            }
                        }
                    )
                    .task { await prefillFromPendingRequests() }
                    .onAppear {
                        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                            glowRotation = .degrees(360)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    if pm.isPro {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Era Pro active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "seal")
                            .foregroundColor(.orange)
                        Text("Free plan")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Text(appVersionString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Load current state
    private func loadState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                hasAcceptedNotifications = true
                mode = .timePicker
            case .denied, .notDetermined:
                hasAcceptedNotifications = false
                mode = .permissionPrompt
            @unknown default:
                hasAcceptedNotifications = false
                mode = .permissionPrompt
            }
        }
    }

    // MARK: - Ask for permission
    private func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                hasAcceptedNotifications = granted
                mode = granted ? .timePicker : .permissionPrompt
            }
        } catch {
            await MainActor.run {
                hasAcceptedNotifications = false
                mode = .permissionPrompt
            }
        }
    }

    // MARK: - Prefill from pending requests
    private func prefillFromPendingRequests() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        var dates: [Date] = []
        for req in requests {
            if let trig = req.trigger as? UNCalendarNotificationTrigger,
               trig.repeats,
               let hour = trig.dateComponents.hour,
               let minute = trig.dateComponents.minute {
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = minute
                comps.second = 0
                if let date = Calendar.current.date(from: comps) {
                    dates.append(date)
                }
            }
        }
        dates.sort { $0 < $1 }
        await MainActor.run {
            if !dates.isEmpty {
                timeSlots = dates
            }
        }
    }

    // MARK: - Schedule notifications
    private func scheduleDailyNotifications(for slots: [Date]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else { return }

        await center.removeAllPendingNotificationRequests()

        for date in slots {
            var comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            comps.second = 0

            let content = UNMutableNotificationContent()
            content.title = "Era"
            content.body = "Hey! It's time to take a second to breath"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let id = "era.daily.\(comps.hour ?? 0)-\(comps.minute ?? 0)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}

// MARK: - Permission Prompt View (replicates onboarding notify step feel)
private struct PermissionPromptView: View {
    @Binding var glowRotation: Angle
    var onRequest: () async -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 6) {
                Text("Want to get notified to take a moment to breathe with")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                HStack(spacing: 4) {
                    Text("Era")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("?")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .multilineTextAlignment(.center)

            ZStack {
                Capsule()
                    .fill(Color.clear)
                    .overlay(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "CBAACB"),
                                Color(hex: "FFB5A7"),
                                Color(hex: "CBAACB")
                            ]),
                            center: .center
                        )
                        .rotationEffect(glowRotation)
                        .mask(Capsule().stroke(lineWidth: 10))
                        .blur(radius: 8)
                        .opacity(0.6)
                    )
                    .allowsHitTesting(false)

                Button {
                    Task { await onRequest() }
                } label: {
                    Text("Notify")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(
                            LinearGradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.black.opacity(0.74), lineWidth: 0.5)
                        )
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 40)
            .shadow(color: Color(hex: "CBAACB").opacity(0.9), radius: 25, x: 0, y: 10)

            Button(action: onSkip) {
                Text("Skip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - Time Picker View (replicates onboarding time select)
private struct TimePickerView: View {
    @Binding var timeSlots: [Date]
    @Binding var glowRotation: Angle
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("What time do you want to get notified each day to a")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                HStack(spacing: 4) {
                    Text("breath")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(timeSlots.indices, id: \.self) { idx in
                    HStack {
                        Text("Time")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.7))
                        Spacer()
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { timeSlots[idx] },
                                set: { timeSlots[idx] = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "en_US"))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }

                Button {
                    let base = timeSlots.last ?? Date()
                    if let next = Calendar.current.date(byAdding: .minute, value: 5, to: base) {
                        timeSlots.append(next)
                    } else {
                        timeSlots.append(Date())
                    }
                } label: {
                    HStack {
                        Text("Add Additional Time Slot")
                            .font(.system(size: 16))
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 40)

            ZStack {
                Capsule()
                    .fill(Color.clear)
                    .overlay(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "CBAACB"),
                                Color(hex: "FFB5A7"),
                                Color(hex: "CBAACB")
                            ]),
                            center: .center
                        )
                        .rotationEffect(glowRotation)
                        .mask(Capsule().stroke(lineWidth: 10))
                        .blur(radius: 8)
                        .opacity(0.6)
                    )
                    .allowsHitTesting(false)

                Button(action: onSave) {
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.black.opacity(0.74), lineWidth: 0.5)
                        )
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 40)
            .shadow(color: Color(hex: "CBAACB").opacity(0.9), radius: 25, x: 0, y: 10)
        }
        .padding(.top, 20)
    }
}

private var appVersionString: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    return "Version \(version) (\(build))"
}