//
//  MAActivityIndicatorView.swift
//  fireshare
//
//  Created by Riyad Anabtawi on 3/22/16.
//  Copyright © 2016 Riyad Anabtawi. All rights reserved.
//

import UIKit


@objc protocol MAActivityIndicatorViewDelegate
{
    func activityIndicatorView(activityIndicatorView: MAActivityIndicatorView,
        circleBackgroundColorAtIndex index: NSInteger) -> UIColor
    
}

class MAActivityIndicatorView: UIView {
    
    
    // MARK: - Private properties
    
    
    /// The number of circle indicators.
    private var _numberOfCircles            = 5
    
    /// The base animation delay of each circle.
    private var delay                       = 0.2
    
    /// The base animation duration of each circle
    private var duration                    = 0.8
    
    /// Total animation duration
    private var _animationDuration:Double   = 2
    
    /// The spacing between circles.
    private var _internalSpacing:CGFloat    = 5
    
    /// The maximum radius of each circle.
    private var _maxRadius:CGFloat          = 10
    
    // The minimum radius of each circle
    private let minRadius:CGFloat           = 2
    
    /// Default color of each circle
    private var _defaultColor                        = UIColor.lightGray
    
    /// An indicator whether the activity indicator view is animating or not.
    private var isAnimating         = false
    
    
    // MARK: - Public properties
    
    /// Delegate, used to chose the color of each circle.
    var delegate:MAActivityIndicatorViewDelegate?
    
    //MARK: - Public computed properties
    
    /// The number of circle indicators.
    var numberOfCircles:Int {
        get {
            return _numberOfCircles
        }
        set {
            _numberOfCircles    = newValue
            delay               = 2*duration/Double(numberOfCircles)
            updateCircles()
        }
    }
    
    /// Default color of each circle
    var defaultColor:UIColor {
        get  {
            return _defaultColor
        }
        set {
            _defaultColor    = newValue
            updateCircles()
        }
    }
    
    /// Total animation duration
    var animationDuration:Double {
        get {
            return _animationDuration
        }
        set {
            _animationDuration  = newValue
            duration            = _animationDuration/2
            delay               = 2*duration/Double(numberOfCircles)
            updateCirclesanimations()
        }
        
    }
    
    /// The maximum radius of each circle.
    var maxRadius:CGFloat {
        get {
            return _maxRadius
        }
        set {
            _maxRadius = newValue
            if _maxRadius < minRadius {
                _maxRadius = minRadius
            }
            updateCircles()
        }
    }
    
    /// The spacing between circles.
    var internalSpacing:CGFloat {
        get {
            return _internalSpacing
        }
        set {
            _internalSpacing = newValue
            if (_internalSpacing * CGFloat(numberOfCircles-1) >  self.frame.width) {
                _internalSpacing = (self.frame.width - CGFloat(numberOfCircles) * minRadius) / CGFloat(numberOfCircles-1)
            }
            updateCircles()
        }
    }
    
    
    // MARK: - override
    
    convenience init () {
        self.init(frame:CGRect(x: 0, y: 0, width: 100, height: 50))
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDefaults()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    
    
    // MARK: - private methods
    
    // Sets up defaults values
    private func setupDefaults() {
        numberOfCircles         = 5
        internalSpacing         = 5
        maxRadius               = 10
        animationDuration       = 2
        defaultColor            = UIColor.lightGray
        
    }
    
    /// Creates the circle view.
    ///
    /// - parameter radius: The radius of the circle.
    /// - parameter color: The background color of the circle.
    /// - parameter positionX: The x-position of the circle in the contentView.
    /// - parameter posX: The x-position of the circle in the contentView.
    /// - parameter posY: The y-position of the circle in the contentView.
    ///
    /// - returns: The circle view
    private func createCircleWithRadius(radius:CGFloat, color:UIColor, posX:CGFloat, posY:CGFloat) -> UIView {
        let circle = UIView(frame: CGRect(x: posX, y: posY, width: radius*2, height: radius*2))
        circle.backgroundColor      = color
        circle.layer.cornerRadius   = radius
        circle.translatesAutoresizingMaskIntoConstraints = false
        return circle
    }
    
    /// Creates the animation of the circle.
    ///
    /// - parameter duration: The duration of the animation.
    /// - parameter delay: The delay of the animation
    ///
    /// - returns: The animation of the circle.
    private func createAnimationWithDuration(duration:Double, delay:Double) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath:"transform.scale")
       // animation.delegate              = self
        animation.fromValue             = 0
        animation.toValue               = 1
        animation.autoreverses          = true
        animation.duration              = duration
        animation.isRemovedOnCompletion   = false
        animation.beginTime             = CACurrentMediaTime() + delay
        animation.repeatCount           = MAXFLOAT
        animation.timingFunction        = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        return animation
    }
    
    /// Add the circles
    private func addCircles () {
        var color = defaultColor
        
        var radiusForCircle  = (self.frame.width - CGFloat(numberOfCircles-1)*internalSpacing)/CGFloat(2*numberOfCircles)
        if radiusForCircle > self.frame.height/2 {
            radiusForCircle = self.frame.height/2
        }
        
        if radiusForCircle > maxRadius {
            radiusForCircle = maxRadius
        }
        
        var widthUsed = 2*radiusForCircle * CGFloat(numberOfCircles) + CGFloat(numberOfCircles-1)*internalSpacing
        if widthUsed > self.frame.width {
            widthUsed = self.frame.width
        }
        
        let offsetX = (self.frame.width - widthUsed)/2
        
        let posY = (self.frame.height - 2*radiusForCircle)/2
        
        for i in 0..<numberOfCircles {
            if let colorFromDelegate = delegate?.activityIndicatorView(activityIndicatorView: self, circleBackgroundColorAtIndex: i) {
                color = colorFromDelegate
            } else {
                color = defaultColor
            }
            
            let posX = offsetX + CGFloat(i) * ((2*radiusForCircle) + internalSpacing)
            let circle = createCircleWithRadius(radius: radiusForCircle, color: color, posX: posX, posY: posY)
            circle.transform = CGAffineTransform(scaleX: 0, y: 0)
            addSubview(circle)
        }
        updateCirclesanimations()
    }
    
    
    // Update the animation for the circles
    private func updateCirclesanimations () {
        for i in 0..<subviews.count {
            let subview = subviews[i]
            subview.layer .removeAnimation(forKey: "scale")
            subview.layer.add(self.createAnimationWithDuration(duration: duration, delay: Double(i)*delay), forKey: "scale")
        }
    }
    
    /// Remove the circles
    private func removeCircles () {
        for subview in subviews {
            subview.removeFromSuperview()
        }
    }
    
    // Update the circles when a property is changed
    private func updateCircles () {
        removeCircles()
        if isAnimating {
            addCircles()
        }
    }
    
    //MARK: - public methods
    
    func startAnimating () {
        if !isAnimating {
            addCircles()
            isHidden = false
            isAnimating = true
        }
    }
    
    func stopAnimating () {
        if isAnimating {
            removeCircles()
            isHidden = true
            self.isAnimating = false
        }
    }
}
