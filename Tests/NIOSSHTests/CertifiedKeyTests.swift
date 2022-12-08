//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Crypto
import Foundation
import NIOCore
@testable import NIOSSH
import XCTest

private enum Fixtures {
    // A P384 certificate authority key generated by ssh-keygen
    static let caPublicKey = "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBHYlMSXacXt13oBLpMXEP0OSMw5okd5c7G3hoim1MR/THUOyOS2AVQKEqLZs+td3Y6yYCrq5TGWDNGY2dfKFX99nLqJCq2kxR//CP3UherkZnn6u4eW4biLL7xODqNOzkQ== lukasa@MacBook-Pro.local"
    static let caPublicKeyExport = "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBHYlMSXacXt13oBLpMXEP0OSMw5okd5c7G3hoim1MR/THUOyOS2AVQKEqLZs+td3Y6yYCrq5TGWDNGY2dfKFX99nLqJCq2kxR//CP3UherkZnn6u4eW4biLL7xODqNOzkQ=="
    static let caPrivateKey = """
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAiAAAABNlY2RzYS
    1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQR2JTEl2nF7dd6AS6TFxD9DkjMOaJHe
    XOxt4aIptTEf0x1DsjktgFUChKi2bPrXd2OsmAq6uUxlgzRmNnXyhV/fZy6iQqtpMUf/wj
    91IXq5GZ5+ruHluG4iy+8Tg6jTs5EAAADg/apwCP2qcAgAAAATZWNkc2Etc2hhMi1uaXN0
    cDM4NAAAAAhuaXN0cDM4NAAAAGEEdiUxJdpxe3XegEukxcQ/Q5IzDmiR3lzsbeGiKbUxH9
    MdQ7I5LYBVAoSotmz613djrJgKurlMZYM0ZjZ18oVf32cuokKraTFH/8I/dSF6uRmefq7h
    5bhuIsvvE4Oo07ORAAAAMAo+qT+cSJ5uKifjDjMEx4kL3Q+oVSPGbaM8ikTVRc34VjBbxg
    5DaDpzw64Aza0b0gAAABhsdWthc2FATWFjQm9vay1Qcm8ubG9jYWw=
    -----END OPENSSH PRIVATE KEY-----
    """

    static let p256UserBase = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBIZS1APJofiPeoATC/VC4kKi7xRPdz934nSkFLTc0whYi3A8hEKHAOX9edgL1UWxRqRGQZq2wvvAIjAO9kCeiQA= lukasa@MacBook-Pro.local"

    static let p256UserBaseExport = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBIZS1APJofiPeoATC/VC4kKi7xRPdz934nSkFLTc0whYi3A8hEKHAOX9edgL1UWxRqRGQZq2wvvAIjAO9kCeiQA="

    // A P256 user key. id "User P256 key" serial 0 for foo,bar valid from 2020-06-03T17:50:15 to 2070-04-02T17:51:15
    // Generated using ssh-keygen -s ca-key -I "User P256 key" -n "foo,bar" -V "-1m:+2600w" user-p256
    static let p256User = "ecdsa-sha2-nistp256-cert-v01@openssh.com AAAAKGVjZHNhLXNoYTItbmlzdHAyNTYtY2VydC12MDFAb3BlbnNzaC5jb20AAAAg3JSGtQjaK4FLif7Gx2ftKiYSCdOTFMO+W6UJvmnIu4AAAAAIbmlzdHAyNTYAAABBBIZS1APJofiPeoATC/VC4kKi7xRPdz934nSkFLTc0whYi3A8hEKHAOX9edgL1UWxRqRGQZq2wvvAIjAO9kCeiQAAAAAAAAAAAAAAAAEAAAANVXNlciBQMjU2IGtleQAAAA4AAAADZm9vAAAAA2JhcgAAAABe19THAAAAALyR+QMAAAAAAAAAggAAABVwZXJtaXQtWDExLWZvcndhcmRpbmcAAAAAAAAAF3Blcm1pdC1hZ2VudC1mb3J3YXJkaW5nAAAAAAAAABZwZXJtaXQtcG9ydC1mb3J3YXJkaW5nAAAAAAAAAApwZXJtaXQtcHR5AAAAAAAAAA5wZXJtaXQtdXNlci1yYwAAAAAAAAAAAAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQR2JTEl2nF7dd6AS6TFxD9DkjMOaJHeXOxt4aIptTEf0x1DsjktgFUChKi2bPrXd2OsmAq6uUxlgzRmNnXyhV/fZy6iQqtpMUf/wj91IXq5GZ5+ruHluG4iy+8Tg6jTs5EAAACEAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAABpAAAAMQD1SlsXyALkWyb5fsNEVNhFA7yZ9PV6KrhT6hcUc7WiscqnfTWmlr84dsydmElTXEEAAAAwAmb+JbJ/Bo+3ywz5fQRUoEbNFo9NsQRwLofyrVTdWPv+IMDtMyX/W/SuEjjr8XD4 lukasa@MacBook-Pro.local"

