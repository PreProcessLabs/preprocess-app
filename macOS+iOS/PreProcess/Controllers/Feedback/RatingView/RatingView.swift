//
//  RatingView.swift
//  OasisStudentMacUI
//
//  Created by Roushil Singla on 23/02/22.
//

import Cocoa

public class RatingView: NSView {

    @IBOutlet var customView: NSView!
    @IBOutlet weak var rateTitleLabel: NSTextField!
    @IBOutlet weak var firstStarButton: NSButton!
    @IBOutlet weak var secondStarButton: NSButton!
    @IBOutlet weak var thirdStarButton: NSButton!
    @IBOutlet weak var fourthStarButton: NSButton!
    @IBOutlet weak var fifthStarButton: NSButton!
    
    var onStarClick: ((Int) -> Void)?
    var isUserInteractionEnabled = true
    
    public override init(frame frameRect: NSRect) {
        super.init(frame:frameRect )
        addView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        addView()
    }
    
    private func addView() {
        Bundle(for: RatingView.self).loadNibNamed("RatingView", owner: self, topLevelObjects: nil)
        let contentFrame = NSMakeRect(0, 0, frame.size.width, frame.size.height)
        customView.frame = contentFrame
        addSubview(customView)
        
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return isUserInteractionEnabled ? super.hitTest(point) : nil
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        firstStarButton.wantsLayer = true
        secondStarButton.wantsLayer = true
        thirdStarButton.wantsLayer = true
        fourthStarButton.wantsLayer = true
        fifthStarButton.wantsLayer = true
    }
    
    
    @IBAction func star1Action(_ sender: Any) {
        firstStarButton.contentTintColor = .systemYellow
        secondStarButton.contentTintColor = .lightGray
        thirdStarButton.contentTintColor = .lightGray
        fourthStarButton.contentTintColor = .lightGray
        fifthStarButton.contentTintColor = .lightGray
        onStarClick?(1)
    }
    
    @IBAction func star2Action(_ sender: Any) {
        firstStarButton.contentTintColor = .systemYellow
        secondStarButton.contentTintColor = .systemYellow
        thirdStarButton.contentTintColor = .lightGray
        fourthStarButton.contentTintColor = .lightGray
        fifthStarButton.contentTintColor = .lightGray
        onStarClick?(2)
    }
    
    @IBAction func star3Action(_ sender: Any) {
        firstStarButton.contentTintColor = .systemYellow
        secondStarButton.contentTintColor = .systemYellow
        thirdStarButton.contentTintColor = .systemYellow
        fourthStarButton.contentTintColor = .lightGray
        fifthStarButton.contentTintColor = .lightGray
        onStarClick?(3)
    }
    
    @IBAction func star4Action(_ sender: Any) {
        firstStarButton.contentTintColor = .systemYellow
        secondStarButton.contentTintColor = .systemYellow
        thirdStarButton.contentTintColor = .systemYellow
        fourthStarButton.contentTintColor = .systemYellow
        fifthStarButton.contentTintColor = .lightGray
        onStarClick?(4)
    }
    
    @IBAction func star5Action(_ sender: Any) {
        firstStarButton.contentTintColor = .systemYellow
        secondStarButton.contentTintColor = .systemYellow
        thirdStarButton.contentTintColor = .systemYellow
        fourthStarButton.contentTintColor = .systemYellow
        fifthStarButton.contentTintColor = .systemYellow
        onStarClick?(5)
    }
    
    public func setTitleForRating(title: String) {
        rateTitleLabel.stringValue = title
        rateTitleLabel.isHidden = title.isEmpty
    }
    
    
    public func setRatings(count: Int, isUserInteractionEnabled: Bool) {
        
        self.isUserInteractionEnabled = isUserInteractionEnabled
        
        switch count {
        case 1:
            star1Action(firstStarButton as Any)
        case 2:
            star2Action(secondStarButton as Any)
        case 3:
            star3Action(thirdStarButton as Any)
        case 4:
            star4Action(fourthStarButton as Any)
        case 5:
            star5Action(fifthStarButton as Any)
        default:
            break
        }
    }
    
    
}
