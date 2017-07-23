# SwiftWebRTC
A Swift interface for WebRTC using [libjingle_peerconnection](https://cocoapods.org/pods/libjingle_peerconnection), [Socket Rocket](https://github.com/facebook/SocketRocket) and a [Signalite](https://github.com/Mattattack/Signalite) signalling server

## Usage

At the moment, the files must be manually copied into your project. Download and copy the following files into your project.
```
RTClient.swift
SignalMessage.swift
WebRTC.swift 
```


Add the following to your podfile:

```
use_frameworks!

pod 'libjingle_peerconnection'
pod 'SocketRocket'
```

Run ```pod install```

Run an instance of the [Signalite](https://github.com/Mattattack/Signalite) server

See the example [viewController](https://github.com/Mattattack/SwiftWebRTC/blob/master/ViewController.swift) for setting up and managing a connection.
Remember to change the URL to the location where the server is running.
   
