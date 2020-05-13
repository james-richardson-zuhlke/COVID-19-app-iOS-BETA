//
//  StatusStateMachineTests.swift
//  SonarTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import Sonar

class StatusStateMachineTests: XCTestCase {

    var machine: StatusStateMachine!
    var persisting: PersistenceDouble!
    var contactEventsUploader: ContactEventsUploaderDouble!
    var notificationCenter: NotificationCenter!
    var userNotificationCenter: UserNotificationCenterDouble!
    var currentDate: Date!

    override func setUp() {
        persisting = PersistenceDouble()
        contactEventsUploader = ContactEventsUploaderDouble()
        notificationCenter = NotificationCenter()
        userNotificationCenter = UserNotificationCenterDouble()

        machine = StatusStateMachine(
            persisting: persisting,
            contactEventsUploader: contactEventsUploader,
            notificationCenter: notificationCenter,
            userNotificationCenter: userNotificationCenter,
            dateProvider: self.currentDate
        )
    }

    func testDefaultIsOk() {
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))
    }

    func testPostExposureNotificationOnExposed() throws {
        currentDate = Date()

        machine.exposed()

        let request = try XCTUnwrap(userNotificationCenter.request)
        XCTAssertEqual(request.content.title, "POTENTIAL_STATUS_TITLE".localized)
    }

    func testPostNotificationOnStatusChange() throws {
        currentDate = Date()

        var notificationPosted = false
        notificationCenter.addObserver(
            forName: StatusStateMachine.StatusStateChangedNotification,
            object: nil,
            queue: nil
        ) { _ in
            notificationPosted = true
        }

        machine.exposed()
        XCTAssertTrue(notificationPosted)

        notificationPosted = false
        try machine.selfDiagnose(symptoms: [.cough], startDate: currentDate)
        XCTAssertTrue(notificationPosted)
    }

    func testOkToSymptomatic() throws {
        persisting.statusState = .ok(StatusState.Ok())

        let startDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 6))!
        try machine.selfDiagnose(symptoms: [.cough], startDate: startDate)

        XCTAssertEqual(machine.state, .symptomatic(StatusState.Symptomatic(symptoms: [.cough], startDate: startDate)))
        XCTAssertTrue(contactEventsUploader.uploadCalled)

        let request = try XCTUnwrap(userNotificationCenter.request)
        XCTAssertEqual(request.identifier, "Diagnosis")
    }

    func testExposedToSymptomatic() throws {
        persisting.statusState = .exposed(StatusState.Exposed(exposureDate: Date()))

        let startDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 6))!
        try machine.selfDiagnose(symptoms: [.cough], startDate: startDate)

        XCTAssertEqual(machine.state, .symptomatic(StatusState.Symptomatic(symptoms: [.cough], startDate: startDate)))
        XCTAssertTrue(contactEventsUploader.uploadCalled)

        let request = try XCTUnwrap(userNotificationCenter.request)
        XCTAssertEqual(request.identifier, "Diagnosis")
    }

    func testTickFromSymptomaticToCheckin() throws {
        let startDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        let symptomatic = StatusState.Symptomatic(symptoms: [.cough], startDate: startDate)
        persisting.statusState = .symptomatic(symptomatic)

        currentDate = Calendar.current.date(byAdding: .hour, value: -1, to: symptomatic.expiryDate)!
        machine.tick()
        XCTAssertTrue(machine.state.isSymptomatic)

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: symptomatic.expiryDate)!
        machine.tick()
        guard case .checkin(let checkin) = machine.state else {
            XCTFail()
            return
        }

        XCTAssertEqual(checkin.checkinDate, symptomatic.expiryDate)

        // There's already a notification scheduled for the symptomatic expiry date
        XCTAssertNil(userNotificationCenter.request)
    }

    func testTickWhenExposedBeforeSeven() {
        let exposureDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 6))!
        let expiry = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 14, hour: 7))!
        persisting.statusState = .exposed(StatusState.Exposed(exposureDate: exposureDate))

        currentDate = Calendar.current.date(byAdding: .hour, value: -1, to: expiry)!
        machine.tick()
        XCTAssertTrue(machine.state.isExposed)

        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: expiry)!
        machine.tick()
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))
    }

    func testTickWhenExposedAfterSeven() {
        let exposureDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 8))!
        let expiry = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 15, hour: 7))!
        persisting.statusState = .exposed(StatusState.Exposed(exposureDate: exposureDate))

        currentDate = Calendar.current.date(byAdding: .hour, value: -1, to: expiry)!
        machine.tick()
        XCTAssertTrue(machine.state.isExposed)

        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: expiry)!
        machine.tick()
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))
    }

    func testCheckinOnlyCough() {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: checkinAt)!
        machine.checkin(symptoms: [.cough])
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))

        XCTAssertNil(userNotificationCenter.request)
    }

    func testCheckinOnlyTemperature() throws {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: checkinAt)!
        machine.checkin(symptoms: [.temperature])

        let nextCheckin = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2, hour: 7))!
        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: nextCheckin)))

        let request = try XCTUnwrap(userNotificationCenter.request)
        XCTAssertEqual(request.identifier, "Diagnosis")
    }

    func testCheckinBothCoughAndTemperature() throws {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: checkinAt)!
        machine.checkin(symptoms: [.cough, .temperature])

        let nextCheckin = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2, hour: 7))!
        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.cough, .temperature], checkinDate: nextCheckin)))

        let request = try XCTUnwrap(userNotificationCenter.request)
        XCTAssertEqual(request.identifier, "Diagnosis")
    }

    func testCheckinWithTemperatureAfterMultipleDays() throws {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        // 2020.04.04
        currentDate = Calendar.current.date(byAdding: .day, value: 3, to: checkinAt)!
        machine.checkin(symptoms: [.temperature])

        let nextCheckin = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 5, hour: 7))!
        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: nextCheckin)))

        let request = try XCTUnwrap(userNotificationCenter.request)
        XCTAssertEqual(request.identifier, "Diagnosis")
    }

    func testIgnoreExposedWhenSymptomatic() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1))!
        persisting.statusState = .symptomatic(StatusState.Symptomatic(symptoms: [.cough], startDate: startDate))

        currentDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2))!
        machine.exposed()

        XCTAssertEqual(machine.state, .symptomatic(StatusState.Symptomatic(symptoms: [.cough], startDate: startDate)))
    }

    func testIgnoreExposedWhenCheckingIn() {
        let checkinDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: checkinDate))

        currentDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2))!
        machine.exposed()

        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: checkinDate)))
    }

}
