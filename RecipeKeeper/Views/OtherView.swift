import SwiftUI

struct OtherView: View {
  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            SettingsContentView()
          } label: {
            Label("设置", systemImage: "gearshape")
          }

          NavigationLink {
            ExerciseProgressionView()
          } label: {
            Label("进阶折线", systemImage: "chart.xyaxis.line")
          }
        }

        Section {
          Text("进阶折线按身体部位分组，点进去可看该部位每个动作的重量变化。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .scrollContentBackground(.hidden)
      .appPageBackground()
      .navigationTitle("📦 其他")
      .navigationBarTitleDisplayMode(.large)
    }
  }
}
