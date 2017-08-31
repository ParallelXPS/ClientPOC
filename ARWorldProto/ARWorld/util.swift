//
//  util.swift
//  ARWorld
//
//  Created by Ian Starnes on 8/30/17.
//  Copyright © 2017 Project Dent. All rights reserved.
//

import Foundation

public class Stopwatch {
    public init() { }
    private var start_: TimeInterval = 0.0;
    private var end_: TimeInterval = 0.0;
    var is_running = false
    
    public func start() {
        is_running = true
        start_ = Date().timeIntervalSince1970;
    }
    
    public func stop() {
        is_running = false
        end_ = Date().timeIntervalSince1970;
    }
    
    public func reset() {
        self.start()
    }
    
    public func durationSeconds() -> TimeInterval {
        end_ = Date().timeIntervalSince1970
        return end_ - start_;
    }
}


