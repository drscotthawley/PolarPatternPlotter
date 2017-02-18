//
//  RingBuffer.swift
//  PolarPatternPloter
//
//  Created by Scott Hawley on 5/8/16.
//  Copyright © 2016 Scott Hawley. All rights reserved.
//

import UIKit

class RingBuffer: NSObject {
    
    var buffer = [Float]()
    var total:Float = 0.0
    var inPtr:Int = 0
    var maxlen:Int = 0
    var filled:Bool = false
    
    // for direction values.  must be stored as radians
    var angularValues:Bool = false
    var totalSin:Float = 0.0
    var totalCos:Float = 0.0
    var sinBuffer = [Float]()
    var cosBuffer = [Float]()
    
    
    init(length:Int, angular:Bool) {
        maxlen = length
        angularValues = angular
        if (angular) {
            sinBuffer = [Float](repeating: 0.0, count: length)
            cosBuffer = [Float](repeating: 0.0, count: length)
        } else {
            buffer = [Float](repeating: 0.0, count: length)
        }
    }
    
    func addValue(_ val:Float) {
        
        if (angularValues) {
            totalSin = totalSin - sinBuffer[inPtr] + sin(val)
            totalCos = totalCos - cosBuffer[inPtr] + cos(val)
            sinBuffer[inPtr] = sin(val)
            cosBuffer[inPtr] = cos(val)
        } else {
            total = total - buffer[inPtr] + val
            buffer[inPtr] = val
        }
        
        inPtr = inPtr + 1
        if (inPtr >= maxlen) {
            filled = true
            inPtr = 0
        }
    }
    
    func getAverage()->Float {
        var n = Float(inPtr)
        if (filled) {
            n = Float(maxlen)
        }
        if (angularValues) {
            //let avgSin = totalSin / n
            //let avgCos = totalCos / n
            return atan2f(totalSin, totalCos) // 1/n in numerator & denominator cancels out
            
        }
        return total / n
    }
}