    static let p256UserExport = "ecdsa-sha2-nistp256-cert-v01@openssh.com AAAAKGVjZHNhLXNoYTItbmlzdHAyNTYtY2VydC12MDFAb3BlbnNzaC5jb20AAAAg3JSGtQjaK4FLif7Gx2ftKiYSCdOTFMO+W6UJvmnIu4AAAAAIbmlzdHAyNTYAAABBBIZS1APJofiPeoATC/VC4kKi7xRPdz934nSkFLTc0whYi3A8hEKHAOX9edgL1UWxRqRGQZq2wvvAIjAO9kCeiQAAAAAAAAAAAAAAAAEAAAANVXNlciBQMjU2IGtleQAAAA4AAAADZm9vAAAAA2JhcgAAAABe19THAAAAALyR+QMAAAAAAAAAggAAABVwZXJtaXQtWDExLWZvcndhcmRpbmcAAAAAAAAAF3Blcm1pdC1hZ2VudC1mb3J3YXJkaW5nAAAAAAAAABZwZXJtaXQtcG9ydC1mb3J3YXJkaW5nAAAAAAAAAApwZXJtaXQtcHR5AAAAAAAAAA5wZXJtaXQtdXNlci1yYwAAAAAAAAAAAAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQR2JTEl2nF7dd6AS6TFxD9DkjMOaJHeXOxt4aIptTEf0x1DsjktgFUChKi2bPrXd2OsmAq6uUxlgzRmNnXyhV/fZy6iQqtpMUf/wj91IXq5GZ5+ruHluG4iy+8Tg6jTs5EAAACEAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAABpAAAAMQD1SlsXyALkWyb5fsNEVNhFA7yZ9PV6KrhT6hcUc7WiscqnfTWmlr84dsydmElTXEEAAAAwAmb+JbJ/Bo+3ywz5fQRUoEbNFo9NsQRwLofyrVTdWPv+IMDtMyX/W/SuEjjr8XD4"

    static let p384HostBase = "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBJPOgAXHijSxoZBiyhSDOR3eUELUoc+hqh/SY1Wq4/562jThf6Q+tjVzZTMWZMAP4S6DD2qZswsRvisxXkcZDOw5bvyk0WmezYvjUP6TZII/0BDVTotCf4SxukEtcqBZqg== lukasa@MacBook-Pro.local"

    static let p384HostBaseExport = "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBJPOgAXHijSxoZBiyhSDOR3eUELUoc+hqh/SY1Wq4/562jThf6Q+tjVzZTMWZMAP4S6DD2qZswsRvisxXkcZDOw5bvyk0WmezYvjUP6TZII/0BDVTotCf4SxukEtcqBZqg=="

    // A P384 host key. id "Host P384 key" serial 543 for localhost,example.com valid from 2020-06-03T17:55:53 to 2038-01-19T03:14:07.
    // Generated using ssh-keygen -s ca-key -I "Host P384 key" -h -n "localhost,example.com" -V "-1m:+2600w" -z 543 -O "critical:cats=dogs" -O "extension:lens=wide" -O "extension:size=full-frame" host-p384
    static let p384Host = "ecdsa-sha2-nistp384-cert-v01@openssh.com AAAAKGVjZHNhLXNoYTItbmlzdHAzODQtY2VydC12MDFAb3BlbnNzaC5jb20AAAAgvD8+H64ZEuPHwYIxuym9XHVpiJEoCvCqyy8Ch7JAZEgAAAAIbmlzdHAzODQAAABhBJPOgAXHijSxoZBiyhSDOR3eUELUoc+hqh/SY1Wq4/562jThf6Q+tjVzZTMWZMAP4S6DD2qZswsRvisxXkcZDOw5bvyk0WmezYvjUP6TZII/0BDVTotCf4SxukEtcqBZqgAAAAAAAAIfAAAAAgAAAA1Ib3N0IFAzODQga2V5AAAAHAAAAAlsb2NhbGhvc3QAAAALZXhhbXBsZS5jb20AAAAAXtfWGQAAAAC8kfpVAAAAFAAAAARjYXRzAAAACAAAAARkb2dzAAAALgAAAARsZW5zAAAACAAAAAR3aWRlAAAABHNpemUAAAAOAAAACmZ1bGwtZnJhbWUAAAAAAAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQR2JTEl2nF7dd6AS6TFxD9DkjMOaJHeXOxt4aIptTEf0x1DsjktgFUChKi2bPrXd2OsmAq6uUxlgzRmNnXyhV/fZy6iQqtpMUf/wj91IXq5GZ5+ruHluG4iy+8Tg6jTs5EAAACEAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAABpAAAAMH0U5Rb7TVXX4TP1T1keRioun8qUwsynDX9HHJ/lxgQVdpv3rK/8JVRYE3iEhs8gCwAAADEAp+ljZpPr60aE5l0Q1KrLv5/gfEbYasXBdnSbO47qnAYRg+6VuEb+GGiG9ZAXsq5G lukasa@MacBook-Pro.local"

