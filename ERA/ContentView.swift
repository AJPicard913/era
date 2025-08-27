//
//  ContentView.swift
//  ERA
//
//  Created by AJ Picard on 8/12/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var showBreathingView = false
    @Environment(\.managedObjectContext) private var viewContext

    // Sort with string key to avoid key-path issues
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "endedAt", ascending: false)],
        animation: .default
    ) private var sessions: FetchedResults<BreathingSession>

    // keep "now" ticking so UI updates as time passes
    @State private var now = Date()
    
    // Track when a session was just completed to avoid showing "It's been" immediately
    @State private var sessionJustCompleted = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading) {
                    // Title row with formatted date
                    HStack {
                        Text(now, format: .dateTime.month().day().year()) // Shows "August 19, 2025"
                            .font(.system(size: 32, weight: .bold))
                        Spacer()
                        Image(systemName: "chart.bar.fill")
                            .font(.title2)
                    }
                    .padding(.horizontal)

                    Spacer().frame(height: 180)

                    // Body Content
                    VStack {
                        if let last = lastSessionDate, !sessionJustCompleted {
                            let timeComponents = timeSince(last, to: now) // (days, hours, minutes)


                            // Time information in an HStack below (days first, then hrs/mins)
                            HStack(spacing: 8) {
                                HStack(spacing: 2) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 18, weight: .regular))
                                    Text("\(timeComponents.days) Day\(timeComponents.days == 1 ? "" : "s")")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                
                                Text("&")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)

                                if timeComponents.totalMinutes < 60 {
                                    // Show only minutes when under 1 hour
                                    HStack(spacing: 2) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 18, weight: .regular))
                                        Text("\(timeComponents.totalMinutes) min")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                } else {
                                    // Show hours and minutes when 1 hour or more
                                    HStack(spacing: 2) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 18, weight: .regular))
                                        Text("\(timeComponents.hours) hr \(timeComponents.minutes) min")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                }
                            }

                            // Description text below
                            Text("since you've paused to focus on your breathing.")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.top, 0.5)
                        } else if sessionJustCompleted {
                            // Show success message when session just completed
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.green)
                                Text("Great job!")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("You've completed your breathing session.")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 20)
                        } else {
                            // First run / no sessions yet
                            HStack(spacing: 8) {
                                Image(systemName: "leaf")
                                Text("Let's take your first breathing session.")
                                    .foregroundColor(.gray)
                            }
                            .font(.system(size: 18))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)

                    // Start button
                    Button(action: { 
                        sessionJustCompleted = false
                        showBreathingView = true 
                    }) {
                        Text("Start Breathing")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "CBAACB"), Color(hex: "FFB5A7")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.black.opacity(0.74), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 50)
                    .padding(.bottom, 30)
                    .padding(.top, 25)
                    .shadow(color: Color(hex: "CBAACB").opacity(0.9), radius: 25, x: 0, y: 10)

                    Spacer()
                }
                .padding(.top)
                
                .fullScreenCover(isPresented: $showBreathingView) {
                    BreathingView()
                        .environment(\.managedObjectContext, viewContext)
                        .ignoresSafeArea()
                        .onDisappear {
                            // Set sessionJustCompleted to true when BreathingView is dismissed
                            sessionJustCompleted = true
                        }
                }
            }
        }
        // tick 'now' every minute so the text stays current
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    // Prefer endedAt; fall back to startedAt. Use KVC to avoid type mismatches.
    private var lastSessionDate: Date? {
        guard let s = sessions.first else { return nil }
        if let d = s.value(forKey: "endedAt") as? Date { return d }
        if let d = s.value(forKey: "startedAt") as? Date { return d }
        return nil
    }

    // Return time components (days, hours, minutes, totalMinutes)
    private func timeSince(_ from: Date, to: Date) -> (days: Int, hours: Int, minutes: Int, totalMinutes: Int) {
        let seconds = max(0, Int(to.timeIntervalSince(from)))
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let days = hours / 24
        
        return (days: days, hours: hours, minutes: minutes, totalMinutes: totalMinutes)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
