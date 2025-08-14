//
//  ContentView.swift
//  ERA
//
//  Created by AJ Picard on 8/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showBreathingView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading) {
                    
                    HStack {
                        Text("June 3rd, 2025")
                            .font(.system(size: 32, weight: .bold))
                        Spacer()
                        Image(systemName: "chart.bar.fill")
                            .font(.title2)
                    }
                    .padding(.horizontal)
              
               
                
                Spacer()
                
                // Body Content
                VStack{
                    
                    HStack(spacing: 8) {
                        Text("It's been")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 18, weight: .regular))
                            Text("1 hour")
                                .font(.system(size: 18, weight: .bold))
                        }
                        Text("&")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .regular))
                            Text("3 Days")
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        
                       
                        
                    }
                    
                    Text("since you've paused to focused on your breathing.")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 0.5)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                            
                // Button
                Button(action: {
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
                
                NavigationLink(
                    destination: BreathingView()
                        .navigationBarHidden(true)
                        .navigationBarBackButtonHidden(true),
                    isActive: $showBreathingView
                ) {
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}