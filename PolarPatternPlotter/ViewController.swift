//
//  ViewController.swift
//  PolarPatternPlotter
//
//  Created by Scott Hawley on 5/6/16.
//  Copyright © 2016 Scott Hawley. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import CoreAudio
import CoreLocation


class ViewController: UIViewController, CLLocationManagerDelegate, AVAudioRecorderDelegate {
    
    
    // user interface objects
    @IBOutlet var MainView: UIView!
    @IBOutlet weak var GraphView: UIView!
    @IBOutlet weak var SoundLevelLabel: UILabel!
    //@IBOutlet weak var HeadingLabel: UILabel!
    @IBOutlet weak var StartButton: UIButton!
    @IBOutlet weak var ClearButton: UIButton!
    @IBOutlet weak var SizeLabel: UILabel!
    @IBOutlet weak var SizeSlider: UISlider!

    @IBOutlet weak var DriftCalLabel: UILabel!
    @IBOutlet weak var DriftCalSlider: UISlider!
    @IBOutlet weak var SoundCalSlider: UISlider!
    @IBOutlet weak var HeadingSelector: UISegmentedControl!
    @IBOutlet weak var VUBarImageView: UIImageView!
    
    
    @IBOutlet var pinchGesture: UIPinchGestureRecognizer!
    @IBOutlet var panGesture: UIPanGestureRecognizer!
    
    @IBOutlet var rotateGesture: UIRotationGestureRecognizer!
    
    // direction objects
    var locationManager:CLLocationManager!
    var compassHeading = Float(0.0)
    var gyroRadians = 0.0
    var accelRadians = 0.0
    
    // Normalization
    var startAngle = Float(0.0)
    var startLevel = Float(0.0)

    // motion
    let motionKit = MotionKit()
    
    // audio objects
    var audioRecorder: AVAudioRecorder!
    var levelTimer = Timer()
    var lowPassResults: Double = 0.0
    var refreshRate = 0.02   // seconds
    
    // graph-drawing variables
    var currentBCurveView : LeanBCurveView!
    var currentPoint : CGPoint!
    var gyro_currentPoint : CGPoint!
    var accel_currentPoint : CGPoint!
    var newPath:Bool = true
    var tickMarkView: TickMarkView!
    let radMax = Float(120)   // maximum radius
    var dbMin = Float(-33)    // Value at origin, i.e. zero radius
    
    
    // dynamic cover for VU Meter
    var VUBarCover : UIView!
    
    // storage for re-graphing
    var headingsArray = [Float]()
    var levelsArray = [Float]()
    var headings_ArrayOfArrays = [[Float]]()
    var levels_ArrayOfArrays = [[Float]]()
    
    // buffers for smoothing graphs
    var startCounter = 0;
    let bufferSize = 3 //10
    var dirBuffer:RingBuffer!    // in radians
    var soundBuffer:RingBuffer!
    
    // to help compensate for angular drift & counterrotation error
    var oldAppAngle = Float(0.0)     // angle used by app
    var oldMKAngle = Float(0.0)     // angle returnd by MotionKit
    var oldAngleDiff = Float(0.0)
    
    // data dump
    var dataStringCSV = ""
    
    
    // var debug step
    let debugStep = 4
    
    
    // for screenshots for iTunes store
    let fakeIt = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Do any additional setup after loading the view, typically from a nib
        
        // Set up UI stuff
        StartButton.setTitle("Start", for: UIControlState())
        StartButton.setTitle("Stop", for: UIControlState.selected)
        GraphView.frame = MainView.bounds
        
        tickMarkView = TickMarkView(frame: GraphView.bounds)
        tickMarkView.isUserInteractionEnabled = false
        MainView.addSubview(tickMarkView)
        tickMarkView.frame = MainView.bounds
        tickMarkView.update(1.0)
        
        //SoundLevelLabel.text = "Sound Level:"
        SizeLabel.text = "dbMin: "+String.localizedStringWithFormat("%.0f", SizeSlider.value)+"dB"
        
        
        // add VUBarCover
        VUBarCover = UIView()
        VUBarCover.backgroundColor = UIColor.black
        
        
        // Set up smoothing-buffer stuff
        dirBuffer = RingBuffer(length: bufferSize, angular: true)
        soundBuffer = RingBuffer(length: bufferSize, angular: false)
        
