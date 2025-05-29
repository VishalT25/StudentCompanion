import SwiftUI

struct IslandSmasherGameView: View {
    @Environment(\.dismiss) var dismiss
    
    // Game state
    @State private var ballPosition: CGPoint = .zero 
    @State private var ballVelocity: CGVector = .zero 
    @State private var paddlePositionX: CGFloat = .zero
    @State private var score = 0
    @State private var highScore = UserDefaults.standard.integer(forKey: "islandSmasherHighScore")
    @State private var isGameOver = false
    
    // Game constants
    let ballRadius: CGFloat = 10
    let paddleWidth: CGFloat = 100
    let paddleHeight: CGFloat = 20
    let dynamicIslandY: CGFloat = 50 
    let dynamicIslandHeight: CGFloat = 30
    let dynamicIslandWidth: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TimelineView(.animation) { timelineContext in
                    VStack(spacing: 0) {
                        Text("Timeline: \(String(format: "%.2f", timelineContext.date.timeIntervalSinceReferenceDate)) | V: \(String(format: "%.1f,%.1f", ballVelocity.dx, ballVelocity.dy)) | P: \(String(format: "%.1f,%.1f", ballPosition.x, ballPosition.y))")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.5))

                        Canvas { context, size in
                            updateGame(size: size, timelineDate: timelineContext.date) // Call update *before* drawing
                            
                            // --- Draw ---
                            let islandRect = CGRect(
                                x: (size.width - dynamicIslandWidth) / 2,
                                y: dynamicIslandY - dynamicIslandHeight / 2,
                                width: dynamicIslandWidth,
                                height: dynamicIslandHeight
                            )
                            context.fill(Path(roundedRect: islandRect, cornerRadius: dynamicIslandHeight / 2), with: .color(.purple.opacity(0.7)))
                            context.draw(Text("Target").font(.caption).foregroundColor(.white), at: CGPoint(x: size.width / 2, y: dynamicIslandY))

                            let paddleRect = CGRect(
                                x: paddlePositionX - paddleWidth / 2,
                                y: size.height - paddleHeight - 30,
                                width: paddleWidth,
                                height: paddleHeight
                            )
                            context.fill(Path(roundedRect: paddleRect, cornerRadius: 5), with: .color(.blue))
                            
                            if !ballPosition.equalTo(.zero) {
                                let ballPath = Path(ellipseIn: CGRect(x: ballPosition.x - ballRadius, y: ballPosition.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2))
                                context.fill(ballPath, with: .color(.yellow))
                            }
                        }
                        .overlay(gameOverOverlay(geometrySize: geometry.size))
                        .gesture(paddleDragGesture(geometrySize: geometry.size))
                        .onTapGesture { if isGameOver { resetGame(size: geometry.size) } }
                    }
                }
            }
            .background(Color.black)
            .ignoresSafeArea(.container, edges: .bottom)
            .overlay(alignment: .top) { scoreDisplay }
            .onAppear {
                 resetGame(size: geometry.size) 
            }
        }
        .navigationTitle("Island Smasher")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreDisplay: some View {
        HStack {
            Text("Score: \(score)")
            Spacer()
            Text("HS: \(highScore)") // Shorter for High Score
        }
        .font(.callout)
        .foregroundColor(.white)
        .padding(.horizontal)
        .padding(.top, 5) 
    }

    @ViewBuilder
    private func gameOverOverlay(geometrySize: CGSize) -> some View {
        if isGameOver {
            VStack {
                Text("Game Over!").font(.largeTitle).foregroundColor(.red)
                Text("Score: \(score)").font(.title2).foregroundColor(.white)
                Button("Play Again") { resetGame(size: geometrySize) }
                    .padding().foregroundColor(.white).background(Color.green).cornerRadius(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.75))
        }
    }

    private func paddleDragGesture(geometrySize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isGameOver {
                    self.paddlePositionX = value.location.x
                    self.paddlePositionX = max(paddleWidth / 2, min(geometrySize.width - paddleWidth / 2, self.paddlePositionX))
                }
            }
    }

    func updateGame(size: CGSize, timelineDate: Date) {
        // Comment out print statements for now to reduce log noise, unless specifically debugging an issue
        // print("--- IslandSmasher Update ---")
        // print("Time: \(timelineDate.timeIntervalSinceReferenceDate)")
        // print("isGameOver: \(isGameOver)")
        // print("Canvas Size: \(size)")
        // print("Ball Position Before: \(ballPosition)")
        // print("Ball Velocity Before: \(ballVelocity)")

        guard !isGameOver, size.width > 0, size.height > 0 else { return }

        // CHANGE: Directly modify ballPosition components
        ballPosition.x += ballVelocity.dx
        ballPosition.y += ballVelocity.dy
        
        // print("Ball Position After Move: \(ballPosition)")
        
        let ballRect = CGRect(x: ballPosition.x - ballRadius, y: ballPosition.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)

        // Walls
        if ballRect.minX <= 0 || ballRect.maxX >= size.width {
            ballVelocity.dx *= -1
            ballPosition.x = max(ballRadius, min(size.width - ballRadius, ballPosition.x)) 
        }
        if ballRect.minY <= 0 {
            ballVelocity.dy *= -1
            ballPosition.y = ballRadius
        }
        
        // Paddle
        let paddleRect = CGRect(x: paddlePositionX - paddleWidth / 2, y: size.height - paddleHeight - 30, width: paddleWidth, height: paddleHeight)
        if ballRect.intersects(paddleRect) && ballVelocity.dy > 0 {
            ballVelocity.dy *= -1
            ballPosition.y = paddleRect.minY - ballRadius 
        }
        
        // Island Target
        let islandHitBox = CGRect(
            x: (size.width - dynamicIslandWidth) / 2, // Original hitbox
            y: dynamicIslandY - dynamicIslandHeight / 2,
            width: dynamicIslandWidth,
            height: dynamicIslandHeight
        )
        if ballRect.intersects(islandHitBox) {
            score += 1
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "islandSmasherHighScore")
            }
            ballVelocity.dy *= -1 
            ballPosition.y = islandHitBox.maxY + ballRadius 
        }

        // Game Over
        if ballRect.minY > size.height { 
            isGameOver = true
        }
    }
    
    func resetGame(size: CGSize) {
        // print("--- IslandSmasher Reset Game ---")
        // print("Resetting with size: \(size)")
        
        if size.width > 0 && size.height > 0 {
            ballPosition = CGPoint(x: size.width / 2, y: size.height / 3)
            paddlePositionX = size.width / 2
        } else {
            let fallbackWidth: CGFloat = 390 
            let fallbackHeight: CGFloat = 700 
            ballPosition = CGPoint(x: fallbackWidth / 2, y: fallbackHeight / 3)
            paddlePositionX = fallbackWidth / 2
            // print("Warning: ResetGame called with zero size, using fallback dimensions.")
        }
        
        // Fixed initial velocity for testing
        ballVelocity = CGVector(dx: 2.5, dy: 2.5) // Let's try slightly slower fixed values
        score = 0
        isGameOver = false
        // print("Reset Ball Position: \(ballPosition)")
        // print("Reset Ball Velocity: \(ballVelocity)")
    }
}
