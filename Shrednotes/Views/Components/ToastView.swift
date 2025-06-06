import SwiftUI

struct ToastView: View {
    @Binding var show: Bool
    let message: String
    let icon: String

    var body: some View {
        VStack {
            Spacer()
            if show {
                HStack {
                    Image(systemName: icon)
                    Text(message)
                }
                .padding()
                .background(.ultraThickMaterial)
                .cornerRadius(20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            show = false
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), value: show)
        .padding(.horizontal)
    }
} 