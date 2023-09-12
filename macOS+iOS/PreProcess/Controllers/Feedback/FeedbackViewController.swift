//
//  FeedbackViewController.swift
//  PreProcess
//
//  Created by Roushil Singla on 26/08/23.
//

import Cocoa
import SwiftUI

class FeedbackViewController: NSViewController {

    @IBOutlet weak var ratingView: RatingView!
    @IBOutlet var inputTextView: NSTextView!
    @IBOutlet weak var submitSuccessImageView: NSImageView!
    
    var ratedValue = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        handleRating()
        submitSuccessImageView.isHidden = true
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func onSubmitClick(_ sender: NSButton) {
        guard let accessToken = UserDefaults.standard.string(forKey: "AccessTokenKey") else {
            return
        }
        sender.isEnabled = false
        ratingView.isUserInteractionEnabled = false

        // Use the accessToken in your POST request to http://preprocess.tech/api/v1/account/feedback/
        let feedbackPayload: [String: Any] = [
            "feedback_rating": ratedValue,
            "feedback_description": inputTextView.string,
        ]

        // Create a URLRequest and include the accessToken in the request headers
        var request = URLRequest(url: URL(string: "http://preprocess.tech/api/v1/account/feedback/")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: feedbackPayload, options: [])
            request.httpBody = jsonData

            // Send the POST request and handle the response
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error: \(error)")
                        sender.isEnabled = true
                        self.ratingView.isUserInteractionEnabled = true
                    } else if let _ = data {
                        self.submitSuccessImageView.isHidden = false
                    }
                }
            }.resume()
        } catch {
            // Handle the error (e.g., show an alert to the user)
            print("Error serializing JSON: \(error)")
        }
    }

    func handleRating() {
        ratingView.onStarClick = { [unowned self] rating in
            ratedValue = rating
        }
    }
}
