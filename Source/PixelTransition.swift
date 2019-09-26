//
//  PixelTransition.swift
//  PixelTransitions
//
//  Created by Hexagons on 2019-09-25.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import SwiftUI

@_functionBuilder
public struct PixelTransitionViewBuilder<Content: View> {
    public static func buildBlock(_ children: Content...) -> [Content] {
        return children
    }
}

class PixelTransitionAnimations {
    
    static let shared = PixelTransitionAnimations()
    
    var displayLink: CADisplayLink!
    
    var frameCallbacks: [(id: UUID, callback: () -> ())] = []
    
    init() {
        displayLink = CADisplayLink(target: self, selector: #selector(frameLoop))
        displayLink!.add(to: RunLoop.main, forMode: .common)
    }
    
    // MARK: - Frame Loop
    
    @objc func frameLoop() {
        for frameCallback in self.frameCallbacks {
            frameCallback.callback()
        }
    }
    
    public enum ListenState {
        case `continue`
        case done
    }
    
    public func listenToFramesUntil(callback: @escaping () -> (ListenState)) {
        let id = UUID()
        frameCallbacks.append((id: id, callback: {
            if callback() == .done {
                self.unlistenToFrames(for: id)
            }
        }))
    }
    
    public func listenToFrames(callback: @escaping () -> ()) {
        frameCallbacks.append((id: UUID(), callback: {
            callback()
        }))
    }
    
    public func unlistenToFrames(for id: UUID) {
        for (i, frameCallback) in self.frameCallbacks.enumerated() {
            if frameCallback.id == id {
                frameCallbacks.remove(at: i)
                break
            }
        }
    }
    
    // MARK: - Transitions
    
    var transitionList: [String: PixelTransitionAnimation] = [:]
    
    func transition(for id: String, index: Binding<Int>, seconds: Double, ease: PixelTransitionEase) -> PixelTransitionAnimation {
        if let transition = transitionList[id] {
            return transition
        } else {
            let transition = PixelTransitionAnimation(index: index, seconds: seconds, ease: ease)
            transitionList[id] = transition
            return transition
        }
    }
    
}

class PixelTransitionAnimation: ObservableObject {
    
    let index: Binding<Int>
    var currentIndex: Int
    @Published var prevIndex: Int
    @Published var nextIndex: Int
    
    let seconds: Double
    let ease: PixelTransitionEase
    
    @Published var acitve: Bool = false
    @Published var fraction: CGFloat = 0.0

    init(index: Binding<Int>, seconds: Double, ease: PixelTransitionEase) {
        self.index = index
        currentIndex = index.wrappedValue
        prevIndex = currentIndex
        nextIndex = currentIndex
        self.seconds = seconds
        self.ease = ease
        PixelTransitionAnimations.shared.listenToFrames {
            let index = self.index.wrappedValue
            if index != self.currentIndex {
                self.currentIndex = index
                self.animate()
            }
        }
//        PixelKit.main.backgroundAlphaCheckerActive = false
    }
    
    func animate() {
        guard !acitve else { return }
        guard currentIndex != nextIndex else { return }
        acitve = true
        nextIndex = currentIndex
        let startDate = Date()
        PixelTransitionAnimations.shared.listenToFramesUntil {
            let linearFraction = CGFloat(min(-startDate.timeIntervalSinceNow / self.seconds, 1.0))
            switch self.ease {
            case .none: self.fraction = linearFraction
            case .in: self.fraction = cos(linearFraction * .pi / 2 + .pi) + 1.0
            case .out: self.fraction = cos(linearFraction * .pi / 2 + .pi + .pi / 2)
            case .inOut: self.fraction = cos(linearFraction * .pi + .pi) / 2 + 0.5
            }
            let isDone = linearFraction == 1.0
            if isDone {
                self.done()
            }
            return isDone ? .done : .continue
        }
    }
    
