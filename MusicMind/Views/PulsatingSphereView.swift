import SwiftUI

private struct GradientBlob: View {
    let gradient: LinearGradient
    let size: CGSize
    let duration: Double
    let offsetAmplitude: CGFloat
    let opacityRange: (Double, Double)

    @State private var isAnimating = false
    var isActive: Bool

    var body: some View {
        Circle()
            .fill(gradient)
            .frame(width: size.width, height: size.height)
            .offset(
                x: isAnimating ? offsetAmplitude : -offsetAmplitude,
                y: isAnimating ? -offsetAmplitude : offsetAmplitude
            )
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? opacityRange.1 : opacityRange.0)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .onChange(of: duration) { newDuration in
                withAnimation(.easeInOut(duration: newDuration).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

struct PulsatingSphereView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private var spec: ThemeSpec { themeManager.currentSpec }

    let subtitle: String
    let subtitleColor: Color
    var isActive: Bool = true
    var isUnauthorized: Bool = false

    @State private var rotation: Double = 0
    @State private var rotationSlow: Double = 0
    @State private var borderPhase: Double = 0
    
    // инженерное меню
    @State private var showDebugMenu = false
    
    // настраиваемые параметры
    @State private var blobSizeMultiplier: Double = 1.0
    @State private var blobDurationMultiplier: Double = 1.0
    @State private var blobAmplitudeMultiplier: Double = 1.0
    @State private var blurRadius: Double = 35
    @State private var backgroundBlurRadius: Double = 25
    @State private var saturation: Double = 1.3
    @State private var contrast: Double = 1.15
    @State private var rotationSpeed: Double = 1.0
    @State private var rotationSlowSpeed: Double = 1.0
    @State private var borderSpeed: Double = 1.0
    @State private var overlaySize: Double = 300
    @State private var cornerRadius: Double = 120
    @State private var overlayOpacity: Double = 0.35

    private var blobConfigs: [(size: CGSize, duration: Double, amplitude: CGFloat, opacityRange: (Double, Double), gradient: LinearGradient)] {
        isUnauthorized ? Self.unauthorizedConfigs : authorizedConfigs
    }

    private var authorizedConfigs: [(size: CGSize, duration: Double, amplitude: CGFloat, opacityRange: (Double, Double), gradient: LinearGradient)] {
        let a = spec.accent
        let s = spec.surface
        return [
            (CGSize(width: 150, height: 150), 1.2, 52, (0.6, 1.0), LinearGradient(colors: [a, .purple], startPoint: .top, endPoint: .bottom)),
            (CGSize(width: 135, height: 135), 1.5, 60, (0.5, 0.95), LinearGradient(colors: [s, .blue], startPoint: .leading, endPoint: .trailing)),
            (CGSize(width: 165, height: 165), 0.9, 45, (0.7, 1.0), LinearGradient(colors: [.purple, a], startPoint: .bottom, endPoint: .top)),
            (CGSize(width: 120, height: 120), 1.8, 67, (0.5, 0.9), LinearGradient(colors: [s, .cyan], startPoint: .trailing, endPoint: .leading)),
            (CGSize(width: 142, height: 142), 1.1, 57, (0.55, 0.85), LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)),
            (CGSize(width: 127, height: 127), 1.4, 63, (0.5, 0.9), LinearGradient(colors: [.orange, a], startPoint: .leading, endPoint: .trailing)),
            (CGSize(width: 157, height: 157), 1.0, 48, (0.45, 0.8), LinearGradient(colors: [.pink, .purple], startPoint: .bottomLeading, endPoint: .topTrailing)),
            (CGSize(width: 112, height: 112), 1.6, 72, (0.5, 0.85), LinearGradient(colors: [.yellow.opacity(0.9), .orange], startPoint: .top, endPoint: .bottom))
        ]
    }

    private static let unauthorizedConfigs: [(size: CGSize, duration: Double, amplitude: CGFloat, opacityRange: (Double, Double), gradient: LinearGradient)] = [
        (CGSize(width: 150, height: 150), 3.0, 30, (0.3, 0.5), LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)], startPoint: .top, endPoint: .bottom)),
        (CGSize(width: 135, height: 135), 3.5, 35, (0.25, 0.45), LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)),
        (CGSize(width: 165, height: 165), 2.5, 25, (0.35, 0.55), LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.5)], startPoint: .bottom, endPoint: .top)),
        (CGSize(width: 120, height: 120), 4.0, 40, (0.25, 0.4), LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.35)], startPoint: .trailing, endPoint: .leading)),
        (CGSize(width: 142, height: 142), 2.8, 32, (0.28, 0.42), LinearGradient(colors: [.gray.opacity(0.45), .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)),
        (CGSize(width: 127, height: 127), 3.2, 38, (0.25, 0.45), LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)),
        (CGSize(width: 157, height: 157), 2.6, 28, (0.22, 0.38), LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.4)], startPoint: .bottomLeading, endPoint: .topTrailing)),
        (CGSize(width: 112, height: 112), 3.8, 42, (0.25, 0.42), LinearGradient(colors: [.gray.opacity(0.45), .gray.opacity(0.35)], startPoint: .top, endPoint: .bottom))
    ]
    
    private var rotationDuration: Double {
        (isUnauthorized ? 12 : 4) / rotationSpeed
    }
    
    private var rotationSlowDuration: Double {
        (isUnauthorized ? 18 : 6) / rotationSlowSpeed
    }
    
    private var borderPhaseDuration: Double {
        (isUnauthorized ? 16 : 8) / borderSpeed
    }

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                // Фоновый слой размытия (глубина)
                ZStack {
                    ForEach(0..<blobConfigs.count, id: \.self) { i in
                        let config = blobConfigs[i]
                        Circle()
                            .fill(config.gradient.opacity(0.4))
                            .frame(
                                width: config.size.width * 0.7 * blobSizeMultiplier,
                                height: config.size.height * 0.7 * blobSizeMultiplier
                            )
                            .blur(radius: backgroundBlurRadius)
                    }
                }
                .rotationEffect(.degrees(-rotationSlow * 0.7))
                .onAppear {
                    withAnimation(.linear(duration: rotationSlowDuration).repeatForever(autoreverses: false)) {
                        rotationSlow = 360
                    }
                }
                .onChange(of: rotationSlowSpeed) { _ in
                    withAnimation(.linear(duration: rotationSlowDuration).repeatForever(autoreverses: false)) {
                        rotationSlow = 360
                    }
                }

                // Основные блобы
                ZStack {
                    ForEach(0..<blobConfigs.count, id: \.self) { i in
                        let config = blobConfigs[i]
                        GradientBlob(
                            gradient: config.gradient,
                            size: CGSize(
                                width: config.size.width * blobSizeMultiplier,
                                height: config.size.height * blobSizeMultiplier
                            ),
                            duration: config.duration * blobDurationMultiplier,
                            offsetAmplitude: config.amplitude * blobAmplitudeMultiplier,
                            opacityRange: config.opacityRange,
                            isActive: isActive
                        )
                        .rotationEffect(.degrees(Double(i) * 45))
                    }
                }
                .rotationEffect(.degrees(rotation))
                .blur(radius: blurRadius)
                .saturation(isUnauthorized ? 0 : saturation)
                .contrast(isUnauthorized ? 0.8 : contrast)
                .onAppear {
                    withAnimation(.linear(duration: rotationDuration).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
                .onChange(of: rotationSpeed) { _ in
                    withAnimation(.linear(duration: rotationDuration).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

                // Glassmorphism overlay
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .frame(width: overlaySize, height: overlaySize)
                    .opacity(overlayOpacity)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                AngularGradient(
                                    colors: isUnauthorized ? [
                                        .gray.opacity(0.4),
                                        .gray.opacity(0.3),
                                        .gray.opacity(0.2),
                                        .gray.opacity(0.3),
                                        .gray.opacity(0.4)
                                    ] : [
                                        spec.accent,
                                        .cyan,
                                        .mint,
                                        .orange,
                                        spec.accent
                                    ],
                                    center: .center
                                ),
                                lineWidth: 2
                            )
                            .rotationEffect(.degrees(borderPhase))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: isUnauthorized ? [
                                        .gray.opacity(0.2),
                                        .gray.opacity(0.15),
                                        .clear
                                    ] : [
                                        spec.accent.opacity(0.5),
                                        .cyan.opacity(0.3),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .onAppear {
                        withAnimation(.linear(duration: borderPhaseDuration).repeatForever(autoreverses: false)) {
                            borderPhase = 360
                        }
                    }
                    .onChange(of: borderSpeed) { _ in
                        withAnimation(.linear(duration: borderPhaseDuration).repeatForever(autoreverses: false)) {
                            borderPhase = 360
                        }
                    }
            }
            .frame(width: 330, height: 330)
            .overlay(alignment: .topTrailing) {
                Button(action: { showDebugMenu.toggle() }) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(8)
            }

            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(subtitleColor.opacity(0.95))
                .multilineTextAlignment(.center)
        }
        .overlay {
            if showDebugMenu {
                debugMenuView
            }
        }
    }
    
    private var debugMenuView: some View {
        ZStack {
            // полупрозрачный фон
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    showDebugMenu = false
                }
            
            // меню
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("инженерное меню")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showDebugMenu = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        menuSection(title: "размеры блобов") {
                            sliderRow(label: "размер", value: $blobSizeMultiplier, range: 0.1...3.0, format: "%.2f")
                        }
                        
                        menuSection(title: "анимация") {
                            sliderRow(label: "длительность", value: $blobDurationMultiplier, range: 0.1...5.0, format: "%.2f")
                            sliderRow(label: "амплитуда смещения", value: $blobAmplitudeMultiplier, range: 0.0...3.0, format: "%.2f")
                        }
                        
                        menuSection(title: "размытие") {
                            sliderRow(label: "основное размытие", value: $blurRadius, range: 0...100, format: "%.0f")
                            sliderRow(label: "фоновое размытие", value: $backgroundBlurRadius, range: 0...100, format: "%.0f")
                        }
                        
                        menuSection(title: "цвет") {
                            sliderRow(label: "насыщенность", value: $saturation, range: 0...3.0, format: "%.2f")
                            sliderRow(label: "контраст", value: $contrast, range: 0...3.0, format: "%.2f")
                        }
                        
                        menuSection(title: "вращение") {
                            sliderRow(label: "скорость основного", value: $rotationSpeed, range: 0.1...5.0, format: "%.2f")
                            sliderRow(label: "скорость фонового", value: $rotationSlowSpeed, range: 0.1...5.0, format: "%.2f")
                            sliderRow(label: "скорость границы", value: $borderSpeed, range: 0.1...5.0, format: "%.2f")
                        }
                        
                        menuSection(title: "overlay") {
                            sliderRow(label: "размер overlay", value: $overlaySize, range: 100...500, format: "%.0f")
                            sliderRow(label: "радиус углов", value: $cornerRadius, range: 0...200, format: "%.0f")
                            sliderRow(label: "прозрачность overlay", value: $overlayOpacity, range: 0...1.0, format: "%.2f")
                        }
                        
                        Button(action: {
                            blobSizeMultiplier = 1.0
                            blobDurationMultiplier = 1.0
                            blobAmplitudeMultiplier = 1.0
                            blurRadius = 35
                            backgroundBlurRadius = 25
                            saturation = 1.3
                            contrast = 1.15
                            rotationSpeed = 1.0
                            rotationSlowSpeed = 1.0
                            borderSpeed = 1.0
                            overlaySize = 300
                            cornerRadius = 120
                            overlayOpacity = 0.35
                        }) {
                            Text("сбросить")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .background(.ultraThinMaterial.opacity(0.3))
            .cornerRadius(20)
            .padding()
        }
    }
    
    @ViewBuilder
    private func menuSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
            content()
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            Slider(value: value, in: range)
                .tint(.white.opacity(0.8))
        }
    }
}