    static let p384HostExport = "ecdsa-sha2-nistp384-cert-v01@openssh.com AAAAKGVjZHNhLXNoYTItbmlzdHAzODQtY2VydC12MDFAb3BlbnNzaC5jb20AAAAgvD8+H64ZEuPHwYIxuym9XHVpiJEoCvCqyy8Ch7JAZEgAAAAIbmlzdHAzODQAAABhBJPOgAXHijSxoZBiyhSDOR3eUELUoc+hqh/SY1Wq4/562jThf6Q+tjVzZTMWZMAP4S6DD2qZswsRvisxXkcZDOw5bvyk0WmezYvjUP6TZII/0BDVTotCf4SxukEtcqBZqgAAAAAAAAIfAAAAAgAAAA1Ib3N0IFAzODQga2V5AAAAHAAAAAlsb2NhbGhvc3QAAAALZXhhbXBsZS5jb20AAAAAXtfWGQAAAAC8kfpVAAAAFAAAAARjYXRzAAAACAAAAARkb2dzAAAALgAAAARsZW5zAAAACAAAAAR3aWRlAAAABHNpemUAAAAOAAAACmZ1bGwtZnJhbWUAAAAAAAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQR2JTEl2nF7dd6AS6TFxD9DkjMOaJHeXOxt4aIptTEf0x1DsjktgFUChKi2bPrXd2OsmAq6uUxlgzRmNnXyhV/fZy6iQqtpMUf/wj91IXq5GZ5+ruHluG4iy+8Tg6jTs5EAAACEAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAABpAAAAMH0U5Rb7TVXX4TP1T1keRioun8qUwsynDX9HHJ/lxgQVdpv3rK/8JVRYE3iEhs8gCwAAADEAp+ljZpPr60aE5l0Q1KrLv5/gfEbYasXBdnSbO47qnAYRg+6VuEb+GGiG9ZAXsq5G"

    static let ed25519UserBase = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJfkNV4OS33ImTXvorZr72q4v5XhVEQKfvqsxOEJ/XaR lukasa@MacBook-Pro.local"

    static let ed25519UserBaseExport = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJfkNV4OS33ImTXvorZr72q4v5XhVEQKfvqsxOEJ/XaR"

    /// A ed25519 user key. id "User ed25519 key" serial 0 valid from 2020-06-03T17:58:47 to 2038-01-19T03:14:07
    /// Generated using ssh-keygen -s ca-key -I "User ed25519 key" -V "-1m:+2600w" -O "force-command=uname -a" user-ed25519
    static let ed25519User = "ssh-ed25519-cert-v01@openssh.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29tAAAAIDxk/nOhhVDtrweRRR1trNm3T3RdPinf7bYLTPnfWAPuAAAAIJfkNV4OS33ImTXvorZr72q4v5XhVEQKfvqsxOEJ/XaRAAAAAAAAAAAAAAABAAAAEFVzZXIgZWQyNTUxOSBrZXkAAAAAAAAAAF7X1scAAAAAvJH7AwAAACEAAAANZm9yY2UtY29tbWFuZAAAAAwAAAAIdW5hbWUgLWEAAACCAAAAFXBlcm1pdC1YMTEtZm9yd2FyZGluZwAAAAAAAAAXcGVybWl0LWFnZW50LWZvcndhcmRpbmcAAAAAAAAAFnBlcm1pdC1wb3J0LWZvcndhcmRpbmcAAAAAAAAACnBlcm1pdC1wdHkAAAAAAAAADnBlcm1pdC11c2VyLXJjAAAAAAAAAAAAAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBHYlMSXacXt13oBLpMXEP0OSMw5okd5c7G3hoim1MR/THUOyOS2AVQKEqLZs+td3Y6yYCrq5TGWDNGY2dfKFX99nLqJCq2kxR//CP3UherkZnn6u4eW4biLL7xODqNOzkQAAAIMAAAATZWNkc2Etc2hhMi1uaXN0cDM4NAAAAGgAAAAwBWeqRhZqFoGRXg7WtKSbQ9rOn2WNUiaDV1XjX2aCyi/W7431Hxpxg5iGLzP5B7ZuAAAAMByxIrsZhBM9RDxS2qGV9QByw5ebAaRFLtmvJSyxgn1nwWtkPnKetYTsP1Olh4+3tQ== lukasa@MacBook-Pro.local"

