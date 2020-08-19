import XCTest
@testable import Family_Shared

class CALayerExtensionTests: XCTestCase {
    func testResolvingAnimationFromCALayer() {
        let layer = CALayer()
        let animation = CABasicAnimation(keyPath: "bounds")

        animation.fromValue = 10.0

        XCTAssertNil(layer.resolveAnimationDuration)

        layer.add(animation, forKey: "bounds")

        XCTAssertNotNil(layer.resolveAnimationDuration)
    }
}
