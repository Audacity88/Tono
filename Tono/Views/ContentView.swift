import SwiftUI
import CoreData

// Define the collection view based on backup implementation
struct CollectionViewWrapper: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.timestamp, ascending: false)],
        animation: .default)
    private var taggedObjects: FetchedResults<TaggedObject>
    
    var body: some View {
        NavigationView {
            if taggedObjects.isEmpty {
                VStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("No objects in your collection yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Explore your surroundings and tag objects to add them to your collection")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .navigationTitle("My Collection")
            } else {
                List {
                    ForEach(taggedObjects) { object in
                        NavigationLink(destination: ObjectDetailViewWrapper(object: object)) {
                            ObjectRow(object: object)
                        }
                    }
                    .onDelete(perform: deleteObjects)
                }
                .navigationTitle("My Collection")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }
    
    private func deleteObjects(offsets: IndexSet) {
        withAnimation {
            offsets.map { taggedObjects[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ObjectRow: View {
    let object: TaggedObject
    
    var body: some View {
        HStack {
            if let imageData = object.image, let uiImage = UIImage(data: imageData) {
                Image(uiImage: fixOrientation(uiImage))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(object.chinese ?? "未知")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text(object.pinyin ?? "")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                Text(object.english ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Show review count as stars
            HStack {
                ForEach(0..<min(Int(object.reviewCount), 5), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }
                ForEach(0..<(5 - min(Int(object.reviewCount), 5)), id: \.self) { _ in
                    Image(systemName: "star")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Helper function to fix image orientation
    private func fixOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: CGPoint.zero)
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
}

struct ObjectDetailViewWrapper: View {
    let object: TaggedObject
    @StateObject private var speechManager = SpeechManager()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                // Object image
                if let imageData = object.image, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: fixOrientation(uiImage))
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .foregroundColor(.gray)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Chinese character
                Text(object.chinese ?? "未知")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.red)
                
                // Pinyin
                Text(object.pinyin ?? "")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                // English translation
                Text(object.english ?? "Unknown")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .padding(.bottom, 10)
                
                // Pronunciation button
                Button(action: {
                    speakWord(object.chinese ?? "")
                }) {
                    HStack {
                        Image(systemName: speechManager.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                        Text(speechManager.isSpeaking ? "Speaking..." : "Pronounce")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: 200)
                    .background(speechManager.isSpeaking ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(speechManager.isSpeaking)
                
                // Review information
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Review Count:")
                        Spacer()
                        Text("\(object.reviewCount)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Last Reviewed:")
                        Spacer()
                        if let date = object.lastReviewDate {
                            Text(dateFormatter.string(from: date))
                                .bold()
                        } else {
                            Text("Never")
                                .bold()
                        }
                    }
                    
                    HStack {
                        Text("Added:")
                        Spacer()
                        if let date = object.timestamp {
                            Text(dateFormatter.string(from: date))
                                .bold()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(object.english ?? "Object Detail")
    }
    
    private func speakWord(_ word: String) {
        if word.isEmpty {
            return
        }
        
        speechManager.speak(word) { _ in
            // Speech completed or started
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    // Helper function to fix image orientation
    private func fixOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: CGPoint.zero)
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
}

struct SettingsView: View {
    @State private var selectedModelIndex = 2 // Default to yolo11m
    @State private var confidenceThreshold = 0.25
    @State private var iouThreshold = 0.45
    @State private var apiKey = ""
    
    private let models = ["yolo11n", "yolo11s", "yolo11m", "yolo11l", "yolo11x"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("YOLO Model")) {
                    Picker("Model", selection: $selectedModelIndex) {
                        ForEach(0..<models.count, id: \.self) { index in
                            Text(models[index]).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Detection Settings")) {
                    VStack {
                        HStack {
                            Text("Confidence Threshold")
                            Spacer()
                            Text("\(Int(confidenceThreshold * 100))%")
                        }
                        Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.05)
                    }
                    
                    VStack {
                        HStack {
                            Text("IoU Threshold")
                            Spacer()
                            Text("\(Int(iouThreshold * 100))%")
                        }
                        Slider(value: $iouThreshold, in: 0.1...0.9, step: 0.05)
                    }
                }
                
                Section(header: Text("Language Settings")) {
                    TextField("Pronunciation API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("Save API Key") {
                        UserDefaults.standard.set(apiKey, forKey: "FluentAPIKey")
                    }
                    .disabled(apiKey.isEmpty)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                    }
                    
                    HStack {
                        Text("YOLO Model")
                        Spacer()
                        Text("YOLO11")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Load API key from UserDefaults if available
                if let savedKey = UserDefaults.standard.string(forKey: "FluentAPIKey") {
                    apiKey = savedKey
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ARExploreView()
                .tabItem {
                    Label("Explore", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            CollectionViewWrapper()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Collection", systemImage: "square.grid.2x2")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 