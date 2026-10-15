import SwiftUI
import UIKit

enum Palette {
    static let paper = dynamic(light: (243, 238, 230), dark: (22, 20, 18))
    static let ink = dynamic(light: (33, 30, 26), dark: (243, 238, 230))
    static let muted = dynamic(light: (111, 103, 95), dark: (183, 175, 166))
    static let coral = dynamic(light: (212, 83, 43), dark: (227, 122, 88))
    static let card = dynamic(light: (251, 248, 243), dark: (34, 31, 28))
    static let line = dynamic(light: (228, 221, 210), dark: (58, 52, 46))

    private static func dynamic(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
        })
    }
}
