//
//  CGSizeExtensions.swift
//  AudienzziOSSDK
//
//  Created by Maksym Ovcharuk on 29.10.2025.
//

import Foundation

extension CGSize {
    static func from(string: String) -> CGSize? {
        let parts = string.split(separator: "x")

        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]) else { return nil }

        return CGSize(width: width, height: height)
    }
}
