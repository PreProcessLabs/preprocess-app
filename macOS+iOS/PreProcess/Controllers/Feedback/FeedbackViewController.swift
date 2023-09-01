//
//  FeedbackViewController.swift
//  PreProcess
//
//  Created by Roushil Singla on 26/08/23.
//

import Cocoa

class FeedbackViewController: NSViewController {

    @IBOutlet weak var ratingView: RatingView!
    @IBOutlet var inputTextView: NSTextView!
    
    var ratedValue = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handleRating()
    }
    
    @IBAction func onSubmitClick(_ sender: NSButton) {
        print(inputTextView.string)
        print(ratedValue)
    }
    
    func handleRating() {
        ratingView.onStarClick = { [unowned self] rating in
            ratedValue = rating
        }
    }
    
}
