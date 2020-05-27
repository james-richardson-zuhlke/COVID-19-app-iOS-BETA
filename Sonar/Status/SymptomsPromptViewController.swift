//
//  SymptomsPromptViewController.swift
//  Sonar
//
//  Created by NHSX on 4/20/20.
//  Copyright © 2020 NHSX. All rights reserved.
//

import UIKit

class SymptomsPromptViewController: UIViewController, Storyboarded {
    static var storyboardName = "QuestionnaireDrawer"

    var completion: ((_ needsCheckin: Bool) -> Void)!

    func inject(
        completion: @escaping (_ needsCheckin: Bool) -> Void
    ) {
        self.completion = completion
    }
    
    @IBAction func updateSymptoms() {
        completion(true)
    }
    
    @IBAction func noSymptoms() {
        completion(false)
    }
}
