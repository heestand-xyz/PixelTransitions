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
    
    func transition(for id: String, index: Binding<Int>, seconds: Double) -> PixelTransitionAnimation {
        if let transition = transitionList[id] {
            return transition
        } else {
            let transition = PixelTransitionAnimation(index: index, seconds: seconds)
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
    
    @Published var acitve: Bool = false
    @Published var fraction: CGFloat = 0.0

    init(index: Binding<Int>, seconds: Double) {
        self.index = index
        currentIndex = index.wrappedValue
        prevIndex = currentIndex
        nextIndex = currentIndex
        self.seconds = seconds
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
            self.fraction = CGFloat(min(-startDate.timeIntervalSinceNow / self.seconds, 1.0))
            let isDone = self.fraction == 1.0
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
}

public enum PixelTransitionStyle {
    case cross
    case panLeft
    case panRight
    case panUp
    case panDown
    var way: PixelTransitionWay? {
        switch self {
        case .cross: return nil
        case .panLeft: return .left
        case .panRight: return .right
        case .panUp: return .up
        case .panDown: return .down
        }
    }
}

public struct PixelTransition<Content: View>: View {
    let index: Binding<Int>
    let style: PixelTransitionStyle
    let content: [Content]
    @ObservedObject var animation: PixelTransitionAnimation
    public init(id: String, selection index: Binding<Int>, style: PixelTransitionStyle, seconds: Double = 0.5, @PixelTransitionViewBuilder<Content> content: () -> ([Content])) {
        print(id)
        self.index = index
        self.style = style
        self.content = content()
        animation = PixelTransitionAnimations.shared.transition(for: id, index: index, seconds: seconds)
    }
    public var body: some View {
        Group {
            if animation.acitve {
                if style == .cross {
                    PixelTransitionCross(contentA: content[animation.prevIndex], contentB: content[animation.nextIndex], fraction: animation.fraction)
                } else if style == .panLeft || style == .panRight || style == .panUp || style == .panDown {
                    EmptyView()
                    PixelTransitionPan(contentA: content[animation.prevIndex], contentB: content[animation.nextIndex], fraction: animation.fraction, way: style.way!)
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
                    .offset(x: self.fraction * -geo.size.width, y: 0)
                self.contentB
                    .opacity(Double(self.fraction))
                    .offset(x: (1.0 - self.fraction) * geo.size.width, y: 0)
            }
        }
    }
}
