//
//  BubbleView.swift
//  soda_shake
//
//  Created by Yushun Chen on 2025/8/13.
//

import SwiftUI

struct Bubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: CGFloat
}

struct BubbleView: View {
    @State private var bubbles: [Bubble] = []
    let energyLevel: Double
    let gameState: GameState
    
    private var bubbleCount: Int {
        // 基礎氣泡數 + 能量相關氣泡數
        let baseCount = 5 // 基礎氣泡數量
        let energyBubbles = Int(energyLevel / 3) // 每3能量增加1個氣泡
        return min(50, baseCount + energyBubbles) // 最多50個氣泡
    }
    
    private var bubbleColor: Color {
        switch gameState {
        case .playing:
            return .blue.opacity(0.6)
        case .exploded:
            return .red.opacity(0.8)
        default:
            return .blue.opacity(0.3)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(bubbleColor)
                        .frame(width: bubble.size, height: bubble.size)
                        .position(x: bubble.x, y: bubble.y)
                        .opacity(bubble.opacity)
                }
            }
            .onAppear {
                startBubbleAnimation(in: geometry.size)
            }
            .onChange(of: energyLevel) { _, _ in
                updateBubbles(in: geometry.size)
            }
            .onChange(of: gameState) { _, newState in
                if newState == .exploded {
                    createExplosionEffect(in: geometry.size)
                } else if newState == .ready {
                    bubbles.removeAll()
                } else if newState == .playing {
                    // 遊戲開始時重新啟動動畫
                    startBubbleAnimation(in: geometry.size)
                }
            }
        }
    }
    
    private func startBubbleAnimation(in size: CGSize) {
        // 確保氣泡開始移動
        updateBubbles(in: size)
        
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if gameState == .ready || gameState == .exploded {
                timer.invalidate()
                return
            }
            
            animateBubbles(in: size)
        }
    }
    
    private func updateBubbles(in size: CGSize) {
        let targetCount = min(bubbleCount, 50)
        let currentCount = bubbles.count
        
        if targetCount > currentCount {
            for _ in 0..<(targetCount - currentCount) {
                addBubble(in: size)
            }
        } else if targetCount < currentCount {
            bubbles.removeLast(currentCount - targetCount)
        }
    }
    
    private func addBubble(in size: CGSize) {
        let bubble = Bubble(
            x: CGFloat.random(in: 20...(size.width - 20)),
            y: CGFloat.random(in: 0...size.height), // 隨機分佈在整個畫面
            size: CGFloat.random(in: 8...25),
            opacity: Double.random(in: 0.4...0.9),
            speed: CGFloat.random(in: 2.0...8.0)
        )
        bubbles.append(bubble)
    }
    
    private func animateBubbles(in size: CGSize) {
        for i in bubbles.indices {
            // 氣泡向上移動
            bubbles[i].y -= bubbles[i].speed
            
            // 當氣泡飛到頂部時，從底部重新開始
            if bubbles[i].y < -30 {
                bubbles[i].x = CGFloat.random(in: 20...(size.width - 20))
                bubbles[i].y = size.height + 30
                bubbles[i].size = CGFloat.random(in: 8...25)
                bubbles[i].opacity = Double.random(in: 0.4...0.9)
                bubbles[i].speed = CGFloat.random(in: 2.0...8.0)
            }
            
            // 氣泡有輕微的水平晃動
            bubbles[i].x += CGFloat.random(in: -0.3...0.3)
            
            // 保持氣泡在畫面內
            bubbles[i].x = max(10, min(size.width - 10, bubbles[i].x))
        }
    }
    
    private func createExplosionEffect(in size: CGSize) {
        bubbles.removeAll()
        
        for _ in 0..<20 {
            let bubble = Bubble(
                x: size.width / 2,
                y: size.height / 2,
                size: CGFloat.random(in: 20...60),
                opacity: 0.9,
                speed: CGFloat.random(in: 5...15)
            )
            bubbles.append(bubble)
        }
        
        withAnimation(.easeOut(duration: 1.0)) {
            for i in bubbles.indices {
                let angle = Double.random(in: 0...(2 * Double.pi))
                let distance = CGFloat.random(in: 100...300)
                
                bubbles[i].x += cos(angle) * distance
                bubbles[i].y += sin(angle) * distance
                bubbles[i].opacity = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            bubbles.removeAll()
        }
    }
}