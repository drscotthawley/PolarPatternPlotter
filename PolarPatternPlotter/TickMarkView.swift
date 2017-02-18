//
//  TickMarkView.swift
//  PolarPatternPlotter
//
//  Created by Scott Hawley on 5/6/16.
//  Copyright © 2016 Scott Hawley. All rights reserved.
//

import UIKit

class TickMarkView: UIView {
    
    
    var paths = [UIBezierPath()]
    var currentPath = UIBezierPath()
    
    var previousPoint:CGPoint = CGPoint.zero
    var lineWidth:CGFloat = 2.0
    var lineColor:UIColor = UIColor.green
    var lineCapStyle:CGLineCap = CGLineCap.round
    var lineJoinStyle:CGLineJoin = CGLineJoin.round
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.superview?.sendSubview(toBack: self)
        self.backgroundColor = UIColor.clear
        //self.update(1.0)
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func clear() {
        if (nil != self.layer.sublayers) {
            for sublayer in self.layer.sublayers! {
                sublayer.removeFromSuperlayer()
            }
        }
    }
    
    let offset = CGPoint(x: 0,y: 0)  // used to correct AutoLayout misalignment
    func addCircle(_ radius: Float, scale: Float) {
        
        var start = self.center
        start.x += offset.x
        start.y += offset.y
        //print ("tickMarkView: self.superview.frame = ",self.superview!.frame,", self.superview.center=",self.superview!.center)
        
        //print ("tickMarkView: self.frame = ",self.frame,", self.center=",self.center)
        let circlePath = UIBezierPath(arcCenter: start, radius: CGFloat(radius*scale), startAngle: CGFloat(0), endAngle:CGFloat(M_PI * 2), clockwise: true)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.cgPath
        //change the fill color
        shapeLayer.fillColor = UIColor.clear.cgColor
        //you can change the stroke color
        shapeLayer.strokeColor = UIColor.white.cgColor
        //you can change the line width
        shapeLayer.lineWidth = 1.0
        shapeLayer.lineDashPattern = [1]
        self.layer.addSublayer(shapeLayer)
        
    }
    func addLine( _ length: Float, angle: Float, scale: Float) {
        // lines
        //design the path
        let path = UIBezierPath()
        var start = self.center
        start.x += offset.x
        start.y += offset.y
        let radians = angle * Float(M_PI / 180.0)
        let end = CGPoint( x: start.x + CGFloat(scale*length*sin(radians)), y: start.y - CGFloat(scale*length*cos(radians)))
        path.move(to: start)
        path.addLine(to: end)
        
        //design path in layer
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 1.0
        shapeLayer.lineDashPattern = [1]
        
        self.layer.addSublayer(shapeLayer)
    }
    
    func update(_ scale:Float) {
        
        self.clear()
        
        addCircle(30.0, scale: scale)
        addCircle(60.0, scale: scale)
        addCircle(90.0, scale: scale)
        addCircle(120.0, scale: scale)
        
        addLine( 140.0, angle: 0.0, scale: scale)
        addLine( 120.0, angle: 30.0, scale: scale)
        addLine( 120.0, angle: -30.0, scale: scale)
        addLine( 120.0, angle: 60.0, scale: scale)
        addLine( 120.0, angle: -60.0, scale: scale)
        addLine( 120.0, angle: 120.0, scale: scale)
        addLine( 120.0, angle: -120.0, scale: scale)
        addLine( 120.0, angle: 180.0, scale: scale)
        
        addLine( 140.0, angle: 90.0, scale: scale)
        addLine( 140.0, angle: -90.0, scale: scale)
        
    }
    
    
    
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
    
    
    
    
    
    
}  // end of class



