//
//  ARWorld.swift
//  ARWorld
//
//  Created by Ian Starnes on 8/21/17.
//  Copyright © 2017 311Labs LLC. All rights reserved.
//

import UIKit
import SceneKit 
import MapKit

class ViewController: UIViewController, MKMapViewDelegate, SceneLocationViewDelegate {
    let sceneLocationView = SceneLocationView()
    
    let mapView = MKMapView()
    var userAnnotation: MKPointAnnotation?
    var locationEstimateAnnotation: MKPointAnnotation?
    var username: String?
    var arworld: ARWorldSession?
    var refreshTimer = Stopwatch()
    
    var updateUserLocationTimer: Timer?
    
    ///Whether to show a map view
    ///The initial value is respected
    var showMapView: Bool = true
    
    var centerMapOnUserLocation: Bool = true
    
    ///Whether to display some debugging data
    ///This currently displays the coordinate of the best location estimate
    ///The initial value is respected
    var displayDebugging = false
    
    var infoLabel = UILabel()
    var titleLabel = UILabel()
    var addButton = UIButton()
    
    var arworldObjects = [Int:LocationNode]()
    
    var updateInfoLabelTimer: Timer?
    
    var adjustNorthByTappingSidesOfScreen = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let defaults = UserDefaults.standard
        self.username = defaults.string(forKey: "username")
        
//        addButton.backgroundColor =
        addButton.setImage(UIImage(named: "add")!, for: UIControlState.normal)
//        addButton.setTitle("Test Button", for: .normal)
        addButton.addTarget(self, action: #selector(addClicked), for: .touchUpInside)
        sceneLocationView.addSubview(addButton)
        
        titleLabel.font = UIFont.systemFont(ofSize: 20)
        titleLabel.text = UIDevice.current.identifierForVendor!.uuidString
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor.red
        titleLabel.numberOfLines = 0
//        let views = ["textLabel" : titleLabel]
//        let formatString = "|-[textLabel]-|"
//
//        let constraints = NSLayoutConstraint.constraints(withVisualFormat: formatString, options:.alignAllTop , metrics: nil, views: views)
//
//        NSLayoutConstraint.activate(constraints)
        sceneLocationView.addSubview(titleLabel)
        
        infoLabel.font = UIFont.systemFont(ofSize: 10)
        infoLabel.textAlignment = .left
        infoLabel.textColor = UIColor.white
        infoLabel.numberOfLines = 0
        sceneLocationView.addSubview(infoLabel)
        
        updateInfoLabelTimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(ViewController.updateInfoLabel),
            userInfo: nil,
            repeats: true)
        
        //Set to true to display an arrow which points north.
        //Checkout the comments in the property description and on the readme on this.
//        sceneLocationView.orientToTrueNorth = false
//        sceneLocationView.locationEstimateMethod = .coreLocationDataOnly
        sceneLocationView.showAxesNode = false
        sceneLocationView.locationDelegate = self
        
        if displayDebugging {
            sceneLocationView.showFeaturePoints = true
        }
        
        //Currently set to Canary Wharf
        // 117.606163
//        let pinCoordinate = CLLocationCoordinate2D(latitude: 33.455489, longitude: -117.606163)
//        let pinLocation = CLLocation(coordinate: pinCoordinate, altitude: 236)
//        let pinImage = UIImage(named: "pin")!
//        let pinLocationNode = LocationAnnotationNode(location: pinLocation, image: pinImage)
//        sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: pinLocationNode)
//
        
//        sceneLocationView.addLocationNodeForCurrentPosition(locationNode: <#T##LocationNode#>)
        
        view.addSubview(sceneLocationView)
        
