//
//  HapticsController.swift
//  soda_shake
//
//  Created by Yushun Chen on 2025/8/13.
//

import CoreHaptics
import Foundation

class HapticsController: ObservableObject {
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var isEngineStarted = false
    private let explosionHaptics = SodaExplosionHaptics()
    
    // MARK: - 感知優化映射參數配置
    private struct HapticParameters {
        // 感知指數映射 I(p) = Imin + (Imax - Imin) * p^γ (γ<1讓前段更快)
        static let intensityMin: Double = 0.35          // 提高下限讓起步明顯
        static let intensityMax: Double = 0.95
        static let intensityGamma: Double = 0.6         // 前段加權指數
        
        // 尖銳度前段偏高 S(p) = Smin + (Smax - Smin) * p^γ  
        static let sharpnessMin: Double = 0.35          // 起步更清脆
        static let sharpnessMax: Double = 0.90
        static let sharpnessGamma: Double = 0.7
        
        // 基準間隔映射 T(p) = Tmin + (Tmax - Tmin) * (1 - p^γ)
        static let intervalMax: Double = 0.75           // 比原先0.9s更短，開場更有存在感
        static let intervalMin: Double = 0.12
        
        // 微脈衝數量映射 K(p) = round(1 + 2*p) (Kmin=1，一開始就有補脈衝)
        static let pulseCountMin: Double = 1.0          // 起步就有節奏
        static let pulseCountMax: Double = 3.0
        
        // 微脈衝間距映射 d(p) = max(0.02, 0.06 - 0.03*p) 
        static let pulseDeltaMin: Double = 0.02
        static let pulseDeltaMax: Double = 0.06
        
        // 隨機抖動 ε ~ U(-J, +J), J = Jmax * (1 - p)
        static let jitterMax: Double = 0.01
        
        // Attack/Decay/Release 映射 (前段稍長更「彈」)
        static let attackMax: Double = 0.06             // 前段更彈
        static let attackMin: Double = 0.012
        static let decayMax: Double = 0.06  
        static let decayMin: Double = 0.03
        static let releaseMax: Double = 0.05
        static let releaseMin: Double = 0.02
        
        // 脈衝強度比例
        static let pulseIntensityRatio: Double = 0.75
        
        // 立即tap增強比例
        static let immediateTapBoost: Double = 1.05
    }
    
    init() {
        setupEngine()
    }
    
    // MARK: - 引擎設置
    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            
            // 監聽引擎狀態變化
            engine?.stoppedHandler = { [weak self] reason in
                DispatchQueue.main.async {
                    self?.isEngineStarted = false
                    print("Haptic engine stopped: \(reason.rawValue)")
                }
            }
            
            engine?.resetHandler = { [weak self] in
                DispatchQueue.main.async {
                    print("Haptic engine reset")
                    self?.startEngine()
                }
            }
            
            startEngine()
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func startEngine() {
        guard let engine = engine, !isEngineStarted else { return }
        
        do {
            try engine.start()
            isEngineStarted = true
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    // MARK: - 線性映射工具函數
    private func clamp(_ value: Double, min: Double = 0.0, max: Double = 1.0) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }
    
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
    
    // MARK: - 感知優化進度映射函數
    private func intensity(for progress: Double) -> Double {
        let pGamma = pow(progress, HapticParameters.intensityGamma)
        return clamp(HapticParameters.intensityMin + 
                    (HapticParameters.intensityMax - HapticParameters.intensityMin) * pGamma)
    }
    
    private func sharpness(for progress: Double) -> Double {
        let pGamma = pow(progress, HapticParameters.sharpnessGamma)
        return clamp(HapticParameters.sharpnessMin + 
                    (HapticParameters.sharpnessMax - HapticParameters.sharpnessMin) * pGamma)
    }
    
    private func interval(for progress: Double) -> Double {
        let pGamma = pow(progress, HapticParameters.intensityGamma)
        return HapticParameters.intervalMin + 
               (HapticParameters.intervalMax - HapticParameters.intervalMin) * (1.0 - pGamma)
    }
    
    private func pulseCount(for progress: Double) -> Int {
        return Int(round(HapticParameters.pulseCountMin + 
                        (HapticParameters.pulseCountMax - HapticParameters.pulseCountMin) * progress))
    }
    
    private func pulseDelta(for progress: Double) -> Double {
        return max(HapticParameters.pulseDeltaMin, 
                   HapticParameters.pulseDeltaMax - 0.03 * progress)
    }
    
    private func jitterRange(for progress: Double) -> Double {
        return HapticParameters.jitterMax * (1.0 - progress)
    }
    
    private func attackTime(for progress: Double) -> Double {
        // 前段稍長更「彈」，使用感知指數讓前段保持更彈性
        let pGamma = pow(progress, 0.8)
        return lerp(HapticParameters.attackMax, HapticParameters.attackMin, pGamma)
    }
    
    private func decayTime(for progress: Double) -> Double {
        return lerp(HapticParameters.decayMax, HapticParameters.decayMin, progress)
    }
    
    private func releaseTime(for progress: Double) -> Double {
        return lerp(HapticParameters.releaseMax, HapticParameters.releaseMin, progress)
    }
    
    // MARK: - 核心播放函數
    func playHaptic(for progress: Double) {
        guard let engine = engine, isEngineStarted else { return }
        
        do {
            // 計算映射參數
            let I = intensity(for: progress)
            let S = sharpness(for: progress)
            let T = interval(for: progress)
            let K = pulseCount(for: progress)
            let d = pulseDelta(for: progress)
            let jitter = jitterRange(for: progress)
            
            // 0) 立即tap（醒目度）- 每段開始立即打一顆瞬時tap
            let immediateTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, 
                                         value: Float(min(1.0, I * HapticParameters.immediateTapBoost))),
                    CHHapticEventParameter(parameterID: .hapticSharpness, 
                                         value: Float(min(1.0, S * HapticParameters.immediateTapBoost)))
                ],
                relativeTime: 0
            )
            
