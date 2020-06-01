//
//  TestResultNotificationHandler.swift
//  Sonar
//
//  Created by NHSX on 21/05/2020
//  Copyright © 2020 NHSX. All rights reserved.
//

import Foundation

import Logging

class TestResultNotificationHandler {
    
    struct UserInfoDecodingError: Error {}
    
    let logger = Logger(label: "StatusNotificationHandler")

    let statusStateMachine: StatusStateMachining
    let userNotificationCenter: UserNotificationCenter

    init(
        statusStateMachine: StatusStateMachining,
        userNotificationCenter: UserNotificationCenter
    ) {
        self.statusStateMachine = statusStateMachine
        self.userNotificationCenter = userNotificationCenter
    }
    
    func handle(userInfo: [AnyHashable: Any], completion: @escaping RemoteNotificationCompletionHandler) {
        let testResult: TestResult
        
        do {
            try testResult = getTestResult(fromUserInfo: userInfo)
        } catch {
            logger.error("Unable to process test result notification: '\(String(describing: userInfo))'")
            completion(.noData)
            return
        }
        
        statusStateMachine.received(testResult)
        completion(.newData)
    }
    
    private func getTestResult(fromUserInfo userInfo: [AnyHashable: Any]) throws -> TestResult {
        let jsonData = try JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let testResult = try? decoder.decode(TestResult.self, from: jsonData) {
            return testResult
        } else {
            throw UserInfoDecodingError()
        }

    }

}