        if showMapView {
            mapView.delegate = self
            mapView.showsUserLocation = true
            mapView.alpha = 0.8
            view.addSubview(mapView)
            
            updateUserLocationTimer = Timer.scheduledTimer(
                timeInterval: 0.5,
                target: self,
                selector: #selector(ViewController.updateUserLocation),
                userInfo: nil,
                repeats: true)
        }
        
    }
    
    @objc func addClicked() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Space Ship", style: .default) { _ in
           self.addShip()
        })
        
        alert.addAction(UIAlertAction(title: "Cup", style: .default) { _ in
            self.addCup()
        })
        
        alert.addAction(UIAlertAction(title: "Chair", style: .default) { _ in
            self.addChair()
        })
        
        alert.addAction(UIAlertAction(title: "Pin", style: .default) { _ in
            self.addPin()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default) { _ in

        })
        
        self.present(alert, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        DDLogDebug("run")
        sceneLocationView.run()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
//        DDLogDebug("pause")
        // Pause the view's session
        sceneLocationView.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if (self.username == nil) {
            self.showInputDialog()
        } else {
            self.fetchARWorld()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        sceneLocationView.frame = CGRect(
            x: 0,
            y: 0,
            width: self.view.frame.size.width,
            height: self.view.frame.size.height)
        
        infoLabel.frame = CGRect(x: 6, y: 0, width: self.view.frame.size.width - 12, height: 14 * 4)
        addButton.frame = CGRect(x: self.view.frame.size.width - 60, y: 0, width: 48, height: 48)
        
        if showMapView {
            infoLabel.frame.origin.y = (self.view.frame.size.height / 2) - infoLabel.frame.size.height
            addButton.frame.origin.y = (self.view.frame.size.height / 2) - infoLabel.frame.size.height
        } else {
            infoLabel.frame.origin.y = self.view.frame.size.height - infoLabel.frame.size.height
            addButton.frame.origin.y = self.view.frame.size.height - 60
        }
        
        titleLabel.frame = CGRect(x: 0, y: 15, width: self.view.frame.size.width, height: 20)
        
        mapView.frame = CGRect(
            x: 0,
            y: self.view.frame.size.height / 2,
            width: self.view.frame.size.width,
            height: self.view.frame.size.height / 2)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    @objc func updateUserLocation() {
        if let currentLocation = sceneLocationView.currentLocation() {
            DispatchQueue.main.async {
                
                self.refreshARWorld(currentLocation)
                
                if let bestEstimate = self.sceneLocationView.bestLocationEstimate(),
                    let position = self.sceneLocationView.currentScenePosition() {
//                    DDLogDebug("")
//                    DDLogDebug("Fetch current location")
//                    DDLogDebug("best location estimate, position: \(bestEstimate.position), location: \(bestEstimate.location.coordinate), accuracy: \(bestEstimate.location.horizontalAccuracy), date: \(bestEstimate.location.timestamp)")
//                    DDLogDebug("current position: \(position)")
                    
                    _ = bestEstimate.translatedLocation(to: position)
                    
//                    DDLogDebug("translation: \(translation)")
//                    DDLogDebug("translated location: \(currentLocation)")
//                    DDLogDebug("")
                }
                
                if self.userAnnotation == nil {
                    self.userAnnotation = MKPointAnnotation()
                    self.mapView.addAnnotation(self.userAnnotation!)
                }
                
                UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: {
                    self.userAnnotation?.coordinate = currentLocation.coordinate
                }, completion: nil)
            
                if self.centerMapOnUserLocation {
                    UIView.animate(withDuration: 0.45, delay: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: {
                        self.mapView.setCenter(self.userAnnotation!.coordinate, animated: false)
                    }, completion: {
                        _ in
                        self.mapView.region.span = MKCoordinateSpan(latitudeDelta: 0.0005, longitudeDelta: 0.0005)
                    })
                }
                
                if self.displayDebugging {
                    let bestLocationEstimate = self.sceneLocationView.bestLocationEstimate()
                    
                    if bestLocationEstimate != nil {
                        if self.locationEstimateAnnotation == nil {
                            self.locationEstimateAnnotation = MKPointAnnotation()
                            self.mapView.addAnnotation(self.locationEstimateAnnotation!)
                        }
                        
                        self.locationEstimateAnnotation!.coordinate = bestLocationEstimate!.location.coordinate
                    } else {
                        if self.locationEstimateAnnotation != nil {
                            self.mapView.removeAnnotation(self.locationEstimateAnnotation!)
                            self.locationEstimateAnnotation = nil
                        }
                    }
                }
            }
        }
    }
    
    @objc func updateInfoLabel() {
        let loc = sceneLocationView.currentLocation()
        self.refreshARWorld(loc!)
        
        if let position = sceneLocationView.currentScenePosition() {
            infoLabel.text = "x: \(String(format: "%.2f", position.x)), y: \(String(format: "%.2f", position.y)), z: \(String(format: "%.2f", position.z))\n"
        }
        
        if let eulerAngles = sceneLocationView.currentEulerAngles() {
            infoLabel.text!.append("Euler x: \(String(format: "%.2f", eulerAngles.x)), y: \(String(format: "%.2f", eulerAngles.y)), z: \(String(format: "%.2f", eulerAngles.z))\n")
        }
        
        if let heading = sceneLocationView.locationManager.heading,
            let accuracy = sceneLocationView.locationManager.headingAccuracy {
            infoLabel.text!.append("Heading: \(heading)º, accuracy: \(Int(round(accuracy)))º\n")
            
            if (showMapView) {
                mapView.camera.heading = heading
                mapView.setCamera(mapView.camera, animated: true)
            }
        }
        
        let date = Date()
        let comp = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        
        let count = arworldObjects.count
        if let hour = comp.hour, let minute = comp.minute, let second = comp.second, let nanosecond = comp.nanosecond {
            infoLabel.text!.append("\(String(format: "%02d", hour)):\(String(format: "%02d", minute)):\(String(format: "%02d", second)):\(String(format: "%03d", nanosecond / 1000000))")
        }
        
        infoLabel.text!.append("  ar objects: \(count)")
        let accuracy = loc?.horizontalAccuracy
        infoLabel.text!.append("  accuracy: \(String(format: "%.2f", accuracy!))")
    }
    
    //MARK: Add ARs
    
    func saveToCloud(_ model: String, _ node: LocationNode, _ kind: Int) {
        // now save object to ARWorld
        self.arworld?.addObject(data: [
            "model": model,
            "kind": kind,
            "alt":node.location.altitude,
            "lat":node.location.coordinate.latitude,
            "lng":node.location.coordinate.longitude
        ]) { status, response in
            
        }
    }
    
    func addPin() {
        let image = UIImage(named: "pin")!
        let annotationNode = LocationAnnotationNode(location: nil, image: image)
        annotationNode.scaleRelativeToDistance = true
        sceneLocationView.addLocationNodeForCurrentPosition(locationNode: annotationNode)
        
        self.saveToCloud("pin", annotationNode, 5)
    }
    
    func addShip() {
        let scene = SCNScene(named: "ship.scn", inDirectory:"Models.scnassets/spaceship")!
        let rootNode = LocationNode(location: nil)
        let node = scene.rootNode.childNode(withName: "ship", recursively: true)!
        
        //rootNode.scaleRelativeToDistance = true
        rootNode.addChildNode(node)
        sceneLocationView.addLocationNodeInFront(locationNode: rootNode)
        
        self.saveToCloud("spaceship", rootNode, 0)

    }
    
    func addCup() {
        let scene = SCNScene(named: "cup.scn", inDirectory:"Models.scnassets/cup")!
        let rootNode = LocationNode(location: nil)
        let node = scene.rootNode.childNode(withName: "cup", recursively: true)!
        
        //rootNode.scaleRelativeToDistance = true
        rootNode.addChildNode(node)
        sceneLocationView.addLocationNodeInFront(locationNode: rootNode)
        self.saveToCloud("cup", rootNode, 0)
    }
    
    func addChair() {
        let scene = SCNScene(named: "chair.scn", inDirectory:"Models.scnassets/chair")!
        let rootNode = LocationNode(location: nil)
        let node = scene.rootNode.childNode(withName: "chair", recursively: true)!
        
        //rootNode.scaleRelativeToDistance = true
        rootNode.addChildNode(node)
        sceneLocationView.addLocationNodeInFront(locationNode: rootNode)
        self.saveToCloud("chair", rootNode, 0)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            if touch.view != nil {
                if (mapView == touch.view! ||
                    mapView.recursiveSubviews().contains(touch.view!)) {
                    centerMapOnUserLocation = false
                } else {
                    
                    let location = touch.location(in: self.view)

                    if location.x <= 40 && adjustNorthByTappingSidesOfScreen {
                        print("left side of the screen")
                        sceneLocationView.moveSceneHeadingAntiClockwise()
                    } else if location.x >= view.frame.size.width - 40 && adjustNorthByTappingSidesOfScreen {
                        print("right side of the screen")
                        sceneLocationView.moveSceneHeadingClockwise()
                    } else {
//                        self.addShip()
//                        let image = UIImage(named: "pin")!
//                        let annotationNode = LocationAnnotationNode(location: nil, image: image)
//                        annotationNode.scaleRelativeToDistance = true
//                        sceneLocationView.addLocationNodeForCurrentPosition(locationNode: annotationNode)
                    }
                }
            }
        }
    }
    
    //MARK: MKMapViewDelegate
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        if let pointAnnotation = annotation as? MKPointAnnotation {
            let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            
            if pointAnnotation == self.userAnnotation {
                marker.displayPriority = .required
                marker.glyphImage = UIImage(named: "user")
            } else {
                marker.displayPriority = .required
                marker.markerTintColor = UIColor(hue: 0.267, saturation: 0.67, brightness: 0.77, alpha: 1.0)
                marker.glyphImage = UIImage(named: "compass")
            }
            
            return marker
        }
        
        return nil
    }
    
    //MARK: SceneLocationViewDelegate
    
    func sceneLocationViewDidAddSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
