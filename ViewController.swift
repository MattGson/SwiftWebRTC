//
//  ViewController.swift
//
//  Created by Matt Goodson on 26/06/17.
//  Copyright © 2017 Matt Goodson. All rights reserved.
//

import UIKit

struct Platform {
    
    static var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0 // Use this line in Xcode 7 or newer
    }
}

class ViewController: UIViewController {
    
    
    var toId = "Sim";
    var myId = "Device";
    var withVideo = true;
    var url = "ws://<INSERT-MAC-NAME>.local:9090"
    
    var webrtc:RTClient?
    var remoteView:RTCEAGLVideoView = RTCEAGLVideoView(frame: UIScreen.main.bounds);
    let localView:UIView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 150.0, height: 150.0));
    var previewLayer:AVCaptureVideoPreviewLayer?
    var remoteVideoTrack:RTCVideoTrack?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.remoteView);
 
        //This example is set up to make a call between a device and a simulator
        //It assumes that the simulator has no camera.
        
        if Platform.isSimulator {
            print("Running on Simulator")
            self.withVideo = false;
            self.toId = "Device";
            self.myId = "Sim";
        }
        else {
            print("Running on device");
        }

        self.webrtc = RTClient(withVideo: self.withVideo, url: url, id: myId, delegate: self);
        self.webrtc?.connect();
    }
    
    
    internal func joinPeer() {
        self.webrtc?.joinPeer(withId: self.toId);
    }
    

    internal func setLocalPreview() {
        
        if (self.withVideo) {
        
            self.previewLayer = self.webrtc?.getLocalPreview();
            self.previewLayer?.frame = self.localView.bounds;
            self.localView.layer.addSublayer(self.previewLayer!);
            self.view.addSubview(self.localView);
        }
    }
}


extension ViewController:RTClientDelegate {
    
    func addedStream(stream: RTCMediaStream) {
    
        if (stream.videoTracks.count > 0) {
        let remoteTrack:RTCVideoTrack = stream.videoTracks[0] as! RTCVideoTrack;
        
        if (self.remoteVideoTrack != nil) {
            self.remoteVideoTrack?.remove(self.remoteView);
            self.remoteVideoTrack = nil;
            self.remoteView.renderFrame(nil);
        }
        
        self.remoteVideoTrack = remoteTrack;
        self.remoteVideoTrack?.add(self.remoteView);
        }
    }
    
    
    func didConnect() {
        self.setLocalPreview();
        self.joinPeer();
    }
    
    func didDisconnect() {
        //Tidy up
        print("Disconnected");
    }
}








