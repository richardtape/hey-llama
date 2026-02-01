import SwiftUI

struct EnrollmentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Speaker Enrollment")
                .font(.title)

            Text("Speaker enrollment will be implemented in Milestone 3")
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

#Preview {
    EnrollmentView()
}
