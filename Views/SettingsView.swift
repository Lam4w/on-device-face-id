struct SettingsView: View {
    @Binding var similarityThreshold: Double // Bind directly to ViewModel's @AppStorage
    @Environment(\.dismiss) var dismiss // To close the sheet

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Verification Threshold")
                    .font(.headline)

                Text("Adjust the similarity score required for a match. Higher values mean stricter matching.")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Text("Low (Loose)")
                    Slider(value: $similarityThreshold, in: 0.5...1.0, step: 0.01) // Example range for DeepLook similarity
                    Text("High (Strict)")
                }

                Text(String(format: "Current Threshold: %.2f", similarityThreshold))
                    .font(.subheadline)

                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss() // Close the sheet
                    }
                }
            }
        }
    }
}