//        DDLogDebug("add scene location estimate, position: \(position), location: \(location.coordinate), accuracy: \(location.horizontalAccuracy), date: \(location.timestamp)")
    }
    
    func sceneLocationViewDidRemoveSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
//        DDLogDebug("remove scene location estimate, position: \(position), location: \(location.coordinate), accuracy: \(location.horizontalAccuracy), date: \(location.timestamp)")
    }
    
    func sceneLocationViewDidConfirmLocationOfNode(sceneLocationView: SceneLocationView, node: LocationNode) {
    }
    
    func sceneLocationViewDidSetupSceneNode(sceneLocationView: SceneLocationView, sceneNode: SCNNode) {
        
    }
    
    func sceneLocationViewDidUpdateLocationAndScaleOfLocationNode(sceneLocationView: SceneLocationView, locationNode: LocationNode) {
        
    }
    
    func refreshARWorld(_ location: CLLocation) {
        var do_refresh = false
        
        if self.refreshTimer.is_running == false {
            do_refresh = true
            self.refreshTimer.start()
        } else {
            if self.refreshTimer.durationSeconds() > 30.0 {
                do_refresh = true
                self.refreshTimer.reset()
            }
        }
        
        if (do_refresh) {
            arworld?.fetchObjects(lat: location.coordinate.latitude, lng: location.coordinate.longitude, alt:location.altitude) { status, response in
                DispatchQueue.main.async {
                    for case let item as Dictionary<String, Any> in response {
                        if let mid = item["id"] as? Int {
                            if self.arworldObjects[mid] == nil {
                                let kind = item["kind"] as? Int
                                if (kind == 0) {
                                    self.addARWorldModel(item)
                                } else {
                                    self.addARWorldPin(item)
                                }
                                
                            }
                        }
                    }
                }
            }
        }

    }
    
    func addARWorldPin(_ model: Dictionary<String, Any>) {
        let mid = model["id"] as? Int
        let model_name = model["model"] as? String
        let lat = model["lat"] as? Double
        let lng = model["lng"] as? Double
        let alt = model["alt"] as? Double
        
        let coordinate = CLLocationCoordinate2D(
            latitude: lat!,
            longitude: lng!)
        
        //        let location = sceneLocationView.currentLocation()
        let location = CLLocation(coordinate: coordinate, altitude: alt!)
        
        let image = UIImage(named: model_name!)!
        let annotationNode = LocationAnnotationNode(location: location, image: image)
        annotationNode.scaleRelativeToDistance = true
        sceneLocationView.addLocationNodeForCurrentPosition(locationNode: annotationNode)
        
        self.arworldObjects[mid!] = annotationNode
    }
    
    func addARWorldModel(_ model: Dictionary<String, Any>) {
        let mid = model["id"] as? Int
        let model_name = model["model"] as? String
        let lat = model["lat"] as? Double
        let lng = model["lng"] as? Double
        let alt = model["alt"] as? Double
        var fname = "ship.scn"
        var path = "Models.scnassets/spaceship"
        var name = "ship"
        
        switch(model_name) {
        case "spaceship"?:
            name = "ship"
            break
        case "lamp"?:
            name = "lamp"
            fname = "\(name).scn"
            path = "Models.scnassets/\(name)"
            break
        case "cup"?:
            name = "cup"
            fname = "\(name).scn"
            path = "Models.scnassets/\(name)"
            break
        case "chair"?:
            name = "chair"
            fname = "\(name).scn"
            path = "Models.scnassets/\(name)"
            break
        case .none:
            
            break
        case .some(_):
            
            break
        }
        
        let coordinate = CLLocationCoordinate2D(
            latitude: lat!,
            longitude: lng!)
        
//        let location = sceneLocationView.currentLocation()
        let location = CLLocation(coordinate: coordinate, altitude: alt!)
        let scene = SCNScene(named: fname, inDirectory:path)!
        let rootNode = LocationNode(location: location)
        let node = scene.rootNode.childNode(withName: name, recursively: true)!
        self.arworldObjects[mid!] = rootNode
        rootNode.addChildNode(node)
        sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: rootNode)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        rootNode.annotation  = annotation
        self.mapView.addAnnotation(annotation)
    }
    
    func fetchARWorld() {
        self.titleLabel.text = self.username
        if self.arworld == nil {
            self.arworld = ARWorldSession(username: self.username!)
        }
        

    }
    
    func showInputDialog() {
        //Creating UIAlertController and
        //Setting title and message for the alert dialog
        let alertController = UIAlertController(title: "Credentials", message: "Enter your username", preferredStyle: .alert)
        
        //the confirm action taking the inputs
        let confirmAction = UIAlertAction(title: "Enter", style: .default) { (_) in
            
            //getting the input values from user
            let name = alertController.textFields?[0].text
//            let email = alertController.textFields?[1].text
            
            //            self.labelMessage.text = "Name: " + name! + "Email: " + email!
            self.username = name
            let defaults = UserDefaults.standard
            defaults.set(name, forKey: "username")
            self.fetchARWorld()
        }
        
        //the cancel action doing nothing
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        
        //adding textfields to our dialog box
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter Username"
        }
//        alertController.addTextField { (textField) in
//            textField.placeholder = "Enter Email"
//        }
        
        //adding the action to dialogbox
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        //finally presenting the dialog box
        self.present(alertController, animated: true, completion: nil)
        
    }
}

extension DispatchQueue {
    func asyncAfter(timeInterval: TimeInterval, execute: @escaping () -> Void) {
        self.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(timeInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: execute)
    }
}

extension UIView {
    func recursiveSubviews() -> [UIView] {
        var recursiveSubviews = self.subviews
        
        for subview in subviews {
            recursiveSubviews.append(contentsOf: subview.recursiveSubviews())
        }
        
        return recursiveSubviews
    }
}

