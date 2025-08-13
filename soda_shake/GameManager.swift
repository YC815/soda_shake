//
//  GameManager.swift
//  soda_shake
//
//  Created by Yushun Chen on 2025/8/13.
//

import SwiftUI
import CoreMotion
import AudioToolbox

enum GameState {
    case ready
    case playing
    case exploded
}

class GameManager: ObservableObject {
    @Published var gameState: GameState = .ready
    @Published var energyLevel: Double = 0.0
    @Published var isGameActive: Bool = false
    
    private let motionManager = CMMotionManager()
    private var shakeIntensity: Double = 0.0
    private let hapticsController = HapticsController()
    
    @Published var explosionThreshold: Double = 200.0
    private let baseEnergyIncrease: Double = 6.0
    private let shakeThreshold: Double = 4.0
    
    private var isCurrentlyShaking: Bool = false
    private var energyTimer: Timer?
    private var hapticTimer: Timer?
    private var isHapticActive: Bool = false
    
    init() {
        setupMotionDetection()
    }
    
    func startGame() {
        gameState = .playing
        isGameActive = true
        energyLevel = 0.0
        isCurrentlyShaking = false
        
        // 隨機設置爆炸閾值 (180-220)
        explosionThreshold = Double.random(in: 180...220)
        
        startMotionUpdates()
        startEnergyTimer()
        startHapticFeedback()
    }
    
    func resetGame() {
        gameState = .ready
        isGameActive = false
        energyLevel = 0.0
        isCurrentlyShaking = false
        stopMotionUpdates()
        stopEnergyTimer()
        stopHapticFeedback()
    }
    
    private func setupMotionDetection() {
        guard motionManager.isGyroAvailable else { return }
        motionManager.gyroUpdateInterval = 0.1
    }
    
    private func startMotionUpdates() {
        guard motionManager.isGyroAvailable else { return }
        
        motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let gyroData = data, self.isGameActive else { return }
            
            let rotationRate = gyroData.rotationRate
            let intensity = sqrt(pow(rotationRate.x, 2) + pow(rotationRate.y, 2) + pow(rotationRate.z, 2))
            
            self.updateEnergyLevel(with: intensity)
        }
    }
    
    private func stopMotionUpdates() {
        motionManager.stopGyroUpdates()
    }
    
    private func updateEnergyLevel(with intensity: Double) {
        // 只更新搖動狀態，不直接增加能量
        isCurrentlyShaking = intensity > shakeThreshold
    }
    
    private func startEnergyTimer() {
        energyTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isGameActive else { return }
            
            // 每0.5秒檢查一次，如果正在搖動就增加能量
            if self.isCurrentlyShaking {
                let randomFactor = Double.random(in: 0.8...1.2)
                let energyIncrease = self.baseEnergyIncrease * randomFactor
                
                self.energyLevel += energyIncrease
                self.energyLevel = min(self.explosionThreshold, self.energyLevel)
                
                self.updateGameState()
            }
        }
    }
    
    private func stopEnergyTimer() {
        energyTimer?.invalidate()
        energyTimer = nil
    }
    
    private func startHapticFeedback() {
        isHapticActive = true
        scheduleNextHaptic()
    }
    
    private func scheduleNextHaptic() {
        guard isGameActive && isHapticActive else { return }
        
        // 將能量等級轉換為進度值 (0.0 - 1.0)
        let progress = min(1.0, energyLevel / explosionThreshold)
        
        // 使用Core Haptics播放基於進度的震動
        hapticsController.playHaptic(for: progress)
        
        // 根據progress計算下次震動的間隔時間
        // 使用與HapticsController相同的映射邏輯
        let intervalMax: Double = 0.90
        let intervalMin: Double = 0.12
        let nextInterval = intervalMax - (intervalMax - intervalMin) * progress
        
        // 安排下一次震動
        hapticTimer = Timer.scheduledTimer(withTimeInterval: nextInterval, repeats: false) { [weak self] _ in
            self?.scheduleNextHaptic()
        }
    }
    
    private func stopHapticFeedback() {
        isHapticActive = false
        hapticTimer?.invalidate()
        hapticTimer = nil
        hapticsController.stopHaptic()
    }
    
    
    private func updateGameState() {
        if energyLevel >= explosionThreshold {
            gameState = .exploded
            explodeGame()
            // 爆炸時特殊震動
            hapticsController.playExplosionHaptic()
        } else if isGameActive {
            gameState = .playing
        }
    }
    
    private func explodeGame() {
        isGameActive = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.resetGame()
        }
    }
    
    
    deinit {
        stopMotionUpdates()
        stopEnergyTimer()
        stopHapticFeedback()
    }
}