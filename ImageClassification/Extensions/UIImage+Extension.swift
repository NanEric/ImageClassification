import UIKit
import CoreVideo

extension UIImage {
    // 调整图片大小并应用增强
    func resizeTo(size: CGSize) -> UIImage? {
        // 使用 UIGraphicsImageRenderer 替代旧的绘图上下文，更高效且自动管理内存
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 设置高质量插值
            context.cgContext.interpolationQuality = .high
            
            // 绘制图像
            self.draw(in: CGRect(origin: .zero, size: size))
            
            // 应用锐化效果
            if let cgImage = context.cgContext.makeImage() {
                let ciImage = CIImage(cgImage: cgImage)
                
                // 创建锐化滤镜
                guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else {
                    return
                }
                
                sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
                sharpenFilter.setValue(0.2, forKey: kCIInputSharpnessKey)
                
                // 创建颜色控制滤镜，增强对比度和亮度
                guard let colorControls = CIFilter(name: "CIColorControls") else {
                    return
                }
                
                colorControls.setValue(sharpenFilter.outputImage, forKey: kCIInputImageKey)
                colorControls.setValue(1.1, forKey: kCIInputContrastKey)  // 增加对比度
                colorControls.setValue(0.1, forKey: kCIInputBrightnessKey) // 微调亮度
                
                // 获取处理后的图像
                if let outputImage = colorControls.outputImage,
                   let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) {
                    UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
                }
            }
        }
    }
    
    // 将图片转换为 CVPixelBuffer，优化性能和内存使用
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let size = self.size
        
        // 配置像素缓冲区的属性
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,  // 使用 BGRA 格式，这是 iOS 相机和显示的默认格式
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        // 获取像素缓冲区的基地址
        guard let pixelData = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }
        
        // 创建位图上下文
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        
        // 转换坐标系（UIKit 和 Core Graphics 的坐标系不同）
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 绘制图像到像素缓冲区
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    // 辅助方法：将图像裁剪为指定比例
    func cropToAspectRatio(_ aspectRatio: CGSize) -> UIImage? {
        let imageAspectRatio = size.width / size.height
        let targetAspectRatio = aspectRatio.width / aspectRatio.height
        
        var newSize = size
        
        if imageAspectRatio > targetAspectRatio {
            // 图像比目标宽，裁剪左右
            newSize.width = size.height * targetAspectRatio
        } else {
            // 图像比目标高，裁剪上下
            newSize.height = size.width / targetAspectRatio
        }
        
        let x = (size.width - newSize.width) / 2.0
        let y = (size.height - newSize.height) / 2.0
        let cropRect = CGRect(x: x, y: y, width: newSize.width, height: newSize.height)
        
        if let cgImage = self.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        
        return nil
    }
    
    // 辅助方法：标准化图像方向
    func normalized() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}
