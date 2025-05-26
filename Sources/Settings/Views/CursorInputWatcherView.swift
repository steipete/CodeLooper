import SwiftUI

struct CursorInputWatcherView: View {
    @StateObject private var viewModel = CursorInputWatcherViewModel()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Cursor Input Watcher")
                .font(.title)
                .padding(.bottom)

            Toggle("Enable Live Watching", isOn: $viewModel.isWatchingEnabled)
                .padding(.bottom)

            Text(viewModel.statusMessage)
                .font(.caption)
                .padding(.bottom)
            
            if viewModel.isWatchingEnabled && viewModel.watchedInputs.isEmpty {
                Text("No inputs are currently being watched. Configure in ViewModel.")
                    .foregroundColor(.orange)
            }

            List {
                ForEach(viewModel.watchedInputs) { inputInfo in
                    VStack(alignment: .leading) {
                        Text(inputInfo.name)
                            .font(.headline)
                        Text("Last Text: \(inputInfo.lastKnownText)")
                            .font(.body)
                            .lineLimit(3)
                        if let error = inputInfo.lastError {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle()) // Or PlainListStyle()

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CursorInputWatcherView_Previews: PreviewProvider {
    static var previews: some View {
        CursorInputWatcherView()
    }
} 