        // Set up heading stuff
        locationManager  = CLLocationManager()
        locationManager.delegate = self
        locationManager.startUpdatingHeading()
        
        // Set up audio stuff
        initalizeRecorder()
        startRecording()

        
        // set random number gen (for colors)
        srand48(1)
        
    }

    var firstSetup = true
    // this gets called after AutoLayout is finished
    override func viewDidLayoutSubviews() {
        //super.viewDidLayoutSubviews()
        
        //print(" in viewDidLayoutSubviews, firstSetup = ",firstSetup)

        if (firstSetup) {
            // cover up VU Meter completely
            VUBarCover.frame = VUBarImageView.frame
            MainView.addSubview(VUBarCover)
            VUBarCover.backgroundColor = UIColor.black
            firstSetup = false
            MainView.sendSubview(toBack: VUBarCover)
            MainView.sendSubview(toBack: VUBarImageView)
        }
    }
    
 
    @IBAction func StartButtonPress(_ sender: AnyObject) {
        StartButton.isSelected = !StartButton.isSelected
        
        if (true == StartButton.isSelected) { //Start button is pressed; Recording
            
            headingsArray.removeAll()
            levelsArray.removeAll()
            if (0==headings_ArrayOfArrays.count) {  //overwrite data file
                dataStringCSV = ""
                writeToDocumentsFile("data.csv", value: "")
            }

            dataStringCSV += "dB, Compass, Gyro, Accel\r\n"

            //startRecording(sender)
            
            compassHeading = 0.0
            setupNewBCurveView()
            
        } else {  // stop button pressed
            stopRecording(sender)
            
            //turn off motionkit
            motionKit.stopAccelerometerUpdates()
            motionKit.stopGyroUpdates()
            motionKit.stopDeviceMotionUpdates()
            motionKit.stopmagnetometerUpdates()
            
            //save datastring
            dataStringCSV += "\r\n"
            writeToDocumentsFile("data.csv", value: dataStringCSV)
            //appendToFile("data.csv", text: dataStringCSV+"\r\n")

            headings_ArrayOfArrays.append(headingsArray)
            levels_ArrayOfArrays.append(levelsArray)
        }
    }
    
    
    @IBAction func ClearButtonPress(_ sender: AnyObject) {
        for view in GraphView.subviews {
            if (view is LeanBCurveView) {
                view.removeFromSuperview()
            }
        }
        dataStringCSV = ""
        startLevel = 0.0
        startAngle = 0.0
        oldAppAngle = startAngle
        oldMKAngle = oldAppAngle
        headings_ArrayOfArrays.removeAll()
        levels_ArrayOfArrays.removeAll()
        writeToDocumentsFile("data.csv", value: "")

        // btnStopPress(sender)
        
    }
    
    
    @IBAction func DriftCalSliderChanged(_ sender: AnyObject) {
        DriftCalLabel.text = "Drift Cal: "+String.localizedStringWithFormat("%.2f", DriftCalSlider.value)
        redrawGraph()
    }
    
    @IBAction func SizeSliderChanged(_ sender: AnyObject) {
        //tickMarkView.update(SizeSlider.value)
        SizeLabel.text = "dbMin: "+String.localizedStringWithFormat("%.0f", SizeSlider.value)+"dB"
        redrawGraph()
    }
    
   
    @IBAction func pinchAction(_ sender: UIPinchGestureRecognizer) {
        // print("Pinching...")
        if let view =  sender.view {
            if (view == GraphView) {
                
                //following code scales from center of pinch
                //var anchor = recognizer.locationInView(view)
                //following code scales from center of screen
                var anchor = view.center
                //print("anchor = ",anchor)
                //print("view.bounds = ",view.bounds)
                //print("view.frame = ",view.frame)
                let offset = CGPoint(x: 0, y:0) //corrects for misalignment
                anchor.x += offset.x
                anchor.y += offset.y
                anchor = CGPoint(x: anchor.x - view.bounds.size.width/2, y: anchor.y-view.bounds.size.height/2);
                var affineMatrix = view.transform
                affineMatrix = affineMatrix.translatedBy(x: anchor.x, y: anchor.y)
                affineMatrix = affineMatrix.scaledBy(x: sender.scale, y: sender.scale)
                affineMatrix = affineMatrix.translatedBy(x: -anchor.x, y: -anchor.y)
                view.transform = affineMatrix
                sender.scale = 1
            }
        }
    }
    
    
    // single-finger rotation
    var startRotAngle:Float = 0.0
    @IBAction func panAction(_ sender:UIPanGestureRecognizer) {
        //print("    Panning...")
        if let view =  sender.view {
            if (view == GraphView) {
                if (sender.state == .began) {
                    //print ("      pan began")
                    let dx:Float  = Float(sender.location(in: view).x - view.center.x)
                    let dy:Float = Float(sender.location(in: view).y - view.center.y)
                    startRotAngle = atan2f(dy,dx)
                    
                }
                else if (sender.state == .changed) {
                    //print ("         pan changed")
                    let dx:Float  = Float(sender.location(in: view).x - view.center.x)
                    let dy:Float = Float(sender.location(in: view).y - view.center.y)
                    let newRotAngle = atan2f(dy,dx)
                    let dTheta = CGFloat(newRotAngle - startRotAngle)
                    
                    let offset = CGPoint(x: -2, y: 0) //correct for misalignment
                    var affineMatrix = view.transform
                    affineMatrix = affineMatrix.translatedBy(x: offset.x, y: offset.y)
                    affineMatrix = affineMatrix.rotated(by: dTheta)
                    affineMatrix = affineMatrix.translatedBy(x: -offset.x, y: -offset.y)
                    view.transform = affineMatrix
                    
                }
            }
        }
        sender.setTranslation(CGPoint.zero, in: self.view)
        
    }
    
    
    @IBAction func rotateAction(_ sender : UIRotationGestureRecognizer) {
        return Void() //disable rotation
            
        print("            Rotating")
        if let view =  sender.view {
            if (view == GraphView) {
            }
            
        }
    }
    
    
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        // This will print out the direction the device is heading
        //print(heading.magneticHeading)
        
        //HeadingLabel.text = "Heading: " + String(heading.magneticHeading)
        compassHeading = Float(heading.magneticHeading)
        //HeadingLabel.text = "Heading: "+String.localizedStringWithFormat("%.2f", compassHeading)+"°"
        //HeadingLabel.text = ""
        
        
        dirBuffer.addValue( compassHeading*Float(M_PI/180) )
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    
    
    func initalizeRecorder ()
    {
        do {
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
            try AVAudioSession.sharedInstance().setActive(true)
            
        }catch{
            print(error);
        }
        
        
       /* let stringDir:NSString = self.getDocumentsDirectory();
        let audioFilename = stringDir.stringByAppendingPathComponent("recording.m4a")
        print("File Path : \(audioFilename)");
        let audioURL = NSURL(fileURLWithPath: audioFilename)
        */
        let audioURL = URL(fileURLWithPath: "dev/null")
        
        
        // make a dictionary to hold the recording settings so we can instantiate our AVAudioRecorder
        
        /*let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderBitRateKey:12800 as NSNumber,
            AVLinearPCMBitDepthKey:16 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.High.rawValue
        ]*/
        let settings = [
            AVFormatIDKey: NSNumber(value: kAudioFormatAppleLossless as UInt32),
            AVEncoderAudioQualityKey : AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey : 320000,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey : 44100.0
        ] as [String : Any]
        
        
        
        do {
            if audioRecorder == nil
            {
                audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings )
                audioRecorder!.delegate = self
                audioRecorder!.prepareToRecord();
                audioRecorder!.isMeteringEnabled = true;
            }
            //audioRecorder!.recordForDuration(NSTimeInterval(60.0));
        } catch {
            print("Error")
        }
        
    }
    
    //GET DOCUMENT DIR PATH
    func getDocumentsDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    
    
    ////START RECORDING
    
    func startRecording() {
        
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            
            self.startCounter = 0
            recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                DispatchQueue.main.async {
                    if allowed {
                        self.initalizeRecorder ()
                        self.audioRecorder!.record()
                        //instantiate a timer to be called with whatever frequency we want to grab metering values
                        self.levelTimer = Timer.scheduledTimer(timeInterval: self.refreshRate, target: self, selector: #selector(ViewController.levelTimerCallback), userInfo: nil, repeats: true)
                        
                    } else {
                        print("Failed Permission Record!!")
                    }
                }
            }
        } catch {
            // failed to record!
            print("Failed Permission Record!!")
        }
        
    }
    
    
    //This selector/function is called every time our timer (levelTime) fires
    func levelTimerCallback() {
        //we have to update meters before we can get the metering values
        if audioRecorder != nil
        {
            audioRecorder!.updateMeters()
            

            // time delay to avoid low values at startup
                self.startCounter += 1
                if (startCounter < 5) && (!fakeIt) {
                    print("startCounter =",startCounter,", that's too low")
                    return
                }
            
            // attempted to calibrate iPhone5s to Extech HD600 SPL meter (C-weighted, slow)
            let calAdd = SoundCalSlider.value + Float(112.44)   // additive calibration value in dB
            let calMult = Float(1.5) // multiplicate calibration in dB
            
            let inputValue = audioRecorder!.averagePower(forChannel: 0)
            
            let reportValue = (calAdd +  calMult * inputValue )
            
            if ((false == StartButton.isSelected) || (startCounter % 10 == 0)) && (!fakeIt) {   //don't update the VU meter too frequently
                updateVUMeter(inputValue)
            }
            
            //let reportValue = audioRecorder!.averagePowerForChannel(0)

            if (reportValue > 40.0) {
                SoundLevelLabel.text = "Level: " + String.localizedStringWithFormat("%.1f", reportValue) + " dB"
            } else {
                SoundLevelLabel.text = "Level: <40dB"
            }
            soundBuffer.addValue(reportValue)
            
            if (StartButton.state == .selected) {
                updateGraph(reportValue)
            }
        }
        
        
    }
    //STOP RECORDING
    //@IBAction
    func stopRecording(_ sender: AnyObject) {
        return Void()
        
        if audioRecorder != nil
        {
            audioRecorder!.stop()
            self.levelTimer.invalidate()
            
            
        }
        
    }
    
    func createTickMarks() {
        
    }
    func updateTickMarks() {
        
    }
    
    // partially cover up VUBarImage with black VUBarCover coming from the "right"
    func updateVUMeter(_ inputValue:Float) {   //inputValue is in dB
        //iphone 5s sensitivity goes between -27dB and -0.2dB
        
        let val = inputValue / Float(-25.0)
        
        let fullWidth = VUBarImageView.frame.width
        let maxX = VUBarImageView.frame.maxX
        let width = fullWidth * CGFloat(val)
        let minX = maxX - width
        let minY = VUBarImageView.frame.minY
        let height = VUBarImageView.frame.height
        
        let newFrame = CGRect(x: minX,y: minY, width: width, height: height)
        VUBarCover.frame = newFrame
        VUBarCover.backgroundColor = UIColor.black
       
    }
    
    func updateGraph(_ soundLevel:Float) {
        
        var soundValue = soundBuffer.getAverage()
        let compassRadians = dirBuffer.getAverage()
       
       /*
            // gyro
            motionKit.getAttitudeFromDeviceMotion(0.01) {
                (attitude) -> () in
                let roll = attitude.roll
                let pitch = attitude.pitch
                let yaw = attitude.yaw
                let rotationMatrix = attitude.rotationMatrix
                let quaternion = attitude.quaternion
                
                print("roll, pitch, yaw = ",roll,pitch,yaw)
                self.gyroRadians = yaw
                self.accelRadians = roll
                //print("1. gyroRadians = ",self.gyroRadians)
            }
            
            //accelerometer
            motionKit.getAccelerationFromDeviceMotion(0.01){
                (x, y, z) -> () in
                // Grab the x, y and z values
                let rotation = atan2(x, y) - M_PI
            }

        */
        if (!fakeIt) {
            motionKit.getDeviceMotionObject(0.04){
                (deviceMotion) -> () in
                //let acceleration = deviceMotion.userAcceleration
                let acceleration = deviceMotion.gravity
                self.accelRadians = atan2(acceleration.x, acceleration.y) - M_PI
                //print("accleration = "+String(acceleration)+", accelRadians = "+String(self.accelRadians))
                self.gyroRadians = deviceMotion.attitude.yaw
            }
        }
       
        
        let selectedIndex = HeadingSelector.selectedSegmentIndex;
        //print ("selectedIndex ="+String(selectedIndex))

        var angle = Float(gyroRadians)
        if (0 == selectedIndex) {
            angle = compassRadians
        } else if (2 == selectedIndex) {
            angle = Float(accelRadians)
        }
        
        
        if (fakeIt) {
            let time = Float(startCounter) * 0.01
            angle = Float(time)
            
        }
        let MKAngle = angle
        
        // guard against suddent jumps
        if (fabsf(MKAngle - oldMKAngle) > 3) {  // typically jumps +/- Pi
            oldMKAngle = MKAngle            // turn off diff for this instant
        }
        
        if (newPath) {
            startAngle = angle
            oldAppAngle = startAngle
            oldMKAngle = oldAppAngle
            if (0==levels_ArrayOfArrays.count){ // don't reset startLevel for multiple traces on the same screen
                startLevel = soundValue
            }
        }
        
        let angleDiff = angle - oldMKAngle   // diff in MotionKit angle update
        oldAngleDiff = angleDiff
        oldMKAngle = angle
        
        // Update the angular origentation
        if (false) {     // TODO: Drift Correction disabled due to unfixed calc.
                        //      err involving updates.  Anyone wanna fix it?
            angle = angle - startAngle
        } else {
            let driftCalFactor =  DriftCalSlider.value
            let wouldBeDeg = (oldAppAngle + angleDiff)*360/3.14159
            angle = oldAppAngle + angleDiff * driftCalFactor
            print ("MKAngle = ",MKAngle,". angle would be = ",wouldBeDeg,", but with correction of ",driftCalFactor," it's ",angle*360/3.14159)
            oldAppAngle = angle
        }
        
        if (fakeIt) {
            soundValue = 60.0+15*(1.0+cos(angle) )
            updateVUMeter(soundValue-90)
            print("Faking it: angle = ",angle,", soundValue = ",soundValue)
            SoundLevelLabel.text = "Level: " + String.localizedStringWithFormat("%.1f", soundValue) + " dB"
        }
        
        
        
        let dbFS = soundValue - startLevel
        
        
        headingsArray.append(angle)
        levelsArray.append(dbFS)
    
        let dbMin = Float(SizeSlider.value)
        let radius = max(0.0,radMax + dbFS*radMax/(-dbMin))

       //print("startLevel = ",startLevel,"soundValue = ",soundValue,"dbFS = ",dbFS,", dbMin = ",dbMin,"radius = ",radius)
        
        //let radius = scale * 50*2*(1+cos(dirBuffer.getAverage())) //hard coded cardioid
        
        //let offset = CGPoint(x:-2, y:0)  // used to correct misalignment
        let offset = CGPoint(x:+4, y:0)  // used to correct misalignment

        

        
        currentPoint.x = offset.x + GraphView.center.x + CGFloat( Float(radius) * Float( sin(angle) ) )
        currentPoint.y = offset.y + GraphView.center.y - CGFloat( Float(radius) * Float( cos(angle) ) )
        
        if (newPath) {
            currentBCurveView.newPathStart(currentPoint)
            currentBCurveView.previousPoint = currentPoint
            newPath = false
        }
        
        // add to the dataString
        dataStringCSV += String(soundValue)+", "+String(compassRadians)+", "+String(gyroRadians)+", "+String(accelRadians)+"\r\n"
        
        
        let midPoint = currentBCurveView.midPoint(currentBCurveView.previousPoint, p1: currentPoint)
        currentBCurveView.currentPath.addQuadCurve(to: midPoint,controlPoint: currentBCurveView.previousPoint)
        
        currentBCurveView.previousPoint = currentPoint
        currentBCurveView.setNeedsDisplay()
        
    }
    
    
    func redrawGraph() {
        if (!headings_ArrayOfArrays.isEmpty) && (!levels_ArrayOfArrays.isEmpty) {
            
            // destroy previous graphs
            for view in GraphView.subviews {
                if (view is LeanBCurveView) {
                    view.removeFromSuperview()
                }
            }
            
            startLevel = levels_ArrayOfArrays.map({ $0.max()!}).max()!
            let dbMin = Float(SizeSlider.value)
            
            for i in 0 ..< headings_ArrayOfArrays.count {
                setupNewBCurveView()
                currentBCurveView.lineWidth = 2.0
                currentBCurveView.currentPath.lineWidth = 2.0

                newPath = true
                for j in 0 ..< headings_ArrayOfArrays[i].count {
                    
                    let angle = headings_ArrayOfArrays[i][j]
                    let dbFS = levels_ArrayOfArrays[i][j] - startLevel
                    
                    let radius = max(0.0,  radMax + dbFS*radMax/(-dbMin))
                    //print ("levels_ArrayOfArrays[i][j]=",levels_ArrayOfArrays[i][j] ,"startLevel = ",startLevel,"dbFS = ",dbFS,"radius = ",radius)
                    
                    let offset = CGPoint(x:+4, y:0)  // used to correct misalignment
                    currentPoint.x = offset.x + GraphView.center.x + CGFloat( Float(radius) * Float( sin(angle) ) )
                    currentPoint.y = offset.y + GraphView.center.y - CGFloat( Float(radius) * Float( cos(angle) ) )
                    
                    if (newPath) {
                        currentBCurveView.newPathStart(currentPoint)
                        currentBCurveView.previousPoint = currentPoint
                        newPath = false
                    }
                    let midPoint = currentBCurveView.midPoint(currentBCurveView.previousPoint, p1: currentPoint)
                    currentBCurveView.currentPath.addQuadCurve(to: midPoint,controlPoint: currentBCurveView.previousPoint)
                    currentBCurveView.previousPoint = currentPoint
                    //currentBCurveView.currentPath.lineWidth = 2
                    //currentBCurveView.setNeedsDisplay()
                    
                    currentBCurveView.currentPath.lineWidth = 2.0
                    
                }
            }

            
            
        } else {
            //print("Doing nothing")
        }
    }
    
    
    func setupNewBCurveView() {  // passedView becomes the parent to the new LeanBCurveView
        let view = GraphView
        
        
        newPath = true
        
        if (true)||(currentBCurveView == nil) || (currentBCurveView.paths.count > 0) { // don't cover a blank existing curve view, just use it
            
            let newBCurveView = LeanBCurveView(frame: GraphView.bounds)
            newBCurveView.lineWidth = 2.0
            //newBCurveView.center = view.center
            currentBCurveView = newBCurveView
        } else {
            // logFor.DLog("we are not instantiating a new curve view to go atop an empty one")
        }
        view?.addSubview(currentBCurveView)
        
        
        currentBCurveView.currentPath.lineWidth = 2.0 // 3
        
        
        currentPoint = GraphView.center
        //currentPoint.x -= 20000
        newPath = true
        
    }
    
    
    
    // file I/O:
    // from Samuel Allen's post in http://stackoverflow.com/questions/24097826/read-and-write-data-from-text-file
    func writeToDocumentsFile(_ fileName:String,value:String) {
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString!
        let path = documentsPath?.appendingPathComponent(fileName)
        
        do {
            try value.write(toFile: path!, atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print("ERROR : writing to file \(path) : \(error.localizedDescription)")
        }
    }
    
    func appendToFile(_ fileName:String,text:String){
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString!
        let path = documentsPath?.appendingPathComponent(fileName)
        
        let os: OutputStream = OutputStream(toFileAtPath: path!, append: true)!
        
        os.open()
        
        //let text = "\n\tmore"
        
        os.write(text, maxLength: text.lengthOfBytes(using: String.Encoding.utf8))
        
        os.close()
        
    }
    
    
    
    // Added: autorotation settings
    // as per https://stackoverflow.com/questions/25651969/setting-device-orientation-in-swift-ios/25653474#comment52194689_25653474
    override var shouldAutorotate : Bool {
        if (UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft ||
            UIDevice.current.orientation == UIDeviceOrientation.landscapeRight ||
            UIDevice.current.orientation == UIDeviceOrientation.unknown) {
            return false
        }
        else {
            return true
        }
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return [UIInterfaceOrientationMask.portrait ,UIInterfaceOrientationMask.portraitUpsideDown]
    }
    
}

