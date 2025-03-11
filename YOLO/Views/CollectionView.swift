//
//  CollectionView.swift
//  YOLO
//
//  Created as part of the Tono integration
//

import SwiftUI
import CoreData

struct CollectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.timestamp, ascending: false)],
        animation: .default)
    private var items: FetchedResults<TaggedObject>
    
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedFilter: FilterOption = .all
    
    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case recent = "Recent"
        case needsReview = "Needs Review"
        
        var id: String { self.rawValue }
    }
    
    var filteredItems: [TaggedObject] {
        let filtered = items.filter { item in
            if searchText.isEmpty {
                return true
            } else {
                return (item.english?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (item.chinese?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (item.pinyin?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        switch selectedFilter {
        case .all:
            return Array(filtered)
        case .recent:
            return Array(filtered.prefix(10))
        case .needsReview:
            let now = Date()
            return filtered.filter { item in
                if let nextReviewDate = item.nextReviewDate {
                    return nextReviewDate <= now
                }
                return true // Include items without a next review date
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                // Filter options
                HStack {
                    Text("Filter:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(FilterOption.allCases) { option in
                        Button(action: {
                            selectedFilter = option
                        }) {
                            Text(option.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedFilter == option ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedFilter == option ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                if filteredItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No items in your collection")
                            .font(.headline)
                        
                        Text("Tap on objects in the Explore tab to add them to your collection")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(filteredItems, id: \.self) { item in
                            NavigationLink(destination: ObjectDetailView(object: item)) {
                                ObjectRow(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Collection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredItems[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting item: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ObjectRow: View {
    let item: TaggedObject
    
    var body: some View {
        HStack(spacing: 15) {
            // Image (if available)
            if let imageData = item.image, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .padding(15)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.chinese ?? "Unknown")
                    .font(.headline)
                
                Text(item.pinyin ?? "")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                Text(item.english ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let nextReview = item.nextReviewDate {
                    if nextReview <= Date() {
                        Text("Review due")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Next review: \(nextReview, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

struct ObjectDetailView: View {
    let object: TaggedObject
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isShowingPractice = false
    @State private var isSpeaking = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Image (if available)
                if let imageData = object.image, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .padding(30)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
                
                // Chinese character
                Text(object.chinese ?? "Unknown")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.red)
                
                // Pinyin
                Text(object.pinyin ?? "")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                // English translation
                Text(object.english ?? "")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .padding(.bottom, 10)
                
                // Review stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Review count:")
                        Spacer()
                        Text("\(object.reviewCount)")
                    }
                    
                    HStack {
                        Text("Success count:")
                        Spacer()
                        Text("\(object.successCount)")
                    }
                    
                    if let lastReview = object.lastReviewDate {
                        HStack {
                            Text("Last reviewed:")
                            Spacer()
                            Text("\(lastReview, formatter: dateFormatter)")
                        }
                    }
                    
                    if let nextReview = object.nextReviewDate {
                        HStack {
                            Text("Next review:")
                            Spacer()
                            Text("\(nextReview, formatter: dateFormatter)")
                                .foregroundColor(nextReview <= Date() ? .red : .primary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 30) {
                    Button(action: {
                        isSpeaking = true
                        SpeechManager().speak(object.chinese ?? "") { speaking in
                            isSpeaking = speaking
                        }
                    }) {
                        VStack {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Speak")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .clipShape(Circle())
                    }
                    
                    Button(action: {
                        isShowingPractice = true
                    }) {
                        VStack {
                            Image(systemName: "pencil")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Practice")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.green)
                        .clipShape(Circle())
                    }
                    
                    Button(action: {
                        // Mark as reviewed
                        PersistenceController.shared.updateReviewStatus(
                            for: object,
                            wasCorrect: true,
                            context: viewContext
                        )
                    }) {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Mark")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.purple)
                        .clipShape(Circle())
                    }
                }
                .padding(.vertical, 20)
            }
            .padding(.vertical)
        }
        .navigationTitle(object.english ?? "Object")
        .sheet(isPresented: $isShowingPractice) {
            PracticeObjectView(object: object)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct PracticeObjectView: View {
    let object: TaggedObject
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingChinese = false
    @State private var isRecording = false
    @State private var recordingResult: Double? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Flashcard
                VStack(spacing: 20) {
                    if showingChinese {
                        Text(object.chinese ?? "")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text(object.pinyin ?? "")
                            .font(.title2)
                            .foregroundColor(.orange)
                    } else {
                        Text(object.english ?? "")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 280, height: 200)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onTapGesture {
                    withAnimation {
                        showingChinese.toggle()
                    }
                }
                
                Text("Tap card to flip")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Practice controls
                VStack(spacing: 20) {
                    Button(action: {
                        SpeechManager().speak(object.chinese ?? "") { _ in }
                    }) {
                        Label("Hear Pronunciation", systemImage: "speaker.wave.2.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        isRecording.toggle()
                        if isRecording {
                            // Simulate recording and assessment
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                recordingResult = Double.random(in: 60...95)
                                isRecording = false
                            }
                        }
                    }) {
                        Label(
                            isRecording ? "Stop Recording" : "Record Your Pronunciation",
                            systemImage: isRecording ? "stop.fill" : "mic.fill"
                        )
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    if let score = recordingResult {
                        HStack {
                            Text("Pronunciation score:")
                            Spacer()
                            Text("\(Int(score))/100")
                                .foregroundColor(score > 80 ? .green : (score > 60 ? .orange : .red))
                                .fontWeight(.bold)
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Result buttons
                HStack(spacing: 20) {
                    Button(action: {
                        // Mark as incorrect
                        PersistenceController.shared.updateReviewStatus(
                            for: object,
                            wasCorrect: false,
                            context: viewContext
                        )
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("I was wrong")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Mark as correct
                        PersistenceController.shared.updateReviewStatus(
                            for: object,
                            wasCorrect: true,
                            context: viewContext
                        )
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("I got it right")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Practice")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search", text: $text)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CollectionView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 