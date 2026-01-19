import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [WaterEntry]
    
    // State for celebration
    @State private var confettiCounter = 0
    @State private var previousProgress: Double = 0
    
    // State for reset alert
    @State private var showResetAlert = false
    
    // State for water animation trigger
    @State private var waterAddedTrigger = 0
    
    // Dynamic goal from AppStorage
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    
    // Containers from AppStorage
    @AppStorage("containers") private var containersJSON = Container.defaults.toJSON()
    
    private var containers: [Container] {
        Array<Container>.fromJSON(containersJSON)
    }
    
    // Calculate today's total
    private var todayTotal: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = allEntries.filter { entry in
            Calendar.current.isDate(entry.timestamp, inSameDayAs: today)
        }
        return todayEntries.reduce(0) { $0 + $1.amountML }
    }
    
    // Calculate progress for visual (capped at 1.0)
    private var progress: Double {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return min(ratio, 1.0)
    }
    
    // Calculate actual percentage (can go above 100%)
    private var percentageValue: Int {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return Int(ratio * 100)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Water Glass with Enhanced Physics
                    EnhancedWaterGlassView(
                        progress: progress,
                        currentAmount: todayTotal,
                        goalAmount: dailyGoalML,
                        percentage: percentageValue,
                        waterAddedTrigger: waterAddedTrigger
                    )
                    .frame(height: 300)
                    .padding(.top, 30)
                    
                    // Container quick-add buttons
                    if containers.isEmpty {
                        Text("Add containers in Settings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(containers.prefix(6)) { container in
                                ContainerButton(container: container, action: addWater)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
                    // Reset button
                    Button(action: {
                        showResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Today")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .dismissKeyboardOnTap()
            .overlay(
                // Celebration overlay
                Group {
                    if progress >= 1.0 {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 20) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundStyle(.green)
                                    .scaleEffect(confettiCounter > 0 ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: confettiCounter)
                                
                                Text("Goal Reached! 🎉")
                                    .font(.title.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .opacity(confettiCounter > 0 && confettiCounter < 2 ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.3), value: confettiCounter)
                    }
                }
            )
            .alert("Reset Today's Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetTodayData()
                }
            } message: {
                Text("This will delete all water entries for today. This action cannot be undone.")
            }
        }
    }
    
    // Function to add water entry with haptics & celebration
    private func addWater(amount: Int) {
        let oldProgress = progress
        
        // Add entry
        let entry = WaterEntry(timestamp: Date(), amountML: amount)
        modelContext.insert(entry)
        
        // Trigger water animation
        waterAddedTrigger += 1
        
        // Light haptic feedback for button tap
        HapticManager.shared.impact(style: .light)
        
        // Check if goal was just reached
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if oldProgress < 1.0 && progress >= 1.0 {
                // Goal reached! Success haptic + celebration
                HapticManager.shared.notification(type: .success)
                confettiCounter = 1
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    confettiCounter = 2
                }
            }
        }
    }
    
    // Function to reset today's data
    private func resetTodayData() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = allEntries.filter { entry in
            Calendar.current.isDate(entry.timestamp, inSameDayAs: today)
        }
        
        for entry in todayEntries {
            modelContext.delete(entry)
        }
        
        // Reset celebration counter
        confettiCounter = 0
        
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Container Button Component
struct ContainerButton: View {
    let container: Container
    let action: (Int) -> Void
    
