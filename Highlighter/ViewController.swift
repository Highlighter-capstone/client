import UIKit
import MobileCoreServices
import AVKit
import Photos
import LightCompressor
import Amplify
import AWSCognitoAuthPlugin
import AWSS3StoragePlugin

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIImageView!
    @IBOutlet weak var originalSize: UILabel!
    @IBOutlet weak var sizeAfterCompression: UILabel!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var progressView: UIStackView!
    @IBOutlet weak var progressBar: UIProgressView!
    
    @IBOutlet weak var progressLabel:UILabel!
    private var imagePickerController: UIImagePickerController?
    private var compression: Compression?
    
    private var compressedPath: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        // create tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.imageTapped(gesture:)))
        
        // add it to the image view;
        videoView.addGestureRecognizer(tapGesture)
        // make sure imageView can be interacted with by user
        videoView.isUserInteractionEnabled = true
        
        // configure AWS Amplify
        configureAmplify()
    }
    private func initView(){
        self.videoView.isHidden = true
        self.originalSize.isHidden = true
        self.sizeAfterCompression.isHidden = true
        self.duration.isHidden = true
        self.progressBar.isHidden = true
        self.progressLabel.isHidden = true
    }
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.imagePickerController?.dismiss(animated: true, completion: nil)
        
        // Get source video
        let videoToCompress = info[UIImagePickerController.InfoKey(rawValue: "UIImagePickerControllerMediaURL")] as! URL
        
        let thumbnail = createThumbnailOfVideoFromFileURL(videoURL: videoToCompress.absoluteString)
        videoView.image = UIImage(cgImage: thumbnail!)
        
        DispatchQueue.main.async { [unowned self] in
            self.originalSize.isHidden = false
            self.originalSize.text = "Original size: \(videoToCompress.fileSizeInMB())"
        }
        
        
        // Declare destination path and remove anything exists in it
        let destinationPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("compressed.mp4")
        try? FileManager.default.removeItem(at: destinationPath)
        
        let startingPoint = Date()
        let videoCompressor = LightCompressor()
        
        compression = videoCompressor.compressVideo(source: videoToCompress,
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
            
            switch result {
                
            case .onSuccess(let path):
                self.compressedPath = path
                DispatchQueue.main.async { [unowned self] in
                    self.sizeAfterCompression.isHidden = false
                    self.duration.isHidden = false
                    self.progressBar.isHidden = true
                    self.progressLabel.isHidden = true
                    
                    self.sizeAfterCompression.text = "Size after compression: \(path.fileSizeInMB())"
                    self.duration.text = "Duration: \(String(format: "%.2f", startingPoint.timeIntervalSinceNow * -1)) seconds"
                    
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: path)
                    })
                    // 내가작성
                    print("압축된 원본 :\(path)")
                    self.cropVideo(sourceURL1: path, statTime: 3, endTime: 5)
                    self.uploadFile()
                }
                
            case .onStart:
                self.videoView.isHidden = false
                self.progressBar.isHidden = false
                self.progressLabel.isHidden = false
                self.sizeAfterCompression.isHidden = true
                self.duration.isHidden = true
                //self.originalSize.visiblity(gone: false)
                
            case .onFailure(let error):
                self.progressBar.isHidden = true
                self.progressLabel.isHidden = false
                self.progressLabel.text = (error as! CompressionError).title
                
                
            case .onCancelled:
                print("---------------------------")
                print("Cancelled")
                print("---------------------------")
            }
        })
        
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
        // if the tapped view is a UIImageView then set it to imageview
        if (gesture.view as? UIImageView) != nil {
            
            DispatchQueue.main.async { [unowned self] in
                let player = AVPlayer(url: self.compressedPath! as URL)
                let controller = AVPlayerViewController()
                controller.player = player
                self.present(controller, animated: true) {
                    player.play()
                }
            }
            
        }
    }
    
    func createThumbnailOfVideoFromFileURL(videoURL: String) -> CGImage? {
        let asset = AVAsset(url: URL(string: videoURL)!)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        let time = CMTimeMakeWithSeconds(Float64(1), preferredTimescale: 100)
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            return img
        } catch {
            return nil
        }
    }
}


extension URL {
    func fileSizeInMB() -> String {
        let p = self.path
        
        let attr = try? FileManager.default.attributesOfItem(atPath: p)
        
        if let attr = attr {
            let fileSize = Float(attr[FileAttributeKey.size] as! UInt64) / (1024.0 * 1024.0)
            
            return String(format: "%.2f MB", fileSize)
        } else {
            return "Failed to get size"
        }
    }
}

//내가 작성
extension ViewController{
    func cropVideo(sourceURL1: URL, statTime:Float, endTime:Float)
    {
        let manager = FileManager.default
        
        guard let documentDirectory = try? manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {return}
        let mediaType = "mp4"
        if mediaType == kUTTypeMovie as String || mediaType == "mp4" as String {
            let asset = AVAsset(url: sourceURL1 as URL)
            let length = Float(asset.duration.value) / Float(asset.duration.timescale)
            print("video length: \(length) seconds")
            
            let start = statTime
            let end = endTime
            
            var outputURL = documentDirectory.appendingPathComponent("output")
            do {
                try manager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
                outputURL = outputURL.appendingPathComponent("\(UUID().uuidString).\(mediaType)")
            }catch let error {
                print(error)
            }
            
            //Remove existing file
            _ = try? manager.removeItem(at: outputURL)
            
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {return}
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            
            let startTime = CMTime(seconds: Double(start ), preferredTimescale: 1000)
            let endTime = CMTime(seconds: Double(end ), preferredTimescale: 1000)
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            
            exportSession.timeRange = timeRange
            exportSession.exportAsynchronously{
                switch exportSession.status {
                case .completed:
                    print("exported at \(outputURL)")
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                    })
                case .failed:
                    print("failed \(exportSession.error)")
                    
                case .cancelled:
                    print("cancelled \(exportSession.error)")
                    
                default: break
                }
            }
        }
    }
}

extension ViewController{
    
    private func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSS3StoragePlugin())
            
            try Amplify.configure()
            print("Successfully configured Amplify")
            
        } catch {
            print("Could not configure Amplify", error)
        }
    }
    func uploadFile() {
        let videoKey = "compressed.mp4"
        let videoURL = self.compressedPath!
        Amplify.Storage.uploadFile(key: videoKey, local: videoURL) { result in
            switch result {
            case .success(let uploadedData):
                print(uploadedData)
            case .failure(let error):
                print(error)
            }
        }
    }
//    func downloadImage() {
//        Amplify.Storage.downloadData(key: imageKey) { result in
//            switch result {
//            case .success(let data):
//                DispatchQueue.main.async {
//                    self.image = UIImage(data: data)
//                }
//            case .failure(let error):
//                print(error)
//            }
//        }
//    }
}
