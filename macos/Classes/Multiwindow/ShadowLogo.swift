import Foundation
import SwiftUI

struct ProgressiveFillShadowLogo: View {
    var fillLevel: CGFloat
    var fillColor: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base white logo
                ShadowLogo(fillLevel: 1.0)
                    .fill(Color.white)

                // Colored fill
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [fillColor.opacity(0.7), fillColor]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: geometry.size.height * fillLevel)
                    .offset(y: geometry.size.height * (1 - fillLevel))
            }
            .clipShape(ShadowLogo(fillLevel: 1.0))
        }
    }
}

struct ShadowLogo: Shape {
    var fillLevel: CGFloat
    
    func fill<Fill: ShapeStyle, Stroke: ShapeStyle>(_ fillStyle: Fill, strokeBorder strokeStyle: Stroke, lineWidth: Double = 1) -> some View {
        ZStack {
            self.fill(fillStyle)
            self.stroke(strokeStyle, lineWidth: lineWidth)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.77565*width, y: 0.6557*height))
        path.addCurve(to: CGPoint(x: 0.81125*width, y: 0.7062*height), control1: CGPoint(x: 0.79535*width, y: 0.6558*height), control2: CGPoint(x: 0.81125*width, y: 0.67835*height))
        path.addCurve(to: CGPoint(x: 0.7754*width, y: 0.75665*height), control1: CGPoint(x: 0.81125*width, y: 0.73405*height), control2: CGPoint(x: 0.7952*width, y: 0.75685*height))
        path.addCurve(to: CGPoint(x: 0.6836*width, y: 0.7565*height), control1: CGPoint(x: 0.7648*width, y: 0.75655*height), control2: CGPoint(x: 0.6942*width, y: 0.75655*height))
        path.addCurve(to: CGPoint(x: 0.64425*width, y: 0.79745*height), control1: CGPoint(x: 0.6599*width, y: 0.75645*height), control2: CGPoint(x: 0.64935*width, y: 0.76635*height))
        path.addCurve(to: CGPoint(x: 0.6032*width, y: 0.9133*height), control1: CGPoint(x: 0.6371*width, y: 0.84075*height), control2: CGPoint(x: 0.62285*width, y: 0.8785*height))
        path.addCurve(to: CGPoint(x: 0.6023*width, y: 0.94515*height), control1: CGPoint(x: 0.59795*width, y: 0.92255*height), control2: CGPoint(x: 0.5972*width, y: 0.9357*height))
        path.addCurve(to: CGPoint(x: 0.6729*width, y: 0.9753*height), control1: CGPoint(x: 0.6222*width, y: 0.98205*height), control2: CGPoint(x: 0.6476*width, y: 0.98475*height))
        path.addCurve(to: CGPoint(x: 0.77865*width, y: 0.91795*height), control1: CGPoint(x: 0.70955*width, y: 0.9616*height), control2: CGPoint(x: 0.7447*width, y: 0.94185*height))
        path.addCurve(to: CGPoint(x: 0.947*width, y: 0.7228*height), control1: CGPoint(x: 0.8453*width, y: 0.87105*height), control2: CGPoint(x: 0.90345*width, y: 0.80925*height))
        path.addCurve(to: CGPoint(x: 1.00005*width, y: 0.50105*height), control1: CGPoint(x: 0.9804*width, y: 0.6566*height), control2: CGPoint(x: 0.99985*width, y: 0.5833*height))
        path.addCurve(to: CGPoint(x: 0.96965*width, y: 0.45775*height), control1: CGPoint(x: 1.0001*width, y: 0.47115*height), control2: CGPoint(x: 0.99095*width, y: 0.458*height))
        path.addCurve(to: CGPoint(x: 0.8191*width, y: 0.4573*height), control1: CGPoint(x: 0.95085*width, y: 0.45755*height), control2: CGPoint(x: 0.8379*width, y: 0.4574*height))
        path.addCurve(to: CGPoint(x: 0.7818*width, y: 0.40435*height), control1: CGPoint(x: 0.7985*width, y: 0.45715*height), control2: CGPoint(x: 0.7818*width, y: 0.4335*height))
        path.addCurve(to: CGPoint(x: 0.81925*width, y: 0.35135*height), control1: CGPoint(x: 0.7818*width, y: 0.3752*height), control2: CGPoint(x: 0.79855*width, y: 0.3513*height))
        path.addCurve(to: CGPoint(x: 0.95695*width, y: 0.35185*height), control1: CGPoint(x: 0.83395*width, y: 0.35135*height), control2: CGPoint(x: 0.94285*width, y: 0.3516*height))
        path.addCurve(to: CGPoint(x: 0.9689*width, y: 0.325*height), control1: CGPoint(x: 0.9705*width, y: 0.3521*height), control2: CGPoint(x: 0.9753*width, y: 0.3421*height))
        path.addCurve(to: CGPoint(x: 0.88915*width, y: 0.1885*height), control1: CGPoint(x: 0.949*width, y: 0.27175*height), control2: CGPoint(x: 0.92175*width, y: 0.227*height))
        path.addCurve(to: CGPoint(x: 0.70865*width, y: 0.0565*height), control1: CGPoint(x: 0.8359*width, y: 0.1256*height), control2: CGPoint(x: 0.7747*width, y: 0.08445*height))
        path.addCurve(to: CGPoint(x: 0.45375*width, y: 0.02455*height), control1: CGPoint(x: 0.62525*width, y: 0.0212*height), control2: CGPoint(x: 0.54*width, y: 0.01385*height))
        path.addCurve(to: CGPoint(x: 0.2241*width, y: 0.11355*height), control1: CGPoint(x: 0.3734*width, y: 0.0345*height), control2: CGPoint(x: 0.2966*width, y: 0.0633*height))
        path.addCurve(to: CGPoint(x: 0.07165*width, y: 0.27725*height), control1: CGPoint(x: 0.16575*width, y: 0.154*height), control2: CGPoint(x: 0.1135*width, y: 0.20615*height))
        path.addCurve(to: CGPoint(x: 0.0002*width, y: 0.54935*height), control1: CGPoint(x: 0.02535*width, y: 0.356*height), control2: CGPoint(x: -0.0026*width, y: 0.44465*height))
        path.addCurve(to: CGPoint(x: 0.02395*width, y: 0.59795*height), control1: CGPoint(x: 0.00075*width, y: 0.57045*height), control2: CGPoint(x: 0.00565*width, y: 0.58765*height))
        path.addCurve(to: CGPoint(x: 0.0949*width, y: 0.58255*height), control1: CGPoint(x: 0.04765*width, y: 0.61135*height), control2: CGPoint(x: 0.07505*width, y: 0.6049*height))
        path.addCurve(to: CGPoint(x: 0.1616*width, y: 0.5184*height), control1: CGPoint(x: 0.11605*width, y: 0.5588*height), control2: CGPoint(x: 0.13735*width, y: 0.5351*height))
        path.addCurve(to: CGPoint(x: 0.35805*width, y: 0.4584*height), control1: CGPoint(x: 0.224*width, y: 0.47535*height), control2: CGPoint(x: 0.2895*width, y: 0.45645*height))
        path.addCurve(to: CGPoint(x: 0.5189*width, y: 0.5097*height), control1: CGPoint(x: 0.41355*width, y: 0.46*height), control2: CGPoint(x: 0.4688*width, y: 0.4759*height))
        path.addCurve(to: CGPoint(x: 0.6202*width, y: 0.62945*height), control1: CGPoint(x: 0.55975*width, y: 0.53725*height), control2: CGPoint(x: 0.595*width, y: 0.57475*height))
        path.addCurve(to: CGPoint(x: 0.655*width, y: 0.656*height), control1: CGPoint(x: 0.6285*width, y: 0.64745*height), control2: CGPoint(x: 0.63945*width, y: 0.6568*height))
        path.addLine(to: CGPoint(x: 0.77565*width, y: 0.65565*height))
        path.closeSubpath()
        return path
    }
}
