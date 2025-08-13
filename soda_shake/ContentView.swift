//
//  ContentView.swift
//  soda_shake
//
//  Created by Yushun Chen on 2025/8/13.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @State private var screenShake = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                BubbleView(energyLevel: gameManager.energyLevel, gameState: gameManager.gameState)
                
                VStack {
                    Spacer()
                    
                    if gameManager.gameState == .ready {
                        startButton
                    } else if gameManager.gameState == .exploded {
                        explosionText
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .offset(x: screenShake ? 5 : 0)
        .animation(.easeInOut(duration: 0.1), value: screenShake)
        .onChange(of: gameManager.gameState) { _, newState in
            if newState == .exploded {
                createScreenShake()
            }
        }
    }
    
    private var startButton: some View {
        Button(action: {
            gameManager.startGame()
        }) {
            Text("SHAKE TO START")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.blue)
                        .shadow(radius: 10)
                )
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true)
    }
    
    private var explosionText: some View {
        VStack(spacing: 20) {
            Text("💥")
                .font(.system(size: 100))
                .scaleEffect(screenShake ? 1.2 : 1.0)
            
            Text("YOU LOSE!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .scaleEffect(screenShake ? 1.1 : 1.0)
            
            Text("Game will restart automatically...")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    
    private func createScreenShake() {
        screenShake = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            screenShake = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            screenShake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            screenShake = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            screenShake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            screenShake = false
        }
    }
}

#Preview {
    ContentView()
}
