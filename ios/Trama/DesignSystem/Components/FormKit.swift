import PhotosUI
import SwiftUI

/// Standard modal editor: NavigationStack + Form with Cancel / Save.
struct FormSheet<Content: View>: View {
    var title: LocalizedStringKey
    var saveTitle: LocalizedStringKey = "Guardar"
    var canSave: Bool = true
    var onSave: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form { content }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveTitle) { onSave() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                            .keyboardShortcut("s", modifiers: .command)
                    }
                }
        }
    }
}

/// Numeric text field that edits an Int. Empty input maps to 0.
struct IntField: View {
    var title: LocalizedStringKey
    @Binding var value: Int
    var prompt: String = "0"

    var body: some View {
        LabeledContent(title) {
            TextField(prompt, value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

/// Numeric text field that edits a Double (currency or decimal).
struct DecimalField: View {
    var title: LocalizedStringKey
    @Binding var value: Double
    var currency = false

    var body: some View {
        LabeledContent(title) {
            Group {
                if currency {
                    TextField("$0", value: $value, format: .currency(code: Fmt.currencyCode))
                } else {
                    TextField("0", value: $value, format: .number)
                }
            }
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
        }
    }
}

/// Image picker row: photo library or camera, with preview and remove.
struct PhotoField: View {
    var title: LocalizedStringKey = "Imagen"
    @Binding var data: Data?

    @State private var item: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        HStack(spacing: 16) {
            SwatchImage(data: data, name: "Imagen", cornerRadius: 14)
                .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 8) {
                PhotosPicker(selection: $item, matching: .images) {
                    Label(data == nil ? "Elegir de fotos" : "Cambiar foto", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Tomar foto", systemImage: "camera")
                    }
                }
                if data != nil {
                    Button(role: .destructive) {
                        data = nil
                    } label: {
                        Label("Quitar", systemImage: "trash")
                    }
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .onChange(of: item) { _, newItem in
            Task {
                if let raw = try? await newItem?.loadTransferable(type: Data.self) {
                    data = ImageCompressor.compress(raw)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in data = ImageCompressor.compress(image) }
                .ignoresSafeArea()
        }
    }
}

enum ImageCompressor {
    static let maxDimension: CGFloat = 1_600

    static func compress(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return compress(image)
    }

    static func compress(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(longest, 1))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.72)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// Full-screen pinch-to-zoom image viewer (replaces the legacy style image overlays).
struct ZoomableImageViewer: View {
    var data: Data?
    var title: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { scale = max(1, lastScale * $0.magnification) }
                                .onEnded { _ in
                                    lastScale = scale;
                                    if scale == 1 {
                                        withAnimation {
                                            offset = .zero; lastOffset = .zero
                                        }
                                    }
                                }
                                .simultaneously(
                                    with: DragGesture()
                                        .onChanged { v in
                                            guard scale > 1 else { return }
                                            offset = CGSize(
                                                width: lastOffset.width + v.translation.width,
                                                height: lastOffset.height + v.translation.height)
                                        }
                                        .onEnded { _ in lastOffset = offset })
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring) {
                                scale = scale > 1 ? 1 : 2.5
                                lastScale = scale
                                offset = .zero; lastOffset = .zero
                            }
                        }
                } else {
                    SwatchImage(data: nil, name: title).frame(width: 320, height: 320)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }
}

/// Destructive confirmation used before deletes.
extension View {
    func confirmDelete(
        _ title: LocalizedStringKey, isPresented: Binding<Bool>, message: LocalizedStringKey? = nil, action: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive, action: action)
        } message: {
            if let message { Text(message) }
        }
    }
}

/// Wide-screen friendly adaptive grid columns.
enum AdaptiveGrid {
    static func adaptive(min: CGFloat, spacing: CGFloat = 18) -> [GridItem] {
        [GridItem(.adaptive(minimum: min), spacing: spacing, alignment: .top)]
    }
}
