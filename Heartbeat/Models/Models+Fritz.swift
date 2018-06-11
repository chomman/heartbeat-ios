//
//  Models+Fritz.swift
//  Heartbeat
//
//  Created by Andrew Barba on 1/6/18.
//  Copyright © 2018 Fritz Labs, Inc. All rights reserved.
//
import Fritz

extension MobileNet: SwiftIdentifiedModel {

    static let packagedModelVersion: Int = 1

    static let modelIdentifier: String = "model-id-1"

    static let session = Fritz.Session(appToken: "app-token-12345")
}

extension MNIST: SwiftIdentifiedModel {

    static let packagedModelVersion: Int = 1

    static let modelIdentifier: String = "model-id-2"

    static let session = Fritz.Session(appToken: "app-token-12345")
}

extension AgeNet: SwiftIdentifiedModel {

    static let packagedModelVersion: Int = 1

    static let modelIdentifier: String = "model-id-3"

    static let session = Fritz.Session(appToken: "app-token-12345")
}

extension GenderNet: SwiftIdentifiedModel {

    static let packagedModelVersion: Int = 1

    static let modelIdentifier: String = "model-id-4"

    static let session = Fritz.Session(appToken: "app-token-12345")
}

extension SSDMobilenetFeatureExtractor: SwiftIdentifiedModel {

    static let packagedModelVersion: Int = 1

    static let modelIdentifier: String = "model-id-5"
    
    static let session = Fritz.Session(appToken: "app-token-12345")
}

extension starry_night_a05_640x480: SwiftIdentifiedModel {
    
    static let packagedModelVersion: Int = 1
    
    static let modelIdentifier: String = "model-id-6"
    
    static let session = Fritz.Session(appToken: "app-token-12345")
}

extension girl_before_mirror_a05_640x480: SwiftIdentifiedModel {
    
    static let packagedModelVersion: Int = 1
    
    static let modelIdentifier: String = "model-id-7"
    
    static let session = Fritz.Session(appToken: "app-token-12345")
}
