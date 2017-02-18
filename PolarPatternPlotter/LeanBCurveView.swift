//
//  LeanBCurveView.swift
//  Knobility
//
//  Created by Scott Hawley on 8/21/15.
//  Copyright © 2015 Virtual School of Music. All rights reserved.
//
// Following http://cocoabite.com/post/110000170154/smooth-drawing-in-swift
// support for multiple paths is my own


import UIKit

class LeanBCurveView: UIView {
    
    /*
     // Only override drawRect: if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func drawRect(rect: CGRect) {
     // Drawing code
     }
     */
    
    var paths = [UIBezierPath()]
    var currentPath = UIBezierPath()
    var pathThatWasTouched = UIBezierPath()
    
    var previousPoint:CGPoint = CGPoint.zero
    var lineWidth:CGFloat = 12.0
    var lineColor:UIColor = UIColor.green
    var lineCapStyle:CGLineCap = CGLineCap.round
    var lineJoinStyle:CGLineJoin = CGLineJoin.round
    
    
    
    override init(frame: CGRect) {
        paths = []
        let randomRed:CGFloat = CGFloat(drand48())
        let randomGreen:CGFloat = CGFloat(drand48())
        let randomBlue:CGFloat = CGFloat(drand48())
        lineColor = UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: 1.0)
        //let randomRed:CGFloat = CGFloat(arc4random_uniform(256))
        //let randomGreen:CGFloat = CGFloat(arc4random_uniform(256))
        //let randomBlue:CGFloat = CGFloat(arc4random_uniform(256))
        //lineColor =  UIColor(red: randomRed/255, green: randomGreen/255, blue: randomBlue/255, alpha: 1.0)
        
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
        
    }
    
    // NSCoding compliance
    let pathsKey = "paths"
    let lineColorKey = "lineColor"    // lineColor is not a 'stock' property of UIBezierPath
    let transformKey = "transform"
    
    //let lineWidthKey = "lineWidth"
    //let lineCapStyleKey = "lineCapStyle"
    //let lineJoinStyleKey = "lineJoinStyle"
    
    // each member of paths is a UIBezierCurve and comes with plenty of info.
    // the trick is coding an array of them
    required init?(coder: NSCoder) {
        print("decoding LeanBCurveView...")
        super.init(coder: coder)
        
        if coder.containsValue(forKey: transformKey) {
            self.transform = coder.decodeCGAffineTransform(forKey: transformKey)
        }
        if coder.containsValue(forKey: pathsKey) {
            paths = coder.decodeObject(forKey: pathsKey) as! [UIBezierPath]
            if (paths.count > 0) {   //trust NSCoding of each UIBezierCurve in paths
                lineWidth = paths[0].lineWidth
                lineCapStyle = paths[0].lineCapStyle
                lineJoinStyle = paths[0].lineJoinStyle
            }
            print("     still decoding LeanBCurveView with \(paths.count) elements...")
            
            
        } else {
            print("     no pathsKey found.  paths.count = \(paths.count), paths = \(paths)")
        }
        //lineColor = NSUserDefaults.standardUserDefaults().colorForKey("lineColorKey")!
        if coder.containsValue(forKey: lineColorKey) {
            lineColor = (coder.decodeObject(forKey: lineColorKey) as! UIColor?)!
        }
        self.backgroundColor = UIColor.clear
        print("Finished decoding LeanBCurveView with \(paths.count) elements, paths = \(paths).")
        
    }
    
    override func encode(with coder: NSCoder) {
        print("encoding LeanBCurveView with \(paths.count) elements...")
        super.encode(with: coder)
        
        coder.encode(self.transform, forKey: transformKey)
        
        coder.encode( paths as [UIBezierPath], forKey: pathsKey)
        coder.encode(lineColor, forKey: lineColorKey)
        //NSUserDefaults.standardUserDefaults().encodeColor(lineColor, forKey: lineColorKey)
        //coder.encodeObject( lineCapStyle, forKey: lineCapStyleKey)
        //coder.encodeObject( lineJoinStyle, forKey: lineJoinStyleKey)
        
        // lets say path info is downloaded, however how do we get it drawn?
    }
    
    
    
    // Actual drawing work...
    
    override func draw(_ rect: CGRect) {
        //super.drawRect(rect)
        // Drawing code
        lineColor.setStroke()
        for path in paths {
            path.stroke()
            path.lineCapStyle = lineCapStyle
            path.lineJoinStyle = lineJoinStyle
            path.lineWidth=lineWidth
        }
    }
    
    
    // Mark: remove any element from any kind of array
    func arrayRemovingObject<U: Equatable>(_ object: U, fromArray:[U]) -> [U] {
        return fromArray.filter { return $0 != object }
    }
    // Pulls a particular path from a paths array
    func removeFromPaths(_ path: UIBezierPath) {
        paths = arrayRemovingObject(path, fromArray: paths)
        self.setNeedsDisplay()
    }
    
    
    // pass through events that are not on the line
    // http://oleb.net/blog/2012/02/cgpath-hit-testing/
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool
    {
        var result : Bool = false
        
        for path in paths {
            let checkPath : CGPath = CGPath(__byStroking: path.cgPath, transform: nil, lineWidth: path.lineWidth, lineCap: path.lineCapStyle, lineJoin: path.lineJoinStyle, miterLimit: path.miterLimit)!
            
            //if CGPathContainsPoint(checkPath, nil, point, false) {
            if checkPath.contains(point)  {

                result = true
                pathThatWasTouched = path
                return result
            }
        }
        return result
    }
    
    
    func midPoint(_ p0:CGPoint,p1:CGPoint)->CGPoint
    {
        let x=(p0.x+p1.x)/2
        let y=(p0.y+p1.y)/2
        return CGPoint(x: x, y: y)
    }
    
    func newPathStart ( _ firstPoint : CGPoint ) {
        let path = UIBezierPath()
        currentPath = path
        currentPath.move(to: firstPoint)
        paths.append(currentPath)
        self.setNeedsDisplay()
    }
    
    
    
    //Allows gesture recognizers to fire outside parent views
    // https://github.com/mattneub/Programming-iOS-Book-Examples/blob/master/bk2ch05p210hitTesting/ch18p551hitTesting/ViewController.swift
    override func hitTest(_ point: CGPoint, with e: UIEvent?) -> UIView? {
        if let result = super.hitTest(point, with:e) {
            return result
        }
        //for sub in self.subviews.reverse() as! [UIView] {
        for sub in self.subviews.reversed()  {
            let pt = self.convert(point, to:sub)
            if let result = sub.hitTest(pt, with:e) {
                return result
            }
        }
        return nil
    }
    
    
    
    func clone() -> LeanBCurveView {
        //let logFor = MyLog()
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        let newObj = NSKeyedUnarchiver.unarchiveObject(with: data) as! LeanBCurveView!
        //logFor.DLog("clone: self = \(self)")
        //logFor.DLog("clone:newObj = \(newObj)")
        return newObj!
    }
    
}  // end of class



// Not sure where to put this: Used for coding and saving and decoding and intiializing
extension UserDefaults {
    
    // Color:
    // https://stackoverflow.com/questions/1275662/saving-uicolor-to-and-loading-from-nsuserdefaults
    func colorForKey(_ key: String) -> UIColor? {
        var color: UIColor?
        if let colorData = data(forKey: key) {
            color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? UIColor
        }
        print("NSUserDefaults: decoding, colorForKey = \(color)")
        if (color == nil) {
            print("Setting to green")
            color = UIColor.green
        }
        return color
    }
    func encodeColor(_ color: UIColor?, forKey key: String) {
        var colorData: Data?
        print("NSUserDefaults: encoding color \(color)")
        if let color = color {
            colorData = NSKeyedArchiver.archivedData(withRootObject: color)
        }
        set(colorData, forKey: key)
    }
    
    
    // if we need it: array of custom objects:
    // https://stackoverflow.com/questions/3648558/save-and-restore-an-array-of-custom-objects
    
}
