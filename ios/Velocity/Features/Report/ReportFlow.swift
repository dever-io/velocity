import SwiftUI
import PhotosUI
import CoreLocation

struct ReportFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D

    @State private var category: String?
    @State private var comment = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var busy = false

    private let categories = ["pothole", "glass", "closure", "hazard", "other"]
    private func icon(_ c: String) -> String {
        switch c {
        case "pothole": return "exclamationmark.triangle.fill"
        case "glass": return "trash.fill"
        case "closure": return "xmark.octagon.fill"
        case "hazard": return "bolt.trianglebadge.exclamationmark.fill"
        default: return "ellipsis.circle.fill"
        }
    }

    var body: some View {
        let loc = app.loc
        VStack(spacing: 0) {
            FlowNavBar(title: loc.s("repTitle")) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(loc.s("chooseCat")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx2)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(categories, id: \.self) { c in
                            categoryTile(c)
                        }
                    }

                    Text(loc.s("commentL")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx2)
                    ZStack(alignment: .topLeading) {
                        if comment.isEmpty {
                            Text(loc.s("commentPh")).font(.system(size: 15)).foregroundStyle(Theme.tx3)
                                .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                        TextEditor(text: $comment)
                            .font(.system(size: 15)).foregroundStyle(Theme.tx)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .frame(height: 90)
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Text(loc.s("photosL")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx2)
                    photosRow

                    HStack(spacing: 10) {
                        Image(systemName: "location.fill").foregroundStyle(Theme.tint)
                        Text(loc.s("locationL")).font(.system(size: 14)).foregroundStyle(Theme.tx)
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .padding(16)
            }
            PrimaryButton(title: loc.s("submit"), color: Theme.red, enabled: category != nil && !busy) { submit() }
                .padding(16)
                .background(Theme.card.ignoresSafeArea(edges: .bottom).overlay(alignment: .top) { Rectangle().fill(Theme.sep).frame(height: 0.5) })
        }
        .background(ScreenBackground())
        .onChange(of: pickerItems) { _, items in loadImages(items) }
    }

    private func categoryTile(_ c: String) -> some View {
        let loc = app.loc
        let selected = category == c
        let color = Theme.categoryColor(c)
        return Button { category = c } label: {
            VStack(spacing: 8) {
                Image(systemName: icon(c)).font(.system(size: 22, weight: .semibold)).foregroundStyle(color)
                Text(loc.cat(c)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tx)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).frame(height: 82)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? color : Theme.sep, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressStyle())
    }

    private var photosRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<images.count, id: \.self) { i in
                Image(uiImage: images[i]).resizable().scaledToFill()
                    .frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if images.count < 3 {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 3, matching: .images) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(Theme.tx3)
                        .frame(width: 76, height: 76)
                        .overlay(Image(systemName: "plus").font(.system(size: 22)).foregroundStyle(Theme.tx3))
                }
            }
            Spacer()
        }
    }

    private func loadImages(_ items: [PhotosPickerItem]) {
        Task {
            var imgs: [UIImage] = []
            for item in items.prefix(3) {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    imgs.append(img)
                }
            }
            images = imgs
        }
    }

    private func submit() {
        busy = true
        Task {
            var keys: [String] = []
            if !images.isEmpty {
                let datas = images.compactMap { $0.jpegData(compressionQuality: 0.7) }
                if let up = try? await APIClient.shared.upload(images: datas) { keys = up.uploads.map(\.key) }
            }
            let resp = try? await APIClient.shared.createReport(category: category ?? "other", comment: comment, coord: coordinate, photoKeys: keys)
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                app.handleReward(resp?.reward, toast: app.loc.s("repSuccess"))
            }
        }
    }
}

// Shared top bar for full-screen flows
struct FlowNavBar: View {
    let title: String
    var trailing: AnyView? = nil
    let onCancel: () -> Void
    @Environment(AppState.self) private var app
    var body: some View {
        ZStack {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.tx)
            HStack {
                Button(app.loc.s("cancel")) { onCancel() }
                    .font(.system(size: 17)).foregroundStyle(Theme.tint)
                Spacer()
                if let trailing { trailing }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.card.overlay(alignment: .bottom) { Rectangle().fill(Theme.sep).frame(height: 0.5) })
    }
}
