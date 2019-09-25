//
//  PixelTransition.swift
//  PixelTransitions
//
//  Created by Hexagons on 2019-09-25.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import SwiftUI

struct PixelTransition<Content: View>: View {
    var content: () -> ([Content])
    var body: some View {
        let views = content()
        return VStack {
            ForEach(0..<views.count) { i in
                views[i]
            }
        }
    }
}
