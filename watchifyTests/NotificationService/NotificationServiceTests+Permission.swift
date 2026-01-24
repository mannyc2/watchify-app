//
//  NotificationServiceTests+Permission.swift
//  watchifyTests
//

import Foundation
import Testing
import UserNotifications
@testable import watchify

extension NotificationServiceTests {

    @Suite("Permission")
    struct Permission {

        // MARK: - sendIfAuthorized Behavior

        @Test("sendIfAuthorized requests permission when notDetermined")
        @MainActor
        func sendIfAuthorizedRequestsPermissionWhenNotDetermined() async {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .notDetermined
            fakeCenter.requestAuthorizationResult = true
            let service = NotificationService(center: fakeCenter)

            let change = ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Test Product",
                variantTitle: "Default"
            )

            await withNotificationDefaults {
                await service.sendIfAuthorized(for: [change])
            }

            #expect(fakeCenter.requestAuthorizationCalls == 1)
            #expect(fakeCenter.addedRequests.count == 1)
        }

        @Test("sendIfAuthorized skips prompt when already authorized")
        @MainActor
        func sendIfAuthorizedSkipsPromptWhenAuthorized() async {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .authorized
            let service = NotificationService(center: fakeCenter)

            let change = ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Test Product",
                variantTitle: "Default"
            )

            await withNotificationDefaults {
                await service.sendIfAuthorized(for: [change])
            }

            #expect(fakeCenter.requestAuthorizationCalls == 0)
            #expect(fakeCenter.addedRequests.count == 1)
        }

        @Test("sendIfAuthorized does not send when denied")
        @MainActor
        func sendIfAuthorizedDoesNotSendWhenDenied() async {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .denied
            let service = NotificationService(center: fakeCenter)

            let change = ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Test Product",
                variantTitle: "Default"
            )

            await withNotificationDefaults {
                await service.sendIfAuthorized(for: [change])
            }

            #expect(fakeCenter.requestAuthorizationCalls == 0)
            #expect(fakeCenter.addedRequests.isEmpty)
        }

        // MARK: - send Behavior

        @Test("send skips delivery when not authorized")
        @MainActor
        func sendSkipsDeliveryWhenNotAuthorized() async {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .notDetermined
            let service = NotificationService(center: fakeCenter)

            let change = ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Test Product",
                variantTitle: "Default"
            )

            await withNotificationDefaults {
                await service.send(for: [change])
            }

            #expect(fakeCenter.addedRequests.isEmpty)
        }

        @Test("send delivers when authorized")
        @MainActor
        func sendDeliversWhenAuthorized() async {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .authorized
            let service = NotificationService(center: fakeCenter)

            let change = ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Test Product",
                variantTitle: "Default"
            )

            await withNotificationDefaults {
                await service.send(for: [change])
            }

            #expect(fakeCenter.addedRequests.count == 1)
        }

        // MARK: - User Denial Flow

        @Test("sendIfAuthorized handles user denial during prompt")
        @MainActor
        func sendIfAuthorizedHandlesUserDenial() async {
            let fakeCenter = FakeNotificationCenter()
            fakeCenter.currentAuthorizationStatus = .notDetermined
            fakeCenter.requestAuthorizationResult = false // User denies
            let service = NotificationService(center: fakeCenter)

            let change = ChangeEventDTO(
                changeType: .priceDropped,
                productTitle: "Test Product",
                variantTitle: "Default"
            )

            await withNotificationDefaults {
                await service.sendIfAuthorized(for: [change])
            }

            #expect(fakeCenter.requestAuthorizationCalls == 1)
            #expect(fakeCenter.addedRequests.isEmpty) // No notification sent
        }
    }
}
