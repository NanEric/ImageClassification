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

//1.创建或获取机器学习模型：你可以使用各种机器学习框架（如 TensorFlow、PyTorch 等）来训练和创建你的模型。确保将模型保存为 Core ML 支持的格式（如.mlmodel）。
//
//2.将模型添加到项目中：将你的模型文件添加到 iOS 项目的资产目录中。
//
//3.导入 Core ML 框架：在你的项目中，确保已经导入了 Core ML 框架。
//
//4.加载模型：在你的应用代码中，使用MLModel类来加载你的模型。
//
//5.准备输入数据：根据你的模型的要求，准备适当的输入数据。这可能涉及将图像、数组或其他数据转换为模型可以接受的格式。
//
//6.进行预测：使用模型的prediction方法来进行预测，并获取预测结果。
//
//7.处理预测结果：根据你的应用需求，对预测结果进行处理和展示。

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
            configuration.computeUnits = .cpuAndGPU
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
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel.text = "错误：模型未初始化"
            }
            return
        }
        
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // 在后台线程执行预测
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                // 确保在主线程移除加载指示器
                DispatchQueue.main.async {
                    activityIndicator.removeFromSuperview()
                }
            }
            
            do {
                // 1. 创建模型输入
                let input = try MobileNetV2Input(image: image)
                
                // 2. 执行预测
                let startTime = CACurrentMediaTime()
                let prediction = try model.prediction(fromFeatures: input)
                let inferenceTime = CACurrentMediaTime() - startTime
                
                // 3. 处理预测结果
                guard let classLabel = prediction.featureValue(for: "classLabel")?.stringValue,
                      let probabilities = prediction.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Double] else {
                    throw NSError(domain: "com.imageclassification", code: 1, 
                                userInfo: [NSLocalizedDescriptionKey: "无法获取预测结果"])
                }
                
                // 4. 获取前3个最可能的预测结果
                let topPredictions = probabilities
                    .sorted { $0.value > $1.value }
                    .prefix(3)
                    .map { (label, prob) -> (String, Double) in
                        // 将标签转换为更易读的格式
                        let readableLabel = label.replacingOccurrences(of: "_", with: " ").capitalized
                        return (readableLabel, prob)
                    }
                
                // 5. 在主线程更新UI
                DispatchQueue.main.async {
                    var resultText = "预测结果：\n"
                    for (index, prediction) in topPredictions.enumerated() {
                        resultText += "\(index + 1). \(prediction.0): \(String(format: "%.1f", prediction.1 * 100))%\n"
                    }
                    resultText += String(format: "\n处理时间: %.2f秒", inferenceTime)
                    
                    self?.resultLabel.text = resultText
                    self?.resultLabel.textAlignment = .left
                    self?.resultLabel.numberOfLines = 0
                }
                
                print("预测完成，耗时: \(String(format: "%.2f", inferenceTime))秒")
                
            } catch {
                print("预测时出错: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.resultLabel.text = "预测时出错: \(error.localizedDescription)"
                    self?.resultLabel.textAlignment = .center
                }
            }
        }
    }
}

