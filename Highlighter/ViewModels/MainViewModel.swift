import Foundation
import Amplify
import AWSCognitoAuthPlugin
import AWSS3StoragePlugin
import AVKit
import MobileCoreServices
import Photos
import LightCompressor


final class MainViewModel {
    var originalPath:URL?
    var compressedPath: URL?
    private var userID:String = ""
    private var timeString:String = ""
    var destinationPathString: String {
        return "\(userID)-\(timeString).mp4"
    }
    
    func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSS3StoragePlugin())
            
            try Amplify.configure()
            debugPrint("Successfully configured Amplify")
            
        } catch {
            debugPrint("Could not configure Amplify", error)
        }
    }
    
    func uploadFile(localVideoLocation: URL) {
        let videoKey = "\(userID)-\(timeString).mp4"
        debugPrint("- videoKey : \(videoKey)")
        let videoURL = self.compressedPath!
        debugPrint("- local videoURL : \(videoURL)")
        Amplify.Storage.uploadFile(key: videoKey, local: videoURL) { result in
            switch result {
            case .success(let uploadedData):
                debugPrint("===== upload to S3 SUCCESS =====", uploadedData)
                // 업로드 후 서버에 request
                self.sendToServer(key: videoKey, localVideoLocation: localVideoLocation)
            case .failure(let error):
                debugPrint("S3 Error : ", error)
            }
        }
    }
    
    private func sendToServer(key:String, localVideoLocation:URL){
        guard let url = URL(string: "http://\(Address.ip):\(Address.port)") else { return }
        var request = URLRequest(url:url)
        request.httpMethod = "POST"
        let dic:Dictionary = ["video_name": key]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted)
        } catch {
            debugPrint("ERROR : ", error.localizedDescription)
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept-Type")
        
        debugPrint("URLSession 진입")
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 600
        sessionConfig.timeoutIntervalForResource = 600
        let session = URLSession(configuration: sessionConfig)
        session.dataTask(with: request, completionHandler: {(data, response, error) in
            
            debugPrint("===== send to server SUCCESS ===== data :\(data)")
            guard let data = data,
                  let decodedTime = try? JSONDecoder().decode(TimeResponse.self, from: data) else {
                debugPrint("Error: URLSession Decode - \(error?.localizedDescription ?? ".")")
                return
            }
            debugPrint("decoded : ", decodedTime.success, decodedTime.time)
            if !decodedTime.time.isEmpty{
                debugPrint("time[0] : ", decodedTime.time[0].min, decodedTime.time[0].max)
            }
            
            for i in decodedTime.time {
                self.cropVideo(sourceURL: self.originalPath!, statTime: Float(i.min), endTime: Float(i.max))
            }
            
        }).resume()
    }
    
    func cropVideo(sourceURL: URL, statTime:Float, endTime:Float) {
        let manager = FileManager.default
        guard let documentDirectory = try? manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {return}
        let mediaType = "mp4"
        if mediaType == kUTTypeMovie as String || mediaType == "mp4" as String {
            let asset = AVAsset(url: sourceURL as URL)
            let length = Float(asset.duration.value) / Float(asset.duration.timescale)
            debugPrint("video length: \(length) seconds")
            
            let start = statTime
            let end = endTime
            
            var outputURL = documentDirectory.appendingPathComponent("output")
            do {
                try manager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
                outputURL = outputURL.appendingPathComponent("\(UUID().uuidString).\(mediaType)")
            } catch let error {
                debugPrint(error)
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
                    debugPrint("exported at \(outputURL)")
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                    })
                case .failed:
                    debugPrint("failed \(exportSession.error)")
                    
                case .cancelled:
                    debugPrint("cancelled \(exportSession.error)")
                    
                default: break
                }
            }
        }
    }
    
    func getAVPlayer() -> AVPlayer? {
        guard let url = compressedPath else { return nil }
        return AVPlayer(url: url)
    }
    
    func initTimeString() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.locale = Locale(identifier: "ko")
        timeString = formatter.string(from: Date())
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