    static let ed25519UserExport = "ssh-ed25519-cert-v01@openssh.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29tAAAAIDxk/nOhhVDtrweRRR1trNm3T3RdPinf7bYLTPnfWAPuAAAAIJfkNV4OS33ImTXvorZr72q4v5XhVEQKfvqsxOEJ/XaRAAAAAAAAAAAAAAABAAAAEFVzZXIgZWQyNTUxOSBrZXkAAAAAAAAAAF7X1scAAAAAvJH7AwAAACEAAAANZm9yY2UtY29tbWFuZAAAAAwAAAAIdW5hbWUgLWEAAACCAAAAFXBlcm1pdC1YMTEtZm9yd2FyZGluZwAAAAAAAAAXcGVybWl0LWFnZW50LWZvcndhcmRpbmcAAAAAAAAAFnBlcm1pdC1wb3J0LWZvcndhcmRpbmcAAAAAAAAACnBlcm1pdC1wdHkAAAAAAAAADnBlcm1pdC11c2VyLXJjAAAAAAAAAAAAAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBHYlMSXacXt13oBLpMXEP0OSMw5okd5c7G3hoim1MR/THUOyOS2AVQKEqLZs+td3Y6yYCrq5TGWDNGY2dfKFX99nLqJCq2kxR//CP3UherkZnn6u4eW4biLL7xODqNOzkQAAAIMAAAATZWNkc2Etc2hhMi1uaXN0cDM4NAAAAGgAAAAwBWeqRhZqFoGRXg7WtKSbQ9rOn2WNUiaDV1XjX2aCyi/W7431Hxpxg5iGLzP5B7ZuAAAAMByxIrsZhBM9RDxS2qGV9QByw5ebAaRFLtmvJSyxgn1nwWtkPnKetYTsP1Olh4+3tQ=="

    /// An expired ed25519 user key. id "Expired ed25519 key" serial 0 valid from 2019-06-12T13:00:56 to 2020-05-13T13:00:56
    static let ed25519UserExpired = "ssh-ed25519-cert-v01@openssh.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29tAAAAIEm5DjT8oKCz6iBsujwy9Gk7WDbCZ0/+tV+oerk+WkTBAAAAIJfkNV4OS33ImTXvorZr72q4v5XhVEQKfvqsxOEJ/XaRAAAAAAAAAAAAAAABAAAAE0V4cGlyZWQgZWQyNTUxOSBrZXkAAAAAAAAAAF0A6XgAAAAAXrvheAAAAAAAAACCAAAAFXBlcm1pdC1YMTEtZm9yd2FyZGluZwAAAAAAAAAXcGVybWl0LWFnZW50LWZvcndhcmRpbmcAAAAAAAAAFnBlcm1pdC1wb3J0LWZvcndhcmRpbmcAAAAAAAAACnBlcm1pdC1wdHkAAAAAAAAADnBlcm1pdC11c2VyLXJjAAAAAAAAAAAAAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBHYlMSXacXt13oBLpMXEP0OSMw5okd5c7G3hoim1MR/THUOyOS2AVQKEqLZs+td3Y6yYCrq5TGWDNGY2dfKFX99nLqJCq2kxR//CP3UherkZnn6u4eW4biLL7xODqNOzkQAAAIQAAAATZWNkc2Etc2hhMi1uaXN0cDM4NAAAAGkAAAAwfllCm2yx6paKwnn9UPoTmOP52DH2O4zTcLb3/Jz1wDhGG7yKffZ3vt8hBJ50htz/AAAAMQCM/wSyvs2+sGCemtPKy0OiBUAFOdA8p0bpnNgMF8fmyIVufkdkHrcxD4wvfhFayL4= lukasa@MacBook-Pro.local"

