import UIKit
import AVKit
import LightCompressor
import Photos

final class MainViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIImageView!
    @IBOutlet weak var originalSize: UILabel!
    @IBOutlet weak var sizeAfterCompression: UILabel!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    
    @IBOutlet weak var progressLabel:UILabel!
    @IBOutlet weak var videoSelectButtton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    let viewModel:MainViewModel
    var compression: Compression?
    
    
    private var imagePickerController: UIImagePickerController?
    
    required init?(coder: NSCoder) {
        viewModel = MainViewModel()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        // create tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(MainViewController.imageTapped(gesture:)))
        videoView.addGestureRecognizer(tapGesture)
        
        // make sure imageView can be interacted with by user
        videoView.isUserInteractionEnabled = true
        
        // configure AWS Amplify
        viewModel.configureAmplify()
    }
    
    @IBAction func pickVideoPressed(_ sender: UIButton) {
        
        DispatchQueue.main.async { [unowned self] in
            self.imagePickerController = UIImagePickerController()
            self.imagePickerController?.delegate = self
            self.imagePickerController?.sourceType = .photoLibrary
            self.imagePickerController?.mediaTypes = ["public.movie"]
            self.imagePickerController?.videoQuality = UIImagePickerController.QualityType.typeHigh
            self.imagePickerController?.videoExportPreset = AVAssetExportPresetPassthrough
            self.present(self.imagePickerController!, animated: true, completion: nil)
        }
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        compression?.cancel = true
        initView()
    }
    
    @objc func imageTapped(gesture: UIGestureRecognizer) {
        if (gesture.view as? UIImageView) != nil {
            DispatchQueue.main.async { [unowned self] in
                guard let player = self.viewModel.getAVPlayer() else {
                    return
                }
                let controller = AVPlayerViewController()
                controller.player = player
                self.present(controller, animated: true) {
                    player.play()
                }
            }
        }
    }
}
extension MainViewController {
    private func initView(){
        self.videoView.isHidden = true
        self.originalSize.isHidden = true
        self.sizeAfterCompression.isHidden = true
        self.duration.isHidden = true
        self.progressBar.isHidden = true
        self.progressLabel.isHidden = true
        self.videoSelectButtton.backgroundColor = .systemIndigo
        self.videoSelectButtton.layer.cornerRadius = 10
        self.cancelButton.backgroundColor = .systemRed
        self.cancelButton.layer.cornerRadius = 10
        self.progressLabel.numberOfLines = 0
        self.originalSize.numberOfLines = 0
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.imagePickerController?.dismiss(animated: true, completion: nil)
        // Get source video
        let videoToCompress = info[UIImagePickerController.InfoKey(rawValue: "UIImagePickerControllerMediaURL")] as! URL
        viewModel.originalPath = videoToCompress
        guard let thumbnail = viewModel.createThumbnailOfVideoFromFileURL(videoURL: videoToCompress.absoluteString) else { return }
        videoView.image = UIImage(cgImage: thumbnail)
        
        DispatchQueue.main.async { [unowned self] in
            self.originalSize.isHidden = false
            self.originalSize.text = "Original size: \(videoToCompress.fileSizeInMB())"
        }
        
        viewModel.initTimeString()
        startCompression(videoURL: videoToCompress)
    }
    
    private func startCompression(videoURL: URL) {
        // Declare destination path and remove anything exists in it
        let destinationPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(viewModel.destinationPathString)
        try? FileManager.default.removeItem(at: destinationPath)
        let videoCompressor = LightCompressor()
        
        compression = videoCompressor.compressVideo(
            source: videoURL,
            destination: destinationPath as URL,
            quality: .medium,
            isMinBitRateEnabled: true,
            keepOriginalResolution: false,
            progressQueue: .main,
            progressHandler: { progress in
                
            DispatchQueue.main.async { [unowned self] in
                self.progressBar.progress = Float(progress.fractionCompleted)
                self.progressLabel.text = "\(String(format: "%.0f", progress.fractionCompleted * 100))%"
            }},
                                                    
                                                    completion: {[weak self] result in
            guard let `self` = self else { return }
            
            // background processing
            NotificationCenter.default.addObserver(self, selector: #selector(self.backgroundEntered), name: UIScene.willDeactivateNotification, object: nil)
            
            switch result {
            case .onSuccess(let path):
                self.viewModel.compressedPath = path
                DispatchQueue.main.async { [unowned self] in
                    self.configureViewWhenSuccess()
                    self.sizeAfterCompression.text = "Size after compression: \(path.fileSizeInMB())"
                    self.duration.text = "Duration: \(String(format: "%.2f", Date().timeIntervalSinceNow * -1)) seconds"
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: path)
                    })

                    debugPrint("압축된 원본 :\(path)")
                    self.viewModel.uploadFile(localVideoLocation: path)
                }
            case .onStart:
                self.configureViewWhenStart()
                
            case .onFailure(let error):
                self.configureViewWhenFailure(error:error)
            case .onCancelled:
                debugPrint("---------------------------")
                debugPrint("Cancelled")
                debugPrint("---------------------------")
            }
        })
        
    }
    
    @objc func backgroundEntered(){
        debugPrint("Entered background!")
        compression?.cancel = true
        initView()
        self.originalSize.isHidden = false
        self.originalSize.text = "백그라운드 진입으로 작업을 중지합니다.\n다시 실행해주세요."
        self.videoSelectButtton.setTitle("다시 선택하기", for: .normal)
        NotificationCenter.default.removeObserver(self)
    }
    
    private func configureViewWhenStart(){
        self.videoView.isHidden = false
        self.progressBar.isHidden = false
        self.progressLabel.isHidden = false
        self.sizeAfterCompression.isHidden = true
        self.duration.isHidden = true
    }
    private func configureViewWhenSuccess(){
        self.sizeAfterCompression.isHidden = false
        self.duration.isHidden = false
        self.progressBar.isHidden = true
        self.progressLabel.isHidden = true
        self.videoSelectButtton.setTitle("비디오 선택", for: .normal)
        
    }
    private func configureViewWhenFailure(error:CompressionError){
        self.progressBar.isHidden = true
        self.progressLabel.isHidden = false
        self.progressLabel.text = error.title
        self.videoSelectButtton.setTitle("다시 선택하기", for: .normal)
    }
}
