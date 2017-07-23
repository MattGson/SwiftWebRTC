//
//  WebRTC.swift
//
//  Created by Matt Goodson on 27/06/17.
//  Copyright © 2017 Matt Goodson. All rights reserved.
//

import Foundation


protocol WebRTCDelegate {
    
    func sendSDPOffer(offer:RTCSessionDescription);
    func sendSDPAnswer(answer:RTCSessionDescription);
    func sendICECandidate(candidate:RTCICECandidate);
    func addedStream(stream:RTCMediaStream);
}


class WebRTC: NSObject {
    
    
    //MARK:- Properties
    
    var delegate:WebRTCDelegate;
    
    var localMediaStream:RTCMediaStream?
    var peerFactory:RTCPeerConnectionFactory = RTCPeerConnectionFactory();
    var peerConnection:RTCPeerConnection?
    var iceCandidates = [RTCICECandidate]();
    
    var allowVideo:Bool = false;
    var videoDevice:AVCaptureDevice?
    
    var iceServers:[RTCICEServer] = [RTCICEServer]();
    
    var hasSentAnswer = false;
    
    static let PeerCoannectionRoleIntitator = "PeerConnectionRoleIntiator";
    static let PeerConnectionRoleReciever = "PeerConnectionRoleReciever";
    static let STUNHostName:String = "stun:stun.l.google.com:19302";
    
    
    
    //MARK:- Initialization
    
    init(withVideo:Bool, delegate:WebRTCDelegate) {
        //setup front camera as default device
        
        self.delegate = delegate;
        super.init();
        
        var frontCamera:AVCaptureDevice?
        if (withVideo) {
            for device in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
                if ((device as! AVCaptureDevice).position == AVCaptureDevicePosition.front) {
                    frontCamera = device as? AVCaptureDevice;
                }
            }
        }
        
        if (frontCamera != nil) {
            self.allowVideo = true;
            self.videoDevice = frontCamera;
        }
        self.setup();
    }
    
    
    
    
    //MARK:- Setup
    
    private func setup() {
        //set default STUN server and init SSL
        
        let url:URL = URL(string: WebRTC.STUNHostName)!;
        let defaultSTUNServer: RTCICEServer = RTCICEServer(uri: url, username: "", password: "");
        self.iceServers.append(defaultSTUNServer);
        RTCPeerConnectionFactory.initializeSSL();
        self.createLocalStream();
    }
    
    
    
    private func createLocalStream() {
        
        //Create the local media stream with video and audio
        
        self.localMediaStream = self.peerFactory.mediaStream(withLabel: "LOCALM1");
        let audioTrack:RTCAudioTrack = self.peerFactory.audioTrack(withID: "AUDIO1");
        self.localMediaStream?.addAudioTrack(audioTrack);
        
        if (self.allowVideo) {
            let videoSource:RTCAVFoundationVideoSource = RTCAVFoundationVideoSource(factory: self.peerFactory, constraints: nil);
            videoSource.useBackCamera = false;
            let videoTrack: RTCVideoTrack = RTCVideoTrack(factory: self.peerFactory, source: videoSource, trackId: "VIDEO1");
            self.localMediaStream?.addVideoTrack(videoTrack);
        }
    }
    
    
    internal func mediaConstraints() -> RTCMediaConstraints {
        
        let audioConstraint:RTCPair = RTCPair(key: "OfferToReceiveAudio", value: "true");
        let videoConstraint:RTCPair = RTCPair(key: "OfferToReceiveVideo", value: self.allowVideo ? "true" : "False");
        let sctpConstraint:RTCPair = RTCPair(key: "internalSctpDataChannels", value: "true");
        let dtlsConstraint:RTCPair = RTCPair(key: "DtlsSrtpKeyAgreement", value: "true");
        
        return RTCMediaConstraints(mandatoryConstraints: [audioConstraint, videoConstraint], optionalConstraints: [sctpConstraint, dtlsConstraint]);
    }
    
    
    
    //MARK:- Peer Connection
    
    func setPeerConnection() {
        //Create a peer connection and add local media stream to it
        //Only one connection is stored as doing 1:1 calls
        
        let peer:RTCPeerConnection = self.peerFactory.peerConnection(withICEServers: self.iceServers, constraints: self.mediaConstraints(), delegate: self);
        peer.add(self.localMediaStream);
        self.peerConnection = peer;
    }
    
    
    func closePeerConnection() {
        //Remove existing peer connection
        
        self.peerConnection?.close();
        self.peerConnection = nil;
    }
    
    
    func createOfferForPeer() {
        self.peerConnection?.createOffer(with: self, constraints: self.mediaConstraints());
    }
    
    
    func setRemoteDescription(remoteSDP:RTCSessionDescription) {
        peerConnection?.setRemoteDescriptionWith(self, sessionDescription: remoteSDP);
    }
    
    func addICECandidate(candidate:RTCICECandidate) {
        
        if (self.peerConnection?.iceGatheringState == RTCICEGatheringNew) {
            self.iceCandidates.append(candidate);
        }
        else {
            self.peerConnection?.add(candidate);
        }
    }
    
}






extension WebRTC:RTCSessionDescriptionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didSetSessionDescriptionWithError error: Error!) {
        DispatchQueue.main.async {
            
            if (peerConnection.iceGatheringState == RTCICEGatheringGathering) {
                
                for candidate in self.iceCandidates {
                    peerConnection.add(candidate);
                }
                self.iceCandidates.removeAll();
            }
            
            
            if (peerConnection.signalingState == RTCSignalingHaveLocalOffer) {
                if (self.peerConnection != nil) {
              
                    self.delegate.sendSDPOffer(offer: peerConnection.localDescription);
                }
            }
            else if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer) {
                peerConnection.createAnswer(with: self, constraints: self.mediaConstraints());
            }
            else if (peerConnection.signalingState == RTCSignalingStable) {
                if (self.peerConnection != nil && !self.hasSentAnswer) {
            
                    self.delegate.sendSDPAnswer(answer: peerConnection.localDescription);
                    self.hasSentAnswer = true;
                }
            }
        }
    }
    
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didCreateSessionDescription sdp: RTCSessionDescription!, error: Error!) {
        DispatchQueue.main.async {
            let sessionDescription:RTCSessionDescription = RTCSessionDescription(type: sdp.type, sdp: sdp.description);
            peerConnection.setLocalDescriptionWith(self, sessionDescription: sessionDescription);
        }
    }
    
}




extension WebRTC:RTCPeerConnectionDelegate {
    
    
    func peerConnection(onRenegotiationNeeded peerConnection: RTCPeerConnection!) {
        //?????
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, addedStream stream: RTCMediaStream!) {
        print("Stream added, may be local stream");
        
        DispatchQueue.main.async {
            self.delegate.addedStream(stream:stream);
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, removedStream stream: RTCMediaStream!) {
        //TODO:- self.delegate.removedStream(stream)
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, iceGatheringChanged newState: RTCICEGatheringState) {
        //??????????
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, iceConnectionChanged newState: RTCICEConnectionState) {
        //TODO:- self.delegate.didObserverICEConnectionStateChange(state)
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, signalingStateChanged stateChanged: RTCSignalingState) {
        //????
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, gotICECandidate candidate: RTCICECandidate!) {
       
        DispatchQueue.main.async {
            if (self.peerConnection != nil) {
                self.delegate.sendICECandidate(candidate: candidate);
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didOpen dataChannel: RTCDataChannel!) {
        //?????????
    }
}







