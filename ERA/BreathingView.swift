import SwiftUI

struct BreathingView: View {
    @State private var isAnimating = false
    @State private var isButtonMoved = false
    @State private var showPauseLabel = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            // Animated circles - each with their own gradient
            // Positioned to be visible at the bottom initially
            ZStack {
                // Largest circle (behind)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "CBAACB").opacity(0.3), Color(hex: "FFB5A7").opacity(0.3)]),
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: isAnimating ? UIScreen.main.bounds.width * 2.5 : 150,
                        height: isAnimating ? UIScreen.main.bounds.width * 2.5 : 150
                    )
                    .position(
                        x: UIScreen.main.bounds.width / 2,
                        y: UIScreen.main.bounds.height + (isAnimating ? -UIScreen.main.bounds.height * 0.3 : 75)
                    )
                
                // Medium circle
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "CBAACB").opacity(0.5), Color(hex: "FFB5A7").opacity(0.5)]),
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: isAnimating ? UIScreen.main.bounds.width * 2 : 120,
                        height: isAnimating ? UIScreen.main.bounds.width * 2 : 120
                    )
                    .position(
                        x: UIScreen.main.bounds.width / 2,
                        y: UIScreen.main.bounds.height + (isAnimating ? -UIScreen.main.bounds.height * 0.2 : 60)
                    )
                
                // Smallest circle (in front)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "CBAACB").opacity(0.7), Color(hex: "FFB5A7").opacity(0.7)]),
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: isAnimating ? UIScreen.main.bounds.width * 1.5 : 90,
                        height: isAnimating ? UIScreen.main.bounds.width * 1.5 : 90
                    )
                    .position(
                        x: UIScreen.main.bounds.width / 2,
                        y: UIScreen.main.bounds.height + (isAnimating ? -UIScreen.main.bounds.height * 0.1 : 45)
                    )
            }
            .animation(.easeInOut(duration: 4.0), value: isAnimating)
           
            
            // Breath/Pause button - animating from bottom to final position
            Button(action: {
                // Button action can be defined later
            }) {
                Text(showPauseLabel ? "Pause Breathing" : "Breath")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentTransition(.interpolate)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.3)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.3)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
            .padding(.horizontal, 50)
            .frame(maxWidth: .infinity)
            .position(
                x: UIScreen.main.bounds.width / 2,
                y: isButtonMoved ? UIScreen.main.bounds.height - 160 : UIScreen.main.bounds.height + 30
            )
            .animation(.easeInOut(duration: 2), value: isButtonMoved)
            .animation(.easeInOut(duration: 0.3), value: showPauseLabel)
        }
        .onAppear {
            // Start button animation immediately when view appears
            isButtonMoved = true
            
            // Start circle animation after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = true
            }
            
            // Change button label after circle animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
                withAnimation {
                    showPauseLabel = true
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    BreathingView()
}
