//
//  SodaExplosionHaptics.swift
//  soda_shake
//
//  Created by Yushun Chen on 2025/8/13.
//

import CoreHaptics
import Foundation

class SodaExplosionHaptics {
    
    // MARK: - 時間段定義
    private struct ExplosionTimings {
        static let pressureBuildupDuration: Double = 0.6     // 壓力醞釀
        static let capPopDuration: Double = 0.02             // 瓶蓋啪瞬斷
        static let capReboundDelay: Double = 0.02            // 回彈延遲
        static let mainBurstDuration: Double = 0.30          // 主爆發持續
        static let mainBurstDelay: Double = 0.03             // 主爆發開始延遲
        static let foamFlowDuration: Double = 1.2            // 泡沫瀑流
        static let tailHissDuration: Double = 0.6            // 尾韻嘶嘶
    }
    
    // MARK: - 線性映射參數
    private struct ExplosionParameters {
        // 連續事件強度映射 I_c(p) = lerp(min, max, p)
        static let continuousIntensityMin: Double = 0.55
        static let continuousIntensityMax: Double = 0.95
        
        // 尖銳度映射 S_c(p) = lerp(min, max, p)  
        static let sharpnessMin: Double = 0.2
        static let sharpnessMax: Double = 0.9
        
        // 瞬時事件參數
        static let capPopIntensity: Float = 0.95
        static let capPopSharpness: Float = 0.9
        static let capReboundIntensity: Float = 0.6
        static let capReboundSharpness: Float = 0.8
        
        // 叢發瞬時間隔
        static let burstHitInterval: Double = 0.028
        static let burstHitCount: Int = 3
        
        // 泡沫零星爆裂間隔
        static let bubblePopInterval: Double = 0.10
        static let bubbleJitterRange: Double = 0.01
        
        // 動態參數 (ADSR)
        static let attackTimeMin: Double = 0.012
        static let attackTimeMax: Double = 0.06
        static let decayTimeMin: Double = 0.02  
        static let decayTimeMax: Double = 0.10
        static let releaseTimeMin: Double = 0.02
        static let releaseTimeMax: Double = 0.10
    }
    
    // MARK: - 工具函數
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
    
