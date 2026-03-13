import SwiftUI
import AVFoundation

// MARK: - Barcode Scanner Button (standalone Liquid Glass)
struct BarcodeScanButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
    }
}

// MARK: - Scanner Sheet
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onFoodScanned: (ScannedFood) -> Void

    @State private var scannedCode: String?
    @State private var isLookingUp = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(onBarcodeDetected: { code in
                guard scannedCode == nil && !isLookingUp else { return }
                scannedCode = code
                lookupBarcode(code)
            })
            .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Scanning reticle
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    .frame(width: 260, height: 120)
                    .overlay(
                        Group {
                            if isLookingUp {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    )

                Spacer()

                // Status text
                VStack(spacing: 8) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Button("Try again") {
                            scannedCode = nil
                            errorMessage = nil
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    } else if isLookingUp {
                        Text("Looking up product...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Point camera at a barcode")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }

    private func lookupBarcode(_ code: String) {
        isLookingUp = true
        errorMessage = nil

        Task {
            do {
                let food = try await OpenFoodFactsService.lookup(barcode: code)
                await MainActor.run {
                    onFoodScanned(food)
                    dismiss()
                }
            } catch LookupError.notFound {
                await MainActor.run {
                    isLookingUp = false
                    errorMessage = "Product not found"
                }
            } catch {
                await MainActor.run {
                    isLookingUp = false
                    errorMessage = "Lookup failed — check connection"
                }
            }
        }
    }
}

// MARK: - Scanned Food Data
struct ScannedFood {
    let name: String
    let servingGrams: Float
    let caloriesPer100g: Float
    let proteinPer100g: Float
    let carbsPer100g: Float
    let fatPer100g: Float
}

// MARK: - OpenFoodFacts Lookup
enum LookupError: Error {
    case notFound
    case networkError
}

struct OpenFoodFactsService {
    static func lookup(barcode: String) async throws -> ScannedFood {
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,nutriments,serving_quantity"
        guard let url = URL(string: urlString) else { throw LookupError.networkError }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LookupError.networkError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any],
              let name = product["product_name"] as? String, !name.isEmpty,
              let nutriments = product["nutriments"] as? [String: Any] else {
            throw LookupError.notFound
        }

        let servingGrams = floatValue(product["serving_quantity"]) ?? 100
        let calPer100 = floatValue(nutriments["energy-kcal_100g"]) ?? 0
        let proteinPer100 = floatValue(nutriments["proteins_100g"]) ?? 0
        let carbsPer100 = floatValue(nutriments["carbohydrates_100g"]) ?? 0
        let fatPer100 = floatValue(nutriments["fat_100g"]) ?? 0

        return ScannedFood(
            name: name,
            servingGrams: servingGrams,
            caloriesPer100g: calPer100,
            proteinPer100g: proteinPer100,
            carbsPer100g: carbsPer100,
            fatPer100g: fatPer100
        )
    }

    private static func floatValue(_ value: Any?) -> Float? {
        if let n = value as? NSNumber { return n.floatValue }
        if let s = value as? String { return Float(s) }
        return nil
    }
}

// MARK: - Camera Preview (AVFoundation)
struct CameraPreview: UIViewRepresentable {
    let onBarcodeDetected: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return view }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeDetected: onBarcodeDetected)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onBarcodeDetected: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var hasDetected = false

        init(onBarcodeDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasDetected,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = object.stringValue else { return }
            hasDetected = true
            onBarcodeDetected(code)
        }
    }
}
