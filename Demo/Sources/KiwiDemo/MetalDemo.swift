#if os(macOS) && canImport(MetalKit)
import AppKit
import MetalKit
import simd

// MARK: - Entry

@MainActor
func runMetalDemo() {
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)

    let initialFrame = NSRect(x: 0, y: 0, width: 900, height: 600)
    let window = NSWindow(
        contentRect: initialFrame,
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "KiwiDemo — AutoLayout for Metal (drag the panel borders)"
    window.center()

    guard let device = MTLCreateSystemDefaultDevice() else {
        print("Metal is not supported on this device.")
        return
    }

    let view = PanelMetalView(frame: initialFrame, device: device)
    window.contentView = view
    window.makeFirstResponder(view)
    window.makeKeyAndOrderFront(nil)

    let applicationDelegate = ApplicationDelegate()
    application.delegate = applicationDelegate
    application.activate(ignoringOtherApps: true)
    application.run()
}

private final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - Vertex

private struct ColorVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

// MARK: - View

private final class PanelMetalView: MTKView {
    private var renderer: PanelRenderer?
    private let layout: PanelLayout
    private var draggingDivider: PanelLayout.Divider?
    private let hitTolerance = 6.0

    init(frame: NSRect, device: MTLDevice) {
        layout = PanelLayout(
            width: Double(frame.width),
            height: Double(frame.height),
            minimums: .init(left: 120, right: 160, top: 80, middle: 80, bottom: 80)
        )
        super.init(frame: frame, device: device)
        clearColor = MTLClearColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        colorPixelFormat = .bgra8Unorm
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60

        do {
            let createdRenderer = try PanelRenderer(
                device: device,
                pixelFormat: colorPixelFormat,
                layout: layout
            )
            renderer = createdRenderer
            delegate = createdRenderer
        } catch {
            print("Failed to create Metal renderer: \(error)")
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("not implemented") }

    // MARK: Mouse → model coordinates (top-left origin, y-down)

    private func modelPoint(_ event: NSEvent) -> (x: Double, y: Double) {
        let pointInView = convert(event.locationInWindow, from: nil)
        // NSView is not flipped by default: its origin is bottom-left, so flip y to top-left.
        return (Double(pointInView.x), Double(bounds.height) - Double(pointInView.y))
    }

    override func mouseDown(with event: NSEvent) {
        let point = modelPoint(event)
        draggingDivider = layout.dividerHit(x: point.x, y: point.y, tolerance: hitTolerance)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let divider = draggingDivider else { return }
        let point = modelPoint(event)
        switch divider {
        case .splitX: layout.drag(.splitX, to: point.x)
        case .splitY1, .splitY2: layout.drag(divider, to: point.y)
        }
    }

    override func mouseUp(with event: NSEvent) {
        draggingDivider = nil
    }

    // Resize-cursor feedback as the pointer crosses a divider.
    override func mouseMoved(with event: NSEvent) {
        let point = modelPoint(event)
        switch layout.dividerHit(x: point.x, y: point.y, tolerance: hitTolerance) {
        case .splitX: NSCursor.resizeLeftRight.set()
        case .splitY1, .splitY2: NSCursor.resizeUpDown.set()
        case nil: NSCursor.arrow.set()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }
}

// MARK: - Renderer

private final class PanelRenderer: NSObject, MTKViewDelegate {
    private let layout: PanelLayout
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var vertexBuffer: MTLBuffer?

    // A distinct color per panel index.
    private let palette: [SIMD4<Float>] = [
        SIMD4(0.20, 0.45, 0.75, 1.0), // left
        SIMD4(0.85, 0.45, 0.30, 1.0), // right-top
        SIMD4(0.40, 0.65, 0.40, 1.0), // right-mid
        SIMD4(0.65, 0.45, 0.70, 1.0), // right-bot
    ]
    private let gutter = 3.0 // cosmetic gap between panels so the borders read clearly

    init(device: MTLDevice, pixelFormat: MTLPixelFormat, layout: PanelLayout) throws {
        self.layout = layout
        guard let createdQueue = device.makeCommandQueue() else {
            throw RendererError.noCommandQueue
        }
        commandQueue = createdQueue

        let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        guard
            let vertexFunction = library.makeFunction(name: "vertex_main"),
            let fragmentFunction = library.makeFunction(name: "fragment_main")
        else {
            throw RendererError.missingShaderFunctions
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Solve in point units that match the view bounds (mouse events are in points).
        layout.resize(width: Double(view.bounds.width), height: Double(view.bounds.height))
    }

    func draw(in view: MTKView) {
        layout.resize(width: Double(view.bounds.width), height: Double(view.bounds.height))

        guard
            let drawable = view.currentDrawable,
            let passDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        let vertices = buildVertices(width: layout.width, height: layout.height)
        if !vertices.isEmpty {
            vertexBuffer = view.device?.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<ColorVertex>.stride * vertices.count,
                options: .storageModeShared
            )
        }

        guard
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor),
            let buffer = vertexBuffer
        else {
            commandBuffer.commit()
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: Geometry

    private func buildVertices(width: Double, height: Double) -> [ColorVertex] {
        guard width > 0, height > 0 else { return [] }
        let verticesPerQuad = 6
        var vertices: [ColorVertex] = []
        vertices.reserveCapacity(layout.panels.count * verticesPerQuad)

        for (index, panel) in layout.panels.enumerated() {
            let color = palette[index % palette.count]
            // Inset by the gutter so the gaps read as panel borders.
            let left = panel.x + gutter
            let top = panel.y + gutter
            let right = panel.x + panel.width - gutter
            let bottom = panel.y + panel.height - gutter
            guard right > left, bottom > top else { continue }

            let topLeft = normalizedDeviceCoordinate(x: left, y: top, width: width, height: height)
            let topRight = normalizedDeviceCoordinate(x: right, y: top, width: width, height: height)
            let bottomRight = normalizedDeviceCoordinate(x: right, y: bottom, width: width, height: height)
            let bottomLeft = normalizedDeviceCoordinate(x: left, y: bottom, width: width, height: height)

            vertices.append(ColorVertex(position: topLeft, color: color))
            vertices.append(ColorVertex(position: topRight, color: color))
            vertices.append(ColorVertex(position: bottomRight, color: color))
            vertices.append(ColorVertex(position: topLeft, color: color))
            vertices.append(ColorVertex(position: bottomRight, color: color))
            vertices.append(ColorVertex(position: bottomLeft, color: color))
        }
        return vertices
    }

    /// Convert top-left/y-down model coordinates to Metal NDC (center origin, y-up).
    private func normalizedDeviceCoordinate(x: Double, y: Double, width: Double, height: Double) -> SIMD2<Float> {
        SIMD2(Float(x / width * 2 - 1), Float(1 - y / height * 2))
    }

    // MARK: Shader

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position;
        float4 color;
    };

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                                 const device VertexIn* vertices [[buffer(0)]]) {
        VertexOut out;
        out.position = float4(vertices[vertexID].position, 0.0, 1.0);
        out.color = vertices[vertexID].color;
        return out;
    }

    fragment float4 fragment_main(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """

    enum RendererError: Error {
        case noCommandQueue
        case missingShaderFunctions
    }
}

#else

func runMetalDemo() {
    print("The 'metal' mode requires macOS with MetalKit. Try: swift run KiwiDemo terminal")
}

#endif
