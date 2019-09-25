//
//  PixelTransition.swift
//  PixelTransitions
//
//  Created by Hexagons on 2019-09-25.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import SwiftUI
import PixelKit

@_functionBuilder
public struct PixelTransitionViewBuilder<Content: View> {
    public static func buildBlock(_ children: Content...) -> [Content] {
        return children
    }
}

class Transitions {
    
    static let shared = Transitions()
    
    var transitionList: [String: Transition] = [:]
    
    func transition(for id: String, index: Binding<Int>, seconds: Double) -> Transition {
        if let transition = transitionList[id] {
            return transition
        } else {
            let transition = Transition(index: index, seconds: seconds)
            transitionList[id] = transition
            return transition
        }
    }
    
}

class Transition: ObservableObject {
    
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
        PixelKit.main.listenToFrames {
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
        PixelKit.main.listenToFramesUntil {
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

public struct PixelTransition<Content: View>: View {
    let index: Binding<Int>
    @ObservedObject var transition: Transition
    var content: [Content]
    public init(id: String, selection index: Binding<Int>, seconds: Double = 0.5, @PixelTransitionViewBuilder<Content> content: () -> ([Content])) {
        print(id)
        self.index = index
        transition = Transitions.shared.transition(for: id, index: index, seconds: seconds)
        self.content = content()
    }
    public var body: some View {
        Group {
            if transition.acitve {
                BlendsPIXUI { () -> ([PIX & PIXOut]) in
                    LevelsPIXUI { () -> (PIXUI) in
//                        PolygonPIXUI()
                        ViewPIXUI {
                            content[transition.prevIndex]
                        }
                    }
                        .opacity(LiveFloat(1.0 - transition.fraction))
                    LevelsPIXUI { () -> (PIXUI) in
//                        CirclePIXUI()
                        ViewPIXUI {
                            content[transition.nextIndex]
                        }
                    }
                        .opacity(LiveFloat(transition.fraction))
                }
                    .blendMode(.over)
//                CrossPIXUI({ () -> (PIXUI) in
//                    ViewPIXUI {
//                        content[transition.prevIndex]
//                    }
//                }) { () -> (PIXUI) in
//                    ViewPIXUI {
//                        content[transition.nextIndex]
//                    }
//                }
//                    .fraction(transition.fraction)
            } else {
                self.content[index.wrappedValue]
            }
        }
    }
}