    /// A P521 key that isn't yet valid. Not valid until 2070!
    static let p521NotYetValid = "ecdsa-sha2-nistp521-cert-v01@openssh.com AAAAKGVjZHNhLXNoYTItbmlzdHA1MjEtY2VydC12MDFAb3BlbnNzaC5jb20AAAAgCtGNGe/ofwq449Zc9nVxFQ4RN/aj7yMLZd42hRF67YwAAAAIbmlzdHA1MjEAAACFBACkfM3aZf9sgjAkncWtK6A295sdghn1GG1BKJ+hQfD2VBIJxSQDnPOocNIQQZEo3zs1kvwUXOIgWANJqbOiv77tCACxWRRYmAvM3hzgcEOhPROROG+KGvuDAWW6ZuCkaW0QnseR7Yn0+q/+/jai3tNNDWrbVLDesDj5Aq5xq1yrKDHGEAAAAAAAAAAAAAAAAQAAABZOb3QgeWV0IHZhbGlkIFA1MjEga2V5AAAAAAAAAAC8mvCrAAAAAL560qsAAAAAAAAAggAAABVwZXJtaXQtWDExLWZvcndhcmRpbmcAAAAAAAAAF3Blcm1pdC1hZ2VudC1mb3J3YXJkaW5nAAAAAAAAABZwZXJtaXQtcG9ydC1mb3J3YXJkaW5nAAAAAAAAAApwZXJtaXQtcHR5AAAAAAAAAA5wZXJtaXQtdXNlci1yYwAAAAAAAAAAAAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQR2JTEl2nF7dd6AS6TFxD9DkjMOaJHeXOxt4aIptTEf0x1DsjktgFUChKi2bPrXd2OsmAq6uUxlgzRmNnXyhV/fZy6iQqtpMUf/wj91IXq5GZ5+ruHluG4iy+8Tg6jTs5EAAACFAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAABqAAAAMQDxIqxs6e6dk/H/d6Mr4yxRsIVAiftBZKwN/IdHmthfeNHHQ7sLHb5S2qPwWKoP6NEAAAAxAJsd0xET3dWNnnQ7SVsn6VAhy1Jz70eD1dV55IAqh/IH1sx16GYzTHT9dVwV1FDliQ== lukasa@MacBook-Pro.local"
}

final class CertifiedKeyTests: XCTestCase {
    private func roundTripLoadSerialize(publicKey: String) throws {
        let key = try NIOSSHPublicKey(openSSHPublicKey: publicKey)
        guard let certifiedKey = NIOSSHCertifiedPublicKey(key) else {
            XCTFail("Key is not certified")
            return
        }
        let secondKey = NIOSSHPublicKey(certifiedKey)
        XCTAssertEqual(key, secondKey)
        let setOfKeys = Set([key, secondKey])
        XCTAssertEqual(setOfKeys.count, 1)

        // Write the key.
        var firstBuf = ByteBufferAllocator().buffer(capacity: 1024)
        var secondBuf = firstBuf
        firstBuf.writeCertifiedKey(certifiedKey)
        secondBuf.writeSSHHostKey(secondKey)

        // These two write the same, despite coming from separate buffers.
        XCTAssertEqual(firstBuf, secondBuf)
        let crossLoadedFirst = try firstBuf.readCertifiedKey()
        XCTAssertEqual(crossLoadedFirst, certifiedKey)

        // Now we'll drip-feed the key in from the second buffer.
        for i in 0 ..< secondBuf.readableBytes {
            var slice = secondBuf.getSlice(at: 0, length: i)!
            XCTAssertNil(try slice.readCertifiedKey())
        }
        let crossLoadedSecond = try secondBuf.readCertifiedKey()
        XCTAssertEqual(crossLoadedSecond, certifiedKey)
    }

    func testLoadSerializeP256() throws {
        XCTAssertNoThrow(try self.roundTripLoadSerialize(publicKey: Fixtures.p256User))
    }

    func testLoadSerializeP384() throws {
        XCTAssertNoThrow(try self.roundTripLoadSerialize(publicKey: Fixtures.p384Host))
    }

    func testLoadSerializeEd25519() throws {
        XCTAssertNoThrow(try self.roundTripLoadSerialize(publicKey: Fixtures.ed25519User))
    }

    func testStraightForwardHappyPathVerificationUser() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!