    var body: some View {
        Button(action: { action(container.volumeML) }) {
            VStack(spacing: 8) {
                Text(container.emoji)
                    .font(.system(size: 32))
                Text(container.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(container.volumeML) mL")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Water Glass Component
struct EnhancedWaterGlassView: View {
    let progress: Double
    let currentAmount: Int
    let goalAmount: Int
    let percentage: Int
    let waterAddedTrigger: Int
    
    @State private var wavePhase: Double = 0
    @State private var bubbles: [BubbleParticle] = []
    
    let glassThickness: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.65, 220)
            let height = geometry.size.height * 0.85
            let waterHeight = height * CGFloat(min(max(progress, 0.05), 1.0))
            
            ZStack {
                // 1. Back of Glass (Translucent)
                GlassShape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .white.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
                
                // 2. Water Body
                ZStack(alignment: .bottom) {
                    WaterWaveShape(progress: progress, phase: wavePhase)
                        .fill(
                            LinearGradient(
                                colors: progress >= 1.0 ? [
                                    Color.green.opacity(0.4),
                                    Color.green,
                                    Color.green.opacity(0.9)
                                ] : [
                                    Color.blue.opacity(0.3),
                                    Color.blue,
                                    Color(red: 0, green: 0.2, blue: 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width - glassThickness * 2, height: height - glassThickness)
                        .mask(GlassShape().padding(glassThickness))
                    
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            for bubble in bubbles {
                                let rect = CGRect(
                                    x: bubble.x * size.width,
                                    y: size.height - (bubble.y * size.height),
                                    width: bubble.size,
                                    height: bubble.size
                                )
                                context.opacity = bubble.opacity
                                context.fill(Circle().path(in: rect), with: .color(.white.opacity(0.6)))
                            }
                        }
                    }
                    .frame(width: width - glassThickness * 3, height: waterHeight)
                    .mask(GlassShape().padding(glassThickness))
                }

                // 3. Front Glass Glare
                GlassShape()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.1), location: 0),
                                .init(color: .white.opacity(0.6), location: 0.2),
                                .init(color: .white.opacity(0.1), location: 0.4),
                                .init(color: .white.opacity(0.1), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: width, height: height)
                
                Path { path in
                    path.move(to: CGPoint(x: width * 0.2, y: height * 0.1))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.2, y: height * 0.9),
                        control: CGPoint(x: width * 0.15, y: height * 0.5)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.4), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 4
                )
                .frame(width: width, height: height)

                // 4. Text Overlay
                VStack(spacing: 4) {
                    Text("\(percentage)%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(progress > 0.5 ? .white : .blue)
                        .shadow(color: .black.opacity(progress > 0.5 ? 0.2 : 0), radius: 2)
                    
                    Text("\(currentAmount) / \(goalAmount) mL")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(progress > 0.5 ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            startWaveAnimation()
        }
        .onChange(of: waterAddedTrigger) { _, _ in
            spawnBubbles()
        }
    }
    
    private func startWaveAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            wavePhase += 0.02
        }
    }
    
    private func spawnBubbles() {
        for _ in 0..<15 {
            bubbles.append(BubbleParticle())
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if bubbles.isEmpty { timer.invalidate() }
            
            var activeBubbles: [BubbleParticle] = []
            
            for var bubble in bubbles {
                bubble.y += bubble.speed
                bubble.x += sin(bubble.y * 10) * 0.005
                
                if bubble.y < 1.0 {
                    activeBubbles.append(bubble)
                }
            }
            bubbles = activeBubbles
        }
    }
}

// MARK: - Shapes
struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bottomWidth = rect.width * 0.75
        let taper = (rect.width - bottomWidth) / 2
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: taper, y: rect.height - 15))
        path.addQuadCurve(
            to: CGPoint(x: taper + 15, y: rect.height),
            control: CGPoint(x: taper, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width - taper - 15, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - taper, y: rect.height - 15),
            control: CGPoint(x: rect.width - taper, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        return path
    }
}

struct WaterWaveShape: Shape {
    var progress: Double
    var phase: Double
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        let waterHeight = height * CGFloat(progress)
        let topY = height - waterHeight
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: topY))
        
        if progress > 0 && progress < 1.0 {
            for x in stride(from: width, through: 0, by: -2) {
                let relativeX = x / width
                let sine1 = sin(relativeX * 4 * .pi + phase) * 4
                let sine2 = sin(relativeX * 6 * .pi + phase * 1.5) * 2
                
                let y = topY + sine1 + sine2
                path.addLine(to: CGPoint(x: x, y: y))
            }
        } else {
            path.addLine(to: CGPoint(x: 0, y: topY))
        }
        
        path.closeSubpath()
        return path
    }
}

struct BubbleParticle: Identifiable {
    let id = UUID()
    var x: Double = Double.random(in: 0.1...0.9)
    var y: Double = 0
    var speed: Double = Double.random(in: 0.01...0.02)
    var size: Double = Double.random(in: 4...10)
    var opacity: Double = Double.random(in: 0.4...0.8)
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
