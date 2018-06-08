//
//  StyleTransferInput.swift
//  Heartbeat
//
//  Created by Jameson Toole on 6/8/18.
//  Copyright © 2018 Fritz Labs, Inc. All rights reserved.
//

import CoreML
import CoreVideo

// JC: Technically 640x480 below. Should rename this to something a little bit more generic, like `PixelBufferFeatureProvider`
class StyleTransferInput : MLFeatureProvider {
    
    /// input as color (kCVPixelFormatType_32BGRA) image buffer, 720 pixels wide by 720 pixels high
    var input: CVPixelBuffer
    
    var featureNames: Set<String> {
        get {
            return ["input1"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "input1") {
            return MLFeatureValue(pixelBuffer: input)
        }
        return nil
    }
    
    init(input: CVPixelBuffer) {
        self.input = input
    }
}