        // Let's try both valid principals
        var criticalOptions = try userKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [caKey])
        XCTAssertEqual(criticalOptions, [:])

        criticalOptions = try userKey.validate(principal: "bar", type: .user, allowedAuthoritySigningKeys: [caKey])
        XCTAssertEqual(criticalOptions, [:])
    }

    func testStraightForwardHappyPathVerificationHost() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!

        // Let's try both valid principals
        var criticalOptions = try hostKey.validate(principal: "localhost", type: .host, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["cats"])
        XCTAssertEqual(criticalOptions, ["cats": "dogs"])

        criticalOptions = try hostKey.validate(principal: "example.com", type: .host, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["cats"])
        XCTAssertEqual(criticalOptions, ["cats": "dogs"])
    }

    func testStraightForwardHappyPathVerificationUserEd25519() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519User))!

        // Let's try any random principal: this will be good for anything
        var criticalOptions = try userKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["force-command"])
        XCTAssertEqual(criticalOptions, ["force-command": "uname -a"])

        criticalOptions = try userKey.validate(principal: "bar", type: .user, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["force-command"])
        XCTAssertEqual(criticalOptions, ["force-command": "uname -a"])

        criticalOptions = try userKey.validate(principal: "qwerty", type: .user, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["force-command"])
        XCTAssertEqual(criticalOptions, ["force-command": "uname -a"])
    }

    func testKeysThatDontMatchPrincipalAreRejected() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!
        XCTAssertThrowsError(try userKey.validate(principal: "baz", type: .user, allowedAuthoritySigningKeys: [caKey])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
        XCTAssertThrowsError(try hostKey.validate(principal: "baz", type: .user, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["cats"])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testKeysThatDontMatchTypeAreRejected() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!
        let edKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519User))!
        XCTAssertThrowsError(try userKey.validate(principal: "foo", type: .host, allowedAuthoritySigningKeys: [caKey])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
        XCTAssertThrowsError(try hostKey.validate(principal: "localhost", type: .user, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["cats"])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
        XCTAssertThrowsError(try edKey.validate(principal: "foo", type: .host, allowedAuthoritySigningKeys: [caKey])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testKeysSignedByTheWrongEntityAreRejected() throws {
        let badCAKey = NIOSSHPrivateKey(p256Key: .init()).publicKey
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!
        let edKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519User))!
        XCTAssertThrowsError(try userKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [badCAKey])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
        XCTAssertThrowsError(try hostKey.validate(principal: "localhost", type: .host, allowedAuthoritySigningKeys: [badCAKey], acceptableCriticalOptions: ["cats"])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
        XCTAssertThrowsError(try edKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [badCAKey])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testKeysIgnoreUnsuitableCAs() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let badCAKey = NIOSSHPrivateKey(p256Key: .init()).publicKey
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!
        let edKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519User))!
        XCTAssertNoThrow(try userKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [badCAKey, caKey]))
        XCTAssertNoThrow(try hostKey.validate(principal: "localhost", type: .host, allowedAuthoritySigningKeys: [badCAKey, caKey], acceptableCriticalOptions: ["cats"]))
        XCTAssertNoThrow(try edKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [badCAKey, caKey], acceptableCriticalOptions: ["force-command"]))
    }

    func testKeysContainingUnsupportedCriticalExtensionsAreRejected() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!
        XCTAssertThrowsError(try hostKey.validate(principal: "localhost", type: .host, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["dogs"])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testExtraCriticalExtensionsAreIgnored() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!

        // Let's try both valid principals
        let criticalOptions = try hostKey.validate(principal: "localhost", type: .host, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["cats", "lizards"])
        XCTAssertEqual(criticalOptions, ["cats": "dogs"])
    }

    func testExpiredKeysFailValidation() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519UserExpired))!

        // Let's try any random principal: this will be good for anything
        XCTAssertThrowsError(try userKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [caKey], acceptableCriticalOptions: ["force-command"])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testKeysNotYetValidFailValidation() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p521NotYetValid))!

        // Let's try any random principal: this will be good for anything
        XCTAssertThrowsError(try userKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [caKey])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testExpectedFieldContentUserP256() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        let baseKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256UserBase)
        XCTAssertEqual(userKey.serial, 0)
        XCTAssertEqual(userKey.type, .user)
        XCTAssertEqual(userKey.key, baseKey)
        XCTAssertEqual(userKey.keyID, "User P256 key")
        XCTAssertEqual(userKey.validPrincipals, ["foo", "bar"])
        XCTAssertEqual(userKey.validAfter, 1_591_203_015)
        XCTAssertEqual(userKey.validBefore, 3_163_683_075)
        XCTAssertEqual(userKey.criticalOptions, [:])
        XCTAssertEqual(userKey.extensions, ["permit-port-forwarding": "", "permit-agent-forwarding": "", "permit-X11-forwarding": "", "permit-pty": "", "permit-user-rc": ""])

        // Signature is tested in the validation code.
        XCTAssertEqual(userKey.signatureKey, caKey)
    }

    func testExpectedFieldContentHostP384() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!
        let baseKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384HostBase)
        XCTAssertEqual(hostKey.serial, 543)
        XCTAssertEqual(hostKey.type, .host)
        XCTAssertEqual(hostKey.key, baseKey)
        XCTAssertEqual(hostKey.keyID, "Host P384 key")
        XCTAssertEqual(hostKey.validPrincipals, ["localhost", "example.com"])
        XCTAssertEqual(hostKey.validAfter, 1_591_203_353)
        XCTAssertEqual(hostKey.validBefore, 3_163_683_413)
        XCTAssertEqual(hostKey.criticalOptions, ["cats": "dogs"])
        XCTAssertEqual(hostKey.extensions, ["lens": "wide", "size": "full-frame"])

        // Signature is tested in the validation code.
        XCTAssertEqual(hostKey.signatureKey, caKey)
    }

    func testExpectedFieldContentUserEd25519() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519User))!
        let baseKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519UserBase)
        XCTAssertEqual(userKey.serial, 0)
        XCTAssertEqual(userKey.type, .user)
        XCTAssertEqual(userKey.key, baseKey)
        XCTAssertEqual(userKey.keyID, "User ed25519 key")
        XCTAssertEqual(userKey.validPrincipals, [])
        XCTAssertEqual(userKey.validAfter, 1_591_203_527)
        XCTAssertEqual(userKey.validBefore, 3_163_683_587)
        XCTAssertEqual(userKey.criticalOptions, ["force-command": "uname -a"])
        XCTAssertEqual(userKey.extensions, ["permit-port-forwarding": "", "permit-agent-forwarding": "", "permit-X11-forwarding": "", "permit-pty": "", "permit-user-rc": ""])

        // Signature is tested in the validation code.
        XCTAssertEqual(userKey.signatureKey, caKey)
    }

    //tests to check that keyIntoComponents returns the correct string without comments
    func testCaKeyToComponents() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        let reExported = caKey.keyIntoComponents()
        XCTAssertEqual(reExported, Fixtures.caPublicKeyExport)
    }

    func testBaseKeyToComponents() throws {
        let baseKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519UserBase)
        let reExported = baseKey.keyIntoComponents()
        XCTAssertEqual(reExported, Fixtures.ed25519UserBaseExport)
    }

    func testUserKeyToComponents() throws {
        let userK = try (NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519User))
        let reExported = userK.keyIntoComponents()
        XCTAssertEqual(reExported, Fixtures.ed25519UserExport)
    }

    func test384HostToComponents() throws {
        let host384 = try (NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))
        let reExported = host384.keyIntoComponents()
        XCTAssertEqual(reExported, Fixtures.p384HostExport)
    }

    func testUser256ToComponents() throws {
        let user256 = try (NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))
        let reExported = user256.keyIntoComponents()
        XCTAssertEqual(reExported, Fixtures.p256UserExport)
    }

    func test384HostBaseToComponents() throws {
        let baseKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384HostBase)
        let reExported = baseKey.keyIntoComponents()
        XCTAssertEqual(reExported, Fixtures.p384HostBaseExport)
    }

    func test256UserBasedToComponents() throws {
        let userK = try (NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256UserBase))
        let reExported = userK.keyIntoComponents()
        XCTAssertEqual(reExported, Fixtures.p256UserBaseExport)
    }


    private func testVerificationFailsOnMutation(_ mutator: (inout NIOSSHCertifiedPublicKey) throws -> Void) throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        var userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        try mutator(&userKey)

        XCTAssertThrowsError(try userKey.validate(principal: "foo", type: .user, allowedAuthoritySigningKeys: [caKey])) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testVerificationFailsWhenMutatingNonce() throws {
        try self.testVerificationFailsOnMutation { $0.nonce.setInteger(UInt8(104), at: 0) }
    }

    func testVerificationFailsWhenMutatingSerial() throws {
        try self.testVerificationFailsOnMutation { $0.serial = 66 }
    }

    func testVerificationFailsWhenMutatingType() throws {
        try self.testVerificationFailsOnMutation { $0.type = .host }
    }

    func testVerificationFailsWhenMutatingKey() throws {
        try self.testVerificationFailsOnMutation { $0.key = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519UserBase) }
    }

    func testVerificationFailsWhenMutatingKeyID() throws {
        try self.testVerificationFailsOnMutation { $0.keyID = "Definitely fake" }
    }

    func testVerificationFailsWhenMutatingValidPrincipals() throws {
        try self.testVerificationFailsOnMutation { $0.validPrincipals = ["foo", "probably wasn't here before"] }
    }

    func testVerificationFailsWhenMutatingValidAfter() throws {
        try self.testVerificationFailsOnMutation { $0.validAfter += 1 }
    }

    func testVerificationFailsWhenMutatingValidBefore() throws {
        try self.testVerificationFailsOnMutation { $0.validBefore += 1 }
    }

    func testVerificationFailsWhenMutatingCriticalOptions() throws {
        try self.testVerificationFailsOnMutation { $0.criticalOptions["really"] = "yes" }
    }

    func testVerificationFailsWhenMutatingExtensions() throws {
        try self.testVerificationFailsOnMutation { $0.extensions["really"] = "yes" }
    }

    func testVerificationFailsWhenMutatingSignature() throws {
        try self.testVerificationFailsOnMutation { $0.signature = try NIOSSHPrivateKey(p256Key: .init()).sign(digest: SHA256.hash(data: [1, 2, 3, 4])) }
    }

    func testVerificationFailsWhenMutatingSignatureKey() throws {
        try self.testVerificationFailsOnMutation { $0.signatureKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519UserBase) }
    }

    func simpleCoWBehavesAppropriately(_ modifier: (inout NIOSSHCertifiedPublicKey) throws -> Void) throws {
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        var copy = userKey
        let otherCopy = userKey
        try modifier(&copy)

        XCTAssertEqual(otherCopy, userKey)
        XCTAssertNotEqual(copy, userKey)

        XCTAssertEqual(Set([copy, otherCopy, userKey]), Set([copy, userKey]))
    }

    func testCoWBehavesAppropriatelyWhenMutatingNonce() throws {
        try self.simpleCoWBehavesAppropriately { $0.nonce.setInteger(UInt8(104), at: 0) }
    }

    func testCoWBehavesAppropriatelyWhenMutatingSerial() throws {
        try self.simpleCoWBehavesAppropriately { $0.serial = 66 }
    }

    func testCoWBehavesAppropriatelyWhenMutatingType() throws {
        try self.simpleCoWBehavesAppropriately { $0.type = .host }
    }

    func testCoWBehavesAppropriatelyWhenMutatingKey() throws {
        try self.simpleCoWBehavesAppropriately { $0.key = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519UserBase) }
    }

    func testCoWBehavesAppropriatelyWhenMutatingKeyID() throws {
        try self.simpleCoWBehavesAppropriately { $0.keyID = "Definitely fake" }
    }

    func testCoWBehavesAppropriatelyWhenMutatingValidPrincipals() throws {
        try self.simpleCoWBehavesAppropriately { $0.validPrincipals = ["foo", "probably wasn't here before"] }
    }

    func testVCoWBehavesAppropriatelyWhenMutatingValidAfter() throws {
        try self.simpleCoWBehavesAppropriately { $0.validAfter += 1 }
    }

    func testCoWBehavesAppropriatelyWhenMutatingValidBefore() throws {
        try self.simpleCoWBehavesAppropriately { $0.validBefore += 1 }
    }

    func testCoWBehavesAppropriatelyWhenMutatingCriticalOptions() throws {
        try self.simpleCoWBehavesAppropriately { $0.criticalOptions["really"] = "yes" }
    }

    func testCoWBehavesAppropriatelyWhenMutatingExtensions() throws {
        try self.simpleCoWBehavesAppropriately { $0.extensions["really"] = "yes" }
    }

    func testCoWBehavesAppropriatelyWhenMutatingSignature() throws {
        try self.simpleCoWBehavesAppropriately { $0.signature = try NIOSSHPrivateKey(p256Key: .init()).sign(digest: SHA256.hash(data: [1, 2, 3, 4])) }
    }

    func testCoWBehavesAppropriatelyWhenMutatingSignatureKey() throws {
        try self.simpleCoWBehavesAppropriately { $0.signatureKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.ed25519UserBase) }
    }

    func testKeyRejectsBeingCreatedWithCertifiedKeyAsKey() throws {
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!

        XCTAssertThrowsError(try NIOSSHCertifiedPublicKey(nonce: userKey.nonce,
                                                          serial: userKey.serial,
                                                          type: userKey.type,
                                                          key: NIOSSHPublicKey(hostKey),
                                                          keyID: userKey.keyID,
                                                          validPrincipals: userKey.validPrincipals,
                                                          validAfter: userKey.validAfter,
                                                          validBefore: userKey.validBefore,
                                                          criticalOptions: userKey.criticalOptions,
                                                          extensions: userKey.extensions,
                                                          signatureKey: userKey.signatureKey,
                                                          signature: userKey.signature)) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testKeyRejectsBeingCreatedWithCertifiedKeyAsSignatureKey() throws {
        let userKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p256User))!
        let hostKey = try NIOSSHCertifiedPublicKey(NIOSSHPublicKey(openSSHPublicKey: Fixtures.p384Host))!

        XCTAssertThrowsError(try NIOSSHCertifiedPublicKey(nonce: userKey.nonce,
                                                          serial: userKey.serial,
                                                          type: userKey.type,
                                                          key: userKey.key,
                                                          keyID: userKey.keyID,
                                                          validPrincipals: userKey.validPrincipals,
                                                          validAfter: userKey.validAfter,
                                                          validBefore: userKey.validBefore,
                                                          criticalOptions: userKey.criticalOptions,
                                                          extensions: userKey.extensions,
                                                          signatureKey: NIOSSHPublicKey(hostKey),
                                                          signature: userKey.signature)) { error in
            XCTAssertEqual((error as? NIOSSHError)?.type, .invalidCertificate)
        }
    }

    func testNonCertifiedKeysDontAllowConstruction() throws {
        let caKey = try NIOSSHPublicKey(openSSHPublicKey: Fixtures.caPublicKey)
        XCTAssertNil(NIOSSHCertifiedPublicKey(caKey))
    }
}
