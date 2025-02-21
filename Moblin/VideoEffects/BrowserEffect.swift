import Foundation
import WebKit
import SwiftUI
import Metal
import MetalKit

class BrowserEffect: VideoEffect {
    private var webView: WKWebView?
    private var url: String
    private var width: CGFloat
    private var height: CGFloat
    private var x: CGFloat
    private var y: CGFloat
    private var sceneResolution: CGFloat = 1.0
    
    init(url: String, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) {
        self.url = url
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        super.init()
    }
    
    override func setup() {
        let configuration = WKWebViewConfiguration()
        configuration.setValue(true, forKey: "drawsTransparentBackground")
        
        // Calculate optimal scale factor based on both display and scene resolution
        let displayScale = NSScreen.main?.backingScaleFactor ?? 2.0
        sceneResolution = max(displayScale, 2.0) // Ensure minimum 2x scaling
        let finalScale = sceneResolution * displayScale
        
        let scaledWidth = width * finalScale
        let scaledHeight = height * finalScale
        
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight),
                           configuration: configuration)
        
        if let webView = webView {
            // Configure for high-quality rendering
            webView.setValue(false, forKey: "drawsBackground")
            
            // Layer configuration for optimal quality
            if let layer = webView.layer {
                layer.backgroundColor = .clear
                layer.isOpaque = false
                
                // Enable high-quality scaling
                layer.contentsScale = finalScale
                layer.rasterizationScale = finalScale
                
                // Use high-quality filters
                layer.magnificationFilter = .linear
                layer.minificationFilter = .trilinear
                
                // Disable rasterization for sharper text
                layer.shouldRasterize = false
                
                // Enable smooth subpixel antialiasing
                layer.allowsEdgeAntialiasing = true
                layer.allowsGroupOpacity = true
                
                // Improve text rendering
                if let sublayer = layer.sublayers?.first {
                    sublayer.contentsScale = finalScale
                    sublayer.rasterizationScale = finalScale
                }
            }
            
            // Configure for high-quality content loading
            if let url = URL(string: self.url) {
                let request = URLRequest(url: url)
                webView.load(request)
                
                // Inject CSS for better text rendering
                let css = """
                    * {
                        -webkit-font-smoothing: antialiased;
                        -moz-osx-font-smoothing: grayscale;
                        text-rendering: optimizeLegibility;
                    }
                """
                let script = WKUserScript(source: "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);",
                                        injectionTime: .atDocumentEnd,
                                        forMainFrameOnly: true)
                webView.configuration.userContentController.addUserScript(script)
            }
        }
    }
    
    override func render(texture: MTLTexture, commandBuffer: MTLCommandBuffer, textureLoader: MTLTextureLoader) {
        guard let webView = webView else {
            return
        }
        
        // Update scene resolution if needed
        let newSceneResolution = CGFloat(texture.width) / width
        if newSceneResolution != sceneResolution {
            sceneResolution = newSceneResolution
            updateWebViewResolution()
        }
        
        // Configure high-quality rendering context
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        context?.shouldAntialias = true
        
        // Optimize animation and rendering
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Ensure precise positioning
        webView.layer?.position = CGPoint(x: x, y: y)
        webView.layer?.anchorPoint = CGPoint(x: 0, y: 0)
        
        // Configure metal layer for high-quality compositing
        if let metalLayer = webView.layer?.sublayers?.first as? CAMetalLayer {
            metalLayer.framebufferOnly = false
            metalLayer.presentsWithTransaction = true
            metalLayer.wantsExtendedDynamicRangeContent = true
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
            metalLayer.pixelFormat = .bgra8Unorm_srgb
            metalLayer.drawsAsynchronously = true
        }
        
        CATransaction.commit()
    }
    
    private func updateWebViewResolution() {
        guard let webView = webView else { return }
        
        let displayScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let finalScale = sceneResolution * displayScale
        let scaledWidth = width * finalScale
        let scaledHeight = height * finalScale
        
        webView.frame = NSRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)
        webView.layer?.contentsScale = finalScale
        webView.layer?.rasterizationScale = finalScale
    }
    
    override func cleanup() {
        webView = nil
    }
}
