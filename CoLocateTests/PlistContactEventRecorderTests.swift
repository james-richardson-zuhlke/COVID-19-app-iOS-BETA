//
//  ContactEventServiceTests.swift
//  CoLocateTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import CoLocate

class PlistContactEventRecorderTests: XCTestCase {

    let epoch = Date(timeIntervalSince1970: 0)
    
    var contactEvent1: ContactEvent!
    var contactEvent2: ContactEvent!
    var contactEvent3: ContactEvent!
    
    var service: PlistContactEventRecorder!

    override func setUp() {
        service = PlistContactEventRecorder()

        contactEvent1 = ContactEvent(uuid: UUID(), timestamp: epoch, rssi: 1)
        contactEvent2 = ContactEvent(uuid: UUID(), timestamp: epoch, rssi: 1)
        contactEvent3 = ContactEvent(uuid: UUID(), timestamp: epoch, rssi: 1)
    }

    override func tearDown() {
        service.reset()
    }

    func testRecordsContactEvents() {
        XCTAssertEqual(service.contactEvents, [])

        service.record(contactEvent1)
        service.record(contactEvent2)
        service.record(contactEvent3)

        XCTAssertEqual(service.contactEvents.count, 3)
        XCTAssertEqual(service.contactEvents[0], contactEvent1)
        XCTAssertEqual(service.contactEvents[1], contactEvent2)
        XCTAssertEqual(service.contactEvents[2], contactEvent3)
    }

    func testPersistsContactEvents() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: service.fileURL.path))

        service.record(contactEvent1)
        service.record(contactEvent2)
        service.record(contactEvent3)

        let attrs = try! FileManager.default.attributesOfItem(atPath: service.fileURL.path)
        XCTAssertNotEqual(attrs[.size] as! NSNumber, 0)
    }

    func testLoadsContactEventsFromDiskOnInit() {
        service.record(contactEvent1)
        service.record(contactEvent2)
        service.record(contactEvent3)

        service = nil

        service = PlistContactEventRecorder()
        XCTAssertEqual(service.contactEvents.count, 3)
    }

}
