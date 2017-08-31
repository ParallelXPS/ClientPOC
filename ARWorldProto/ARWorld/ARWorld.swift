//
//  ARWorld.swift
//  ARWorld
//
//  Created by Ian Starnes on 8/29/17.
//  Copyright © 2017 311Labs LLC. All rights reserved.
//

import Foundation

let AR_WORLD_URL = "https://itf.io"

class ARWorldSession {
    var username: String
    var token: String? = nil
    
    init(username: String) {
        self.username = username
    }
    
    func addObject(data: Dictionary<String, Any>, completion: @escaping ((_ status:Bool, _ response: Dictionary<String, Any>) -> Void)) {
        do {
            try self.postRequest(path: "rpc/arworld/object", data: data) { status, response in
                if (status == true) {
                    if let jsonResult = response["data"] as? Dictionary<String, Any> {
                        completion(true, jsonResult)
                        return
                    }
                }
                completion(false, [:])
            }
        } catch {
            print(error)
        }
    }
    
    func fetchObjects(lat: Double, lng: Double, alt: Double, completion: @escaping ((_ status:Bool, _ response: Array<Any>) -> Void)) {
        print("fetchObjects")
        print(self.token ?? "no token")
        if self.token == nil {
            self.refreshToken() { status in
                if self.token != nil {
                    self.fetchObjects(lat: lat, lng: lng, alt: alt, completion: completion)
                }
            }
            return
        }
        
        let slat:String = String(format:"%.10f", lat)
        let slng:String = String(format:"%.10f", lng)
        let salt:String = String(format:"%.10f", alt)
        
        let params = [
            "token": self.token!,
            "size": "1000",
            "lat": slat,
            "lng": slng,
            "alt": salt
        ]
        
        self.getRequest(path: "rpc/arworld/observation", params: params) { status, response in
            if (status == true) {
                if let jsonResult = response["data"] as? Array<Any> {
                    // do whatever with jsonResult
                    completion(true, jsonResult)
                    return
                }
            }
            completion(false, [Any]())
        }
    }
    
    func refreshToken(completion: @escaping ((_ status: Bool) -> Void)) {
        let requestData = ["username": self.username, "group":1] as [String : Any]
        do {
            try self.postRequest(path: "rpc/arworld/auth", data: requestData) { status, response in
                if (status == true) {
                    if let jsonResult = response["data"] as? Dictionary<String, Any> {
                        // do whatever with jsonResult
                        self.token = jsonResult["token"] as? String
                        print("token is: \(String(describing: self.token))")
                        completion(true)
                        return
                    }
                }
                completion(false)
            }
        } catch {
            print(error)
        }
    }
    
    func getRequest(path: String, params: [String: Any], completion: @escaping ((_ status:Bool, _ response: Dictionary<String, Any>) -> Void)) {
        let parameterString = params.stringFromHttpParameters()
 
        var request = URLRequest(url: URL(string: "\(AR_WORLD_URL)/\(path)?\(parameterString)")!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            var postResponse:[String:Any] = ["status": true]
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                postResponse["status"] = false
                postResponse["error"] = error?.localizedDescription ?? "No data"
                completion(false, postResponse as! Dictionary<String, Int>)
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                if responseJSON["data"] != nil {
                    postResponse["data"] = responseJSON["data"]
                } else if responseJSON["error"] != nil {
                    postResponse["status"] = false
                    postResponse["error"] = responseJSON["error"]
                }
                completion(true, postResponse)
            }
        }
        
        task.resume()
    }

    func postRequest(path: String, data: Dictionary<String, Any>, completion: @escaping ((_ status:Bool, _ response: Dictionary<String, Any>) -> Void)) throws {
        var jsonObj = data
        if (self.token != nil) {
            jsonObj["token"] = self.token
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted)
        var request = URLRequest(url: URL(string: "\(AR_WORLD_URL)/\(path)")!)
        
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            var postResponse:[String:Any] = ["status": true]
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                postResponse["status"] = false
                postResponse["error"] = error?.localizedDescription ?? "No data"
                completion(false, postResponse as! Dictionary<String, Int>)
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                if let responseDATA = responseJSON["data"] as? [String: Any] {
                    postResponse["data"]  = responseDATA
                } else if let responseErr = responseJSON["error"] as? String {
                    postResponse["status"] = false
                    postResponse["error"] = responseErr
                }
                completion(true, postResponse)
            }
        }
        
        task.resume()
    }
}

extension String {
    
    /// Percent escapes values to be added to a URL query as specified in RFC 3986
    ///
    /// This percent-escapes all characters besides the alphanumeric character set and "-", ".", "_", and "~".
    ///
    /// http://www.ietf.org/rfc/rfc3986.txt
    ///
    /// :returns: Returns percent-escaped string.
    
    func addingPercentEncodingForURLQueryValue() -> String? {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }
    
}

extension Dictionary {
    
    /// Build string representation of HTTP parameter dictionary of keys and objects
    ///
    /// This percent escapes in compliance with RFC 3986
    ///
    /// http://www.ietf.org/rfc/rfc3986.txt
    ///
    /// :returns: String representation in the form of key1=value1&key2=value2 where the keys and values are percent escaped
    
    func stringFromHttpParameters() -> String {
        let parameterArray = self.map { (key, value) -> String in
            let percentEscapedKey = (key as! String).addingPercentEncodingForURLQueryValue()!
            let percentEscapedValue = (value as! String).addingPercentEncodingForURLQueryValue()!
            return "\(percentEscapedKey)=\(percentEscapedValue)"
        }
        
        return parameterArray.joined(separator: "&")
    }
}
