//
//  Extensions.swift
//  Body Music
//
//  Created by Carlo Aguilar on 13/04/21.
//

import SceneKit

extension simd_float2 {
    var hasValidNumbers: Bool {
        return !x.isNaN && !y.isNaN
    }
}

extension float4x4 {
    var position: SCNVector3 {
        return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }
}


extension SCNVector3 {
    
    func substract(vector: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(self.x - vector.x, self.y - vector.y, self.z - vector.z)
    }
    
    /// Calculate the magnitude of this vector
    var magnitude: SCNFloat {
        get {
            return sqrt(dotProduct(self))
        }
    }
    
    /// Vector in the same direction as this vector with a magnitude of 1
    var normalized: SCNVector3 {
        get {
            let localMagnitude = magnitude
            let localX = x / localMagnitude
            let localY = y / localMagnitude
            let localZ = z / localMagnitude
            
            return SCNVector3(localX, localY, localZ)
        }
    }
    
    /**
     Calculate the dot product of two vectors
     
     - parameter vectorB: Other vector in the calculation
     */
    func dotProduct(_ vectorB:SCNVector3) -> SCNFloat {
        
        return (x * vectorB.x) + (y * vectorB.y) + (z * vectorB.z)
    }
}

extension String {
  
  func image() -> UIImage? {
    
    let size = CGSize(width: 20, height: 22)
    
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    UIColor.clear.set()
    
    let rect = CGRect(origin: .zero, size: size)
    UIRectFill(CGRect(origin: .zero, size: size))
    
    (self as AnyObject).draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    
    UIGraphicsEndImageContext()
    
    return image
  }
}
