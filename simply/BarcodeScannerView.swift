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

// MARK: - Scan Result
enum ScanResult {
    case existingFood(Food)
    case scannedFood(ScannedFood, barcode: String)
    case notFound(barcode: String)
}

// MARK: - Scanner Sheet
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let foodService: FoodService
    let onResult: (ScanResult) -> Void

    @State private var scannedCode: String?
    @State private var isLookingUp = false
    @State private var errorMessage: String?
    @State private var showNotFound = false

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

                VStack(spacing: 12) {
                    if showNotFound, let code = scannedCode {
                        Text("Product not found")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Button {
                            onResult(.notFound(barcode: code))
                            dismiss()
                        } label: {
                            Text("Log manually")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }

                        Button("Scan again") {
                            scannedCode = nil
                            showNotFound = false
                            errorMessage = nil
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                    } else if let error = errorMessage {
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
        showNotFound = false

        Task {
            if let existingFood = await foodService.lookupByBarcode(code: code) {
                await MainActor.run {
                    onResult(.existingFood(existingFood))
                    dismiss()
                }
                return
            }

            do {
                let scanned = try await OpenFoodFactsService.lookup(barcode: code)
                await MainActor.run {
                    onResult(.scannedFood(scanned, barcode: code))
                    dismiss()
                }
            } catch LookupError.notFound {
                await MainActor.run {
                    isLookingUp = false
                    showNotFound = true
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

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Self.setupSession(session: session, in: view, coordinator: context.coordinator)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        Self.setupSession(session: session, in: view, coordinator: context.coordinator)
                    }
                }
            }
        default:
            break
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

    private static func setupSession(session: AVCaptureSession, in view: UIView, coordinator: Coordinator) {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(coordinator, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
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
