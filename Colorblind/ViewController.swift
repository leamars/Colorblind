//
//  ViewController.swift
//  Colorblind
//
//  Created by Lea Marolt on 10/26/16.
//  Copyright © 2016 Lea Marolt Sonnenschein. All rights reserved.
//

// **********************************************************************************
// Source: http://web.archive.org/web/20081014161121/http://www.colorjack.com/labs/colormatrix/
// Note that this only *approximates* what a color blind is *supposed* to be seeing and may differ from the actual color that they see
// **********************************************************************************

// Camera icon from the Noun Project: https://thenounproject.com/term/retro-camera/697889/
// By Oliviu Stoian, RO

import UIKit
import Clarifai
import SnapKit

let clarifaiAppID = ""
let clarifaiAppSecret = ""

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var button: UIButton!
    var clarifaiApp: ClarifaiApp = ClarifaiApp()
    var imageView: UIImageView!
    var scrollView: UIScrollView = UIScrollView()
    var rightConstraint: NSLayoutConstraint = NSLayoutConstraint()
    var activityIndicator = UIActivityIndicatorView()
    
    var count = 0 {
        didSet {
            guard recognizedRGBs != nil else { return }
            let colorblindness = Colorblindness.colorblindnessForCount(count: count)
            visionLabel.text = " \(colorblindness.rawValue) "
            maskedRGBs = recognizedRGBs!.map { colorblindness.colorblindRGB(rgb: $0) }
        }
    }
    
    @IBOutlet weak var visionLabel: UILabel!
    
    var recognizedRGBs: [RGB]? {
        didSet {
            addColorCircles(forOriginalRgbs: true, rgbs: recognizedRGBs!, fadeIn: true)
        }
    }
    var maskedRGBs: [RGB]? {
        didSet {
            self.scrollView.subviews.forEach({ (subview) in
                subview.removeFromSuperview()
            })
            addColorCircles(forOriginalRgbs: true, rgbs: recognizedRGBs!, fadeIn: false)
            addColorCircles(forOriginalRgbs: false, rgbs: maskedRGBs!, fadeIn: true)
        }
    }
    
    var hexes: [String]? {
        didSet {
            guard let _hexes = hexes else { return }
            
            let rgbs = _hexes.map{ ColorHelper().convertHexToRGB(hex: $0) }
            recognizedRGBs = rgbs
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView = UIImageView()
        view.addSubview(imageView)
        view.sendSubview(toBack: imageView)
        
        view.addSubview(scrollView)
        
        scrollView.snp.makeConstraints { (make) in
            make.height.equalTo(250)
            make.bottom.left.right.equalTo(view)
        }
        
        activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
    
    }
    
    func addColorCircles(forOriginalRgbs areOriginal: Bool, rgbs: [RGB], fadeIn: Bool) {
        
        // original rgb circles kept on top
        // color blind ones on bottom
        
        for i in 0..<rgbs.count {
            let rgb = rgbs[i]
            let circle = UIView()
            
            scrollView.addSubview(circle)
            
            circle.snp.makeConstraints({ (make) in
                make.height.width.equalTo(100)
                if areOriginal {
                    make.top.equalTo(scrollView)
                } else {
                    make.top.equalTo(scrollView).offset(110)
                }
                make.left.equalTo((i*110)+20)
            })
            
            circle.backgroundColor = UIColor(red: rgb.r/255, green: rgb.g/255, blue: rgb.b/255, alpha: 1.0)
            
            let colorName: String = ColorHelper().rgbToHex(rgb: rgb)
            
            let label = UILabel()
            label.text = colorName
            label.textColor = UIColor.white
            label.textAlignment = .center
            
            circle.addSubview(label)
            
            if fadeIn {
                label.alpha = 0
                circle.alpha = 0
            } else {
                label.alpha = 1
                circle.alpha = 1
            }
            
            label.snp.makeConstraints({ (make) in
                make.edges.equalTo(circle)
            })
            
            UIView.animate(withDuration: 0.3, animations: {
                circle.alpha = 1
                label.alpha = 1
                self.forwardButton.alpha = 1
                self.backButton.alpha = 1
                self.visionLabel.alpha = 1
            })
            
            if i == rgbs.count - 1 {
                scrollView.contentSize = CGSize(width: ((i*110)+140), height: 250)
            }
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func clarifai(_ sender: AnyObject) {
        let picker = UIImagePickerController()
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        #else
            picker.sourceType = UIImagePickerControllerSourceType.camera
        #endif
        picker.allowsEditing = false
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    func recognize(image: UIImage) {
        
        clarifaiApp = ClarifaiApp(appID: clarifaiAppID, appSecret: clarifaiAppSecret)
        
        clarifaiApp.getModelByName("general-v1.3") { (model, error) in
            let clarifaiImage = ClarifaiImage(image: image)
            
            self.clarifaiApp.searchForModel(byName: "color", modelType: .color, completion: { (models, error) in
                if let _models = models {
                    if let _clarifaiImage = clarifaiImage {
                        _models[0].predict(on: [_clarifaiImage], completion: { (outputs, error) in
                            let hexes = outputs?.first?.colors.map({ (concept) -> String in
                                if let fullHexString = concept.conceptName {
                                    let hexString = ColorHelper().createSubstring(with: fullHexString, from: 1, to: fullHexString.characters.count)
                                    return hexString
                                } else {
                                    return ""
                                }
                            })
                            
                            if let _hexes = hexes {
                                DispatchQueue.main.async( execute: {
                                    
                                    self.hexes = _hexes
                                })
                            }
                            
                        })
                    }
                }
            })
        }
    }
    
    //MARK: Image Picker Controller Delegate
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        
        count = 0
        
        self.scrollView.subviews.forEach({ (subview) in
            subview.removeFromSuperview()
        })
        
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.imageView.image = image
            self.imageView.snp.removeConstraints()
            
            self.imageView.snp.makeConstraints({ (make) in
                let viewHeight = view.frame.size.height
                let quotient = image.size.height/viewHeight
                let width = image.size.width/quotient
                
                make.center.equalTo(view)
                make.height.equalTo(viewHeight)
                make.width.equalTo(width)
            })
            recognize(image: image)
        }
    }
    @IBAction func forward(_ sender: AnyObject) {
        count = count+1
        if count > 8 {
            count = 0
        }
    }

    @IBAction func reverse(_ sender: AnyObject) {
        count = count-1
        if count < 0 {
            count = 8
        }
    }
}

