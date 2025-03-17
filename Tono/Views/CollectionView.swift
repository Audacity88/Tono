//
//  CollectionView.swift
//  Tono
//
//  Created for the AR Gamified Chinese Learning App
//

import SwiftUI
import CoreData
import AVFoundation

struct CollectionView: View {
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
                        NavigationLink(destination: ObjectDetailView(object: object)) {
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
                Image(uiImage: uiImage.fixOrientation())
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
}

struct CollectionView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}