    private func clamp(_ value: Double, min: Double = 0.0, max: Double = 1.0) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }
    
    // MARK: - 線性映射計算
    private func continuousIntensity(for progress: Double) -> Double {
        return lerp(ExplosionParameters.continuousIntensityMin, 
                    ExplosionParameters.continuousIntensityMax, progress)
    }
    
    private func sharpness(for progress: Double) -> Double {
        return lerp(ExplosionParameters.sharpnessMin, 
                    ExplosionParameters.sharpnessMax, progress)
    }
    
    private func attackTime(for progress: Double) -> Double {
        return lerp(ExplosionParameters.attackTimeMax, 
                    ExplosionParameters.attackTimeMin, progress)
    }
    
    private func decayTime(for progress: Double) -> Double {
        return lerp(ExplosionParameters.decayTimeMax, 
                    ExplosionParameters.decayTimeMin, progress)
    }
    
    private func releaseTime(for progress: Double) -> Double {
        return lerp(ExplosionParameters.releaseTimeMax, 
                    ExplosionParameters.releaseTimeMin, progress)
    }
    
    // MARK: - 主要爆炸特效函數
    func createSodaExplosionPattern(for progress: Double) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        var currentTime: Double = 0.0
        
        // 計算線性映射參數
        let baseIntensity = continuousIntensity(for: progress)
        let baseSharpness = sharpness(for: progress)
        
        // ===== 1. 壓力醞釀階段 (0.0–0.6s) =====
        currentTime = 0.0
        let prepDuration = ExplosionTimings.pressureBuildupDuration
        
        // 主連續事件（強度線性上升）
        let prepEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, 
                                     value: Float(baseIntensity * 0.7)),
                CHHapticEventParameter(parameterID: .hapticSharpness, 
                                     value: Float(baseSharpness * 0.6))
            ],
            relativeTime: currentTime,
            duration: prepDuration
        )
        events.append(prepEvent)
        
        // 強度拉升參數曲線
        let prepIntensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: currentTime, 
                    value: Float(baseIntensity * 0.7)
                ),
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: currentTime + prepDuration, 
                    value: Float(baseIntensity * 0.95)
                )
            ],
            relativeTime: 0.0
        )
        curves.append(prepIntensityCurve)
        
        // 醞釀期間的微脈衝（每0.15s左右一次）
        let pulseInterval: Double = 0.15
        let pulseCount = Int(prepDuration / pulseInterval)
        for i in 0..<pulseCount {
            let pulseTime = currentTime + Double(i) * pulseInterval + Double.random(in: -0.02...0.02)
            if pulseTime < currentTime + prepDuration - 0.05 {
                let pulseEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, 
                                             value: Float(baseIntensity * 0.4)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, 
                                             value: Float(baseSharpness * 0.5))
                    ],
                    relativeTime: pulseTime
                )
                events.append(pulseEvent)
            }
        }
        
        currentTime += prepDuration
        
        // ===== 2. 瓶蓋「啪」瞬斷 (~0.02s) =====
        
        // 主要瓶蓋爆開瞬時
        let capPopEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, 
                                     value: ExplosionParameters.capPopIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, 
                                     value: ExplosionParameters.capPopSharpness)
            ],
            relativeTime: currentTime
        )
        events.append(capPopEvent)
        
        // 回彈效果
        let capReboundEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, 
                                     value: ExplosionParameters.capReboundIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, 
                                     value: ExplosionParameters.capReboundSharpness)
            ],
            relativeTime: currentTime + ExplosionTimings.capReboundDelay
        )
        events.append(capReboundEvent)
        
        currentTime += ExplosionTimings.mainBurstDelay
        
        // ===== 3. 主爆發階段 (0.15–0.45s) =====
        
        let burstDuration = ExplosionTimings.mainBurstDuration
        let burstStartIntensity = baseIntensity * 0.9
        let burstEndIntensity = baseIntensity * 0.6
        
        // 噴流底噪連續事件
        let burstFlowEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, 
                                     value: Float(burstStartIntensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, 
                                     value: Float(baseSharpness * 0.8))
            ],
            relativeTime: currentTime,
            duration: burstDuration
        )
        events.append(burstFlowEvent)
        
        // 底噪強度衰減曲線
        let burstIntensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: currentTime, 
                    value: Float(burstStartIntensity)
                ),
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: currentTime + burstDuration, 
                    value: Float(burstEndIntensity)
                )
            ],
            relativeTime: 0.0
        )
        curves.append(burstIntensityCurve)
        
        // 叢發瞬時事件（「嘭嘭嘭」碎裂感）
        let burstStartTime = currentTime + 0.05
        for k in 0..<ExplosionParameters.burstHitCount {
            let hitIntensity = max(0.0, min(1.0, burstStartIntensity - 0.05 * Double(k)))
            let hitEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, 
                                         value: Float(hitIntensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, 
                                         value: Float(baseSharpness * 0.85))
                ],
                relativeTime: burstStartTime + Double(k) * ExplosionParameters.burstHitInterval
            )
            events.append(hitEvent)
        }
        
        currentTime += burstDuration + 0.05
        
        // ===== 4. 泡沫瀑流階段 (0.4–1.6s) =====
        
        let foamDuration = ExplosionTimings.foamFlowDuration
        let foamStartIntensity = baseIntensity * 0.55
        let foamEndIntensity = baseIntensity * 0.30
        
        // 泡沫流連續事件
        let foamFlowEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, 
                                     value: Float(foamStartIntensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, 
                                     value: Float(baseSharpness * 0.5))
            ],
            relativeTime: currentTime,
            duration: foamDuration
        )
        events.append(foamFlowEvent)
        
        // 泡沫強度衰減曲線
        let foamIntensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: currentTime, 
                    value: Float(foamStartIntensity)
                ),
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: currentTime + foamDuration, 
                    value: Float(foamEndIntensity)
                )
            ],
            relativeTime: 0.0
        )
        curves.append(foamIntensityCurve)
        
        // 零星氣泡爆裂
        let bubbleCount = Int(foamDuration / ExplosionParameters.bubblePopInterval)
        for j in 0..<bubbleCount {
            let jitter = Double.random(in: -ExplosionParameters.bubbleJitterRange...ExplosionParameters.bubbleJitterRange)
            let bubbleTime = currentTime + 0.08 + Double(j) * ExplosionParameters.bubblePopInterval + jitter
            
            if bubbleTime < currentTime + foamDuration - 0.1 {
                let bubbleEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, 
                                             value: Float(foamStartIntensity * 0.5)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, 
                                             value: Float(baseSharpness * 0.4))
                    ],
                    relativeTime: bubbleTime
                )
                events.append(bubbleEvent)
            }
        }
        
        currentTime += foamDuration + 0.05
        
        // ===== 5. 尾韻嘶嘶階段 (1.6–2.2s) =====
        
        let tailDuration = ExplosionTimings.tailHissDuration
        
        // 尾韻低強度連續事件
        let tailHissEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, 
                                     value: Float(baseIntensity * 0.25)),
                CHHapticEventParameter(parameterID: .hapticSharpness, 
                                     value: Float(baseSharpness * 0.3))
            ],
            relativeTime: currentTime,
            duration: tailDuration
        )
        events.append(tailHissEvent)
        
        // 創建樣式
        let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
        return pattern
    }
    
    // MARK: - 播放爆炸特效
    func playSodaExplosion(engine: CHHapticEngine, progress: Double = 1.0) throws -> CHHapticPatternPlayer {
        let pattern = try createSodaExplosionPattern(for: progress)
        let player = try engine.makePlayer(with: pattern)
        
        // 立即開始播放
        try player.start(atTime: 0)
        
        // 在尾韻階段發送動態參數（更清爽的收尾）
        let tailStartTime = ExplosionTimings.pressureBuildupDuration + 
                           ExplosionTimings.mainBurstDelay + 
                           ExplosionTimings.mainBurstDuration + 
                           ExplosionTimings.foamFlowDuration + 0.10
        
        DispatchQueue.main.asyncAfter(deadline: .now() + tailStartTime) {
            do {
                let attack = CHHapticDynamicParameter(
                    parameterID: .hapticAttackTimeControl,
                    value: Float(self.attackTime(for: progress)),
                    relativeTime: 0
                )
                
                let decay = CHHapticDynamicParameter(
                    parameterID: .hapticDecayTimeControl,
                    value: Float(self.decayTime(for: progress)),
                    relativeTime: 0
                )
                
                let release = CHHapticDynamicParameter(
                    parameterID: .hapticReleaseTimeControl,
                    value: Float(self.releaseTime(for: progress)),
                    relativeTime: 0
                )
                
                try player.sendParameters([attack, decay, release], atTime: 0)
            } catch {
                print("Failed to send dynamic parameters: \(error)")
            }
        }
        
        return player
    }
}