            // 1) 連續事件（背景張力）
            let continuousEvent = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(I * 0.95)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(S * 0.9))
                ],
                relativeTime: 0,
                duration: T
            )
            
            // 2) 參數曲線優化（前40%時間迅速拉高強度，之後緩降）
            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.0, value: Float(I * 0.95)),
                    CHHapticParameterCurve.ControlPoint(relativeTime: T * 0.4, value: Float(I * 1.0)),
                    CHHapticParameterCurve.ControlPoint(relativeTime: T, value: Float(I * 0.92))
                ],
                relativeTime: 0
            )
            
            let sharpnessCurve = CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.0, value: Float(S * 0.9)),
                    CHHapticParameterCurve.ControlPoint(relativeTime: T * 0.4, value: Float(S * 1.0)),
                    CHHapticParameterCurve.ControlPoint(relativeTime: T, value: Float(S * 0.95))
                ],
                relativeTime: 0
            )
            
            // 3) 瞬時微脈衝事件
            var events: [CHHapticEvent] = [immediateTap, continuousEvent]
            
            for j in 0..<K {
                let randomJitter = Double.random(in: -jitter...jitter)
                let pulseTime = max(0.0, min(T - 0.01, Double(j) * d + randomJitter))
                
                let pulseEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, 
                                             value: Float(I * HapticParameters.pulseIntensityRatio)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(S))
                    ],
                    relativeTime: pulseTime
                )
                events.append(pulseEvent)
            }
            
            // 4) 創建樣式並播放
            let pattern = try CHHapticPattern(
                events: events,
                parameterCurves: [intensityCurve, sharpnessCurve]
            )
            
            player = try engine.makePlayer(with: pattern)
            try player?.start(atTime: 0)
            
            // 5) 發送動態參數（Attack/Decay/Release）
            let attackParam = CHHapticDynamicParameter(
                parameterID: .hapticAttackTimeControl,
                value: Float(attackTime(for: progress)),
                relativeTime: 0
            )
            
            let decayParam = CHHapticDynamicParameter(
                parameterID: .hapticDecayTimeControl,
                value: Float(decayTime(for: progress)),
                relativeTime: 0
            )
            
            let releaseParam = CHHapticDynamicParameter(
                parameterID: .hapticReleaseTimeControl,
                value: Float(releaseTime(for: progress)),
                relativeTime: 0
            )
            
            try player?.sendParameters([attackParam, decayParam, releaseParam], atTime: 0)
            
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
    
    // MARK: - 停止播放
    func stopHaptic() {
        do {
            try player?.stop(atTime: 0)
        } catch {
            print("Failed to stop haptic: \(error)")
        }
        player = nil
    }
    
    // MARK: - 爆炸特效
    func playExplosionHaptic(progress: Double = 1.0) {
        guard let engine = engine, isEngineStarted else { return }
        
        do {
            // 停止當前播放
            stopHaptic()
            
            // 使用多段式汽水爆炸特效
            player = try explosionHaptics.playSodaExplosion(engine: engine, progress: progress)
            
        } catch {
            print("Failed to play soda explosion haptic: \(error)")
        }
    }
    
    // MARK: - 簡化爆炸特效（備用）
    func playSimpleExplosionHaptic() {
        guard let engine = engine, isEngineStarted else { return }
        
        do {
            // 簡單版爆炸：超強瞬時震動序列（作為備用）
            var explosionEvents: [CHHapticEvent] = []
            
            let explosionIntensity: Float = 1.0
            let explosionSharpness: Float = 1.0
            
            // 主爆炸
            let mainExplosion = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: explosionIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: explosionSharpness)
                ],
                relativeTime: 0
            )
            explosionEvents.append(mainExplosion)
            
            // 後續震蕩（8次遞減）
            for i in 1...8 {
                let intensity = explosionIntensity * Float(max(0.2, 1.0 - Double(i) * 0.1))
                let sharpness = explosionSharpness * Float(max(0.1, 1.0 - Double(i) * 0.08))
                let time = Double(i) * 0.06
                
                let aftershock = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: time
                )
                explosionEvents.append(aftershock)
            }
            
            let explosionPattern = try CHHapticPattern(events: explosionEvents, parameters: [])
            let explosionPlayer = try engine.makePlayer(with: explosionPattern)
            try explosionPlayer.start(atTime: 0)
            
        } catch {
            print("Failed to play simple explosion haptic: \(error)")
        }
    }
    
    deinit {
        stopHaptic()
        engine = nil
    }
}