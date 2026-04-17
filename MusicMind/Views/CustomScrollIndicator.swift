//
//  CustomScrollIndicator.swift
//  MusicMindAI
//
//  Кастомный индикатор прокрутки в киберпанк-стиле.
//

import SwiftUI

struct ScrollViewWithCustomIndicator<Content: View>: View {
    let content: Content
    let totalItems: Int
    
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    
    init(totalItems: Int, @ViewBuilder content: () -> Content) {
        self.totalItems = totalItems
        self.content = content()
    }
    
    var progress: CGFloat {
        guard contentHeight > visibleHeight, visibleHeight > 0 else { return 0 }
        let maxOffset = max(0, contentHeight - visibleHeight)
        guard maxOffset > 0 else { return 0 }
        let normalizedOffset = min(maxOffset, max(0, -scrollOffset))
        return min(1.0, max(0.0, normalizedOffset / maxOffset))
    }
    
    var indicatorHeight: CGFloat {
        guard contentHeight > visibleHeight, visibleHeight > 0 else { return 0 }
        let ratio = visibleHeight / contentHeight
        return max(40, visibleHeight * ratio)
    }
    
    var indicatorOffset: CGFloat {
        guard contentHeight > visibleHeight, visibleHeight > 0 else { return 0 }
        let maxOffset = visibleHeight - indicatorHeight
        return progress * maxOffset
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView {
                content
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: contentGeometry.frame(in: .named("scroll")).minY
                                )
                                .preference(
                                    key: ContentHeightPreferenceKey.self,
                                    value: contentGeometry.size.height
                                )
                        }
                    )
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
                contentHeight = value
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            visibleHeight = geometry.size.height
                        }
                        .onChange(of: geometry.size.height) { newValue in
                            visibleHeight = newValue
                        }
                }
            )
            
            // кастомный индикатор справа
            if contentHeight > visibleHeight {
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .top) {
                            // фон трека
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CyberpunkTheme.electricBlue.opacity(0.2))
                                .frame(width: 6)
                            
                            // прогресс с градиентом
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            CyberpunkTheme.neonPink.opacity(0.9),
                                            CyberpunkTheme.neonPink.opacity(0.6)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(
                                    width: 6,
                                    height: indicatorHeight
                                )
                                .offset(y: indicatorOffset)
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: indicatorOffset)
                        }
                    }
                    .frame(width: 6)
                    
                    // счетчик треков
                    Text("\(totalItems)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(CyberpunkTheme.neonPink.opacity(0.7))
                        .padding(.top, 2)
                }
                .padding(.trailing, 6)
            }
        }
    }
}

// MARK: - Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ZStack {
        CyberpunkTheme.backgroundGradient
            .ignoresSafeArea()
        
        ScrollViewWithCustomIndicator(totalItems: 100) {
            VStack(spacing: 12) {
                ForEach(0..<100) { i in
                    Text("Item \(i)")
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(CyberpunkTheme.GlassCardBackgroundLegacy())
                }
            }
            .padding()
        }
    }
}
