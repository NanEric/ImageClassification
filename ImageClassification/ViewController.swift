//
//  ViewController.swift
//  ImageClassification
//
//  Created by eric on 2025/12/7.
//

import UIKit
import CoreML
import Vision
import AVFoundation

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // 声明 MobileNetV2 模型实例
    private var model: MobileNetV2?
    
    // 添加 UI 组件
    private let cameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("拍摄照片", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(cameraButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .lightGray
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "拍摄照片进行图像分类"
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化 MobileNetV2 模型
        setupModel()
        setupUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 设置 UI 组件的位置和大小
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 50
        let padding: CGFloat = 20
        let imageSize = min(view.frame.width, view.frame.height) - 2 * padding
        
        cameraButton.frame = CGRect(
            x: (view.frame.width - buttonWidth) / 2,
            y: view.safeAreaInsets.top + padding,
            width: buttonWidth,
            height: buttonHeight
        )
        
        imageView.frame = CGRect(
            x: (view.frame.width - imageSize) / 2,
            y: cameraButton.frame.maxY + padding,
            width: imageSize,
            height: imageSize
        )
        
        resultLabel.frame = CGRect(
            x: padding,
            y: imageView.frame.maxY + padding,
            width: view.frame.width - 2 * padding,
            height: 100
        )
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // 添加子视图
        view.addSubview(cameraButton)
        view.addSubview(imageView)
        view.addSubview(resultLabel)
        
        // 设置导航栏标题
        title = "图像分类"
    }
    
    private func setupModel() {
        do {
            // 使用默认配置初始化模型
            let configuration = MLModelConfiguration()
            if let modelURL = MobileNetV2.urlOfModelInThisBundle() {
                model = try MobileNetV2(contentsOf: modelURL, configuration: configuration)
                print("MobileNetV2 模型初始化成功")
            } else {
                print("无法获取模型文件URL")
            }
        } catch {
            print("初始化 MobileNetV2 模型时出错: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 按钮点击事件
    
    @objc private func cameraButtonTapped() {
        let alertController = UIAlertController(title: "选择图片来源", message: nil, preferredStyle: .actionSheet)
        
        // 相机按钮
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraAction = UIAlertAction(title: "拍照", style: .default) { [weak self] _ in
                self?.openCamera()
            }
            alertController.addAction(cameraAction)
        }
        
        // 相册按钮
        let photoLibraryAction = UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
            self?.openPhotoLibrary()
        }
        
        // 取消按钮
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        alertController.addAction(photoLibraryAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func openCamera() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.cameraCaptureMode = .photo
        present(imagePicker, animated: true, completion: nil)
    }
    
    private func openPhotoLibrary() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[.originalImage] as? UIImage else {
            return
        }
        
        // 显示选中的图片
        imageView.image = image
        
        // 调整图片大小以匹配模型输入要求 (224x224)
        if let resizedImage = image.resizeTo(size: CGSize(width: 224, height: 224)),
           let pixelBuffer = resizedImage.toCVPixelBuffer() {
            // 使用模型进行预测
            classify(image: pixelBuffer)
        } else {
            resultLabel.text = "无法处理所选图片"
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - 图像分类
    
    private func classify(image: CVPixelBuffer) {
        guard let model = model else {
            print("模型未初始化")
            return
        }
        
        do {
            let input = try MobileNetV2Input(image: image)
            let prediction = try model.prediction(fromFeatures: input)
            
            // 获取预测结果
            let featureValue = prediction.featureValue(for: "classLabel")?.stringValue ?? "未知"
            let probs = prediction.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Double] ?? [:]
            let confidence = probs[featureValue] ?? 0.0
            
            // 在主线程更新UI
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel.text = "预测结果: \(featureValue)\n置信度: \(String(format: "%.2f", confidence * 100))%"
            }
            print("预测结果: \(featureValue), 置信度: \(confidence)")
            
        } catch {
            print("预测时出错: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel.text = "预测时出错: \(error.localizedDescription)"
            }
        }
    }
}

