//
//  SignalMessage.swift
//
//  Created by Matt Goodson on 27/06/17.
//  Copyright © 2017 Matt Goodson. All rights reserved.
//


import Foundation


class SignalMessage {
    
    
    var type:String!
    var toId:String!
    var fromId:String!
    var payload:[String:Any]!
    
    
    init(type:String, fromId:String, toId:String, payload:[String:Any]) {
        self.type = type
        self.fromId = fromId
        self.toId = toId
        self.payload = payload
        
    }
    
    
    
    init?(json:Any) {
        
        type = ""
        fromId = ""
        toId = ""
        payload = [String:Any]()
        
        
        do {
            
            guard let j = json as? NSData else {
                print("Input data is not valid JSON")
                return nil
            }
            
            
            let decoded = try JSONSerialization.jsonObject(with: j as Data, options: [])
            if let data = decoded as? [String:Any] {
                
                guard let type = data["type"] as? String else {
                    print("Invalid message type")
                    return nil
                }
                guard let fromId = data["fromId"] as? String else {
                    print("Invalid fromId")
                    return nil
                }
                guard let toId = data["toId"] as? String else {
                    print("Invalid toId")
                    return nil
                }
                guard let payload = data["payload"] as? [String:AnyObject] else {
                    print("Invalid payload")
                    return
                }
                
                self.type = type
                self.fromId = fromId
                self.toId = toId
                self.payload = payload
            }
            else {
                return nil
            }
        } catch let error as NSError {
            print(error)
            return nil
        }
    }
    
    
    
    
    func toJSON() -> Data? {
        
        let data:[String:Any] = ["type":type, "fromId":fromId, "toId":toId, "payload":payload]
        
        do {
            let jsonData:Data = try JSONSerialization.data(withJSONObject: data, options: JSONSerialization.WritingOptions.prettyPrinted)
            // here "jsonData" is the dictionary encoded in JSON data
            return jsonData;
            
        } catch let error as NSError {
            print(error)
        }
        return nil
    }
    
    
    func printMessage() {
        
        print("\n*******Signal********")
        print("Type: ", type)
        print("FromId: ", fromId)
        print("ToId: ", toId)
        print("Payload: ", payload)
        print("*********************\n")
        
    }
    
    
    
}
