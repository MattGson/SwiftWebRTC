//
//  RTClient.swift
//
//  Created by Matt Goodson on 27/06/17.
//  Copyright © 2017 Matt Goodson. All rights reserved.
//

import Foundation
import SocketRocket


protocol RTClientDelegate {
    
    func addedRemoteVideoTrack(videoTrack:RTCVideoTrack);
    func didConnect();
    func didDisconnect();
}


class RTClient: NSObject {
    
    var delegate:RTClientDelegate!
    var socket:SRWebSocket!
    var url:String!
    var id:String!
    var toId:String!
    var webRTC:WebRTC!
    var allowVideo:Bool = false;
    var remoteStream:RTCMediaStream?
    var localStream:RTCMediaStream?
    
    
    
    init(withVideo:Bool, url:String, id:String, delegate:RTClientDelegate) {
        
        super.init();
        self.url = url;
        self.allowVideo = withVideo;
        self.id = id;
        self.delegate = delegate;
    }
    
    
    
    func connect() {
        
        self.socket = nil;
        let newSocket = SRWebSocket(url: URL(string: url));
        newSocket?.delegate = self;
        
        if (self.webRTC == nil) {
            if (self.allowVideo) {
                self.webRTC = WebRTC(withVideo: true, delegate: self);
            } else {
                self.webRTC = WebRTC(withVideo: false, delegate: self);
            }
        }
        print("Opening socket on ", url);
        newSocket?.open();
        
    }
    
    
    
    func joinPeer(withId:String) {
        
        self.toId = withId;
        let message = SignalMessage(type: "join", fromId: self.id, toId: self.toId, payload: [String:AnyObject]());
        self.socket.send(message.toJSON());
    }
    
    
    func getLocalPreview() -> AVCaptureVideoPreviewLayer {
        let videoTrack: RTCVideoTrack = (self.localStream!.videoTracks.first)! as! RTCVideoTrack;
        let videoSource:RTCAVFoundationVideoSource = videoTrack.source as! RTCAVFoundationVideoSource;
        let session:AVCaptureSession = videoSource.captureSession;
        
        return AVCaptureVideoPreviewLayer(session: session);
    }
    
    
    
    internal func socketMessageRecieved(data:Any) {
        
    
        guard let message = SignalMessage(json: data) else {
            print("invalid signal message");
            return;
        }
        
        print("\nRecieved message of type: ", message.type, "\n");
        
        switch message.type {
            
        case "join":
            //Message recieved after joining a room that has another user in it
            //Initialize the peer connection and create an offer
            self.webRTC.setPeerConnection();
            self.webRTC.createOfferForPeer();
            break;
        
        case "leave":
            print("Peer left");
            
            
        case "iceFailed":
            //Recieved when a connection can not be established
            print("\nIce failed\n");
            break;
            
        case "candidate":
            //Recieved when peer has new ICE candidate
            let sdpMid:String = message.payload["sdpMid"] as! String;
            let mLineIndex:Int = message.payload["mLineIndex"] as! Int;
            let sdp:String = message.payload["sdp"] as! String;
            let candidate:RTCICECandidate = RTCICECandidate(mid: sdpMid, index: mLineIndex, sdp: sdp);
            self.webRTC.addICECandidate(candidate: candidate);
            break;
            
        case "answer":
            //Recieved when peer has answer
            let type:String = message.payload["type"] as! String;
            let sdp:String = message.payload["sdp"] as! String;
            let remoteSDP:RTCSessionDescription = RTCSessionDescription(type: type, sdp: sdp);
            self.webRTC.setRemoteDescription(remoteSDP: remoteSDP);
            break;
            
        case "offer":
            //Recieved when a peer joins the room after you
            self.webRTC.setPeerConnection();
            let originalSDP:String = message.payload["sdp"] as! String;
            let type:String = message.payload["type"] as! String;
            
            do {
                let regex:NSRegularExpression = try NSRegularExpression(pattern: "m=application \\d+ DTLS/SCTP 5000 *", options: []);
                let sdp:String = regex.stringByReplacingMatches(in: originalSDP, options: [], range: NSMakeRange(0, originalSDP.characters.count), withTemplate: "m=application 0 DTLS/SCTP 5000")
                let remoteSDP:RTCSessionDescription = RTCSessionDescription(type: type, sdp: sdp);
                self.webRTC.setRemoteDescription(remoteSDP: remoteSDP);
            } catch {
                print("\nRegex failed\n");
            }
            break;
            
        default:
            break;
        }
    }
}



extension RTClient:SRWebSocketDelegate {
    
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        print("Socket opened");
        DispatchQueue.main.async {
            self.socket = webSocket;
            self.localStream = self.webRTC.localMediaStream;
            self.delegate.didConnect();
        }
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        self.delegate.didDisconnect();
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        self.socketMessageRecieved(data: message);
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        print("\nSocket Failed with Error", error, "\n");
    }
    
    
}


extension RTClient:WebRTCDelegate {
    
    func sendICECandidate(candidate: RTCICECandidate) {
        let message:SignalMessage = SignalMessage(type: "candidate", fromId: self.id, toId: self.toId, payload: ["sdpMid":candidate.sdpMid,
                            "mLineIndex": candidate.sdpMLineIndex,
                            "sdp": candidate.sdp]);
        self.socket.send(message.toJSON());
    }
    
    
    func sendSDPOffer(offer: RTCSessionDescription) {
        let message:SignalMessage = SignalMessage(type: "offer", fromId: self.id, toId: self.toId, payload: ["type": offer.type, "sdp": offer.description]);
        self.socket.send(message.toJSON());
    }
    
    
    func sendSDPAnswer(answer: RTCSessionDescription) {
        let message:SignalMessage = SignalMessage(type: "answer", fromId: self.id, toId: self.toId, payload: ["type": answer.type, "sdp": answer.description]);
        self.socket.send(message.toJSON());
    }
    
    
    func addedStream(stream: RTCMediaStream) {
        
        self.remoteStream = stream;
        if (stream.videoTracks.count > 0) {
            let remoteTrack:RTCVideoTrack = stream.videoTracks[0] as! RTCVideoTrack;
            self.delegate.addedRemoteVideoTrack(videoTrack: remoteTrack);
        }
    }
    
}