    func done() {
        acitve = false
        fraction = 0.0
        prevIndex = nextIndex
        if currentIndex != nextIndex {
            animate()
        }
    }
    
}

public enum PixelTransitionWay {
    case left
    case right
    case up
    case down
    var horizontal: Bool {
        [.left, .right].contains(self)
    }
    var veritcal: Bool {
        [.up, .down].contains(self)
    }
}

public enum PixelTransitionAxis {
    case x
    case y
}

public enum PixelTransitionStyle {
    case cross
    case panLeft
    case panRight
    case panUp
    case panDown
    case blur
    case flipLeft
    case flipRight
    case flipUp
    case flipDown
    case zoomIn
    case zoomOut
    var way: PixelTransitionWay? {
        switch self {
        case .panLeft, .flipLeft: return .left
        case .panRight, .flipRight: return .right
        case .panUp, .flipUp: return .up
        case .panDown, .flipDown: return .down
        default: return nil
        }
    }
}

public enum PixelTransitionEase {
    case none
    case `in`
    case out
    case inOut
}

public struct PixelTransition<Content: View>: View {
    let index: Binding<Int>
    let style: PixelTransitionStyle
    let content: [Content]
    @ObservedObject var animation: PixelTransitionAnimation
    public init(id: String, selection index: Binding<Int>, style: PixelTransitionStyle, ease: PixelTransitionEase = .inOut, seconds: Double = 0.5, @PixelTransitionViewBuilder<Content> content: () -> ([Content])) {
        print(id)
        self.index = index
        self.style = style
        self.content = content()
        animation = PixelTransitionAnimations.shared.transition(for: id, index: index, seconds: seconds, ease: ease)
    }
    public var body: some View {
        Group {
            if animation.acitve {
                if style == .cross {
                    PixelTransitionCross(contentA: content[animation.prevIndex], contentB: content[animation.nextIndex], fraction: animation.fraction)
                } else if style == .panLeft || style == .panRight || style == .panUp || style == .panDown {
                    PixelTransitionPan(contentA: content[animation.prevIndex], contentB: content[animation.nextIndex], fraction: animation.fraction, way: style.way!)
                } else if style == .blur {
                    PixelTransitionBlur(contentA: content[animation.prevIndex], contentB: content[animation.nextIndex], fraction: animation.fraction)
                } else if style == .flipLeft || style == .flipRight || style == .flipUp || style == .flipDown {
                   PixelTransitionFlip(contentA: content[animation.prevIndex], contentB: content[animation.nextIndex], fraction: animation.fraction, way: style.way!)
                } else if style == .zoomIn || style == .zoomOut {
                    PixelTransitionZoom(contentA: content[animation.prevIndex], contentB: content[animation.nextIndex], fraction: animation.fraction, direction: style == .zoomIn)
                }
            } else {
                ZStack {
                    content[index.wrappedValue]
                        .opacity(0.0)
                    content[index.wrappedValue]
                }
            }
        }
    }
}

struct PixelTransitionCross<Content: View>: View {
    let contentA: Content
    let contentB: Content
    let fraction: CGFloat
    var body: some View {
        ZStack {
            contentA
                .opacity(1.0 - Double(fraction))
            contentB
                .opacity(Double(fraction))
        }
    }
}

struct PixelTransitionPan<Content: View>: View {
    let contentA: Content
    let contentB: Content
    let fraction: CGFloat
    let way: PixelTransitionWay
    var body: some View {
        GeometryReader { geo in
            ZStack {
                self.contentA
                    .opacity(1.0 - Double(self.fraction))
                    .offset(x: self.way.horizontal ? (self.way == .left ? self.a(geo.size.width) : -self.a(geo.size.width)) : 0,
                            y: self.way.veritcal ? (self.way == .up ? self.a(geo.size.width) : -self.a(geo.size.width)) : 0)
                self.contentB
                    .opacity(Double(self.fraction))
                    .offset(x: self.way.horizontal ? (self.way == .left ? self.b(geo.size.width) : -self.b(geo.size.width)) : 0,
                            y: self.way.veritcal ? (self.way == .up ? self.b(geo.size.width) : -self.b(geo.size.width)) : 0)
            }
        }
    }
    func a(_ val: CGFloat) -> CGFloat {
        fraction * -val
    }
    func b(_ val: CGFloat) -> CGFloat {
        (1.0 - fraction) * val
    }
}

struct PixelTransitionBlur<Content: View>: View {
    let contentA: Content
    let contentB: Content
    let fraction: CGFloat
    var body: some View {
        ZStack {
            contentA
                .opacity(1.0 - Double(fraction))
                .blur(radius: fraction * 25)
            contentB
                .opacity(Double(fraction))
                .blur(radius: (1.0 - fraction) * 25)
        }
    }
}

struct PixelTransitionFlip<Content: View>: View {
    let contentA: Content
    let contentB: Content
    let fraction: CGFloat
    let way: PixelTransitionWay
    var body: some View {
        ZStack {
            contentA
                .opacity(fraction < 0.5 ? 1.0 : 0.0)
                .rotation3DEffect(Angle(radians: Double(fraction) * .pi * ([.left, .down].contains(way) ? -1.0 : 1.0)),
                                  axis: (x: way.veritcal ? 1.0 : 0.0, y: way.horizontal ? 1.0 : 0.0, z: 0.0))
            contentB
                .opacity(fraction > 0.5 ? 1.0 : 0.0)
                .rotation3DEffect(Angle(radians: .pi + Double(fraction) * .pi * ([.left, .down].contains(way) ? -1.0 : 1.0)),
                                  axis: (x: way.veritcal ? 1.0 : 0.0, y: way.horizontal ? 1.0 : 0.0, z: 0.0))
        }
    }
}

struct PixelTransitionZoom<Content: View>: View {
    let kDistance: CGFloat = 0.25
    let contentA: Content
    let contentB: Content
    let fraction: CGFloat
    let direction: Bool
    var body: some View {
        ZStack {
            contentA
                .opacity(1.0 - Double(fraction))
                .scaleEffect(a())
            contentB
                .opacity(Double(fraction))
                .scaleEffect(b())
        }
    }
    func a() -> CGFloat {
        direction ? 1.0 - fraction * kDistance : 1.0 + fraction * kDistance
    }
    func b() -> CGFloat {
        direction ? 1.0 - fraction * kDistance + kDistance : 1.0 + fraction * kDistance - kDistance
    }
}
