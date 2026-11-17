//
//  HudView.swift
//  MyLocations
//

import UIKit

// Глава 26 "Adding Polish": небольшой HUD (Heads Up Display), который
// на секунду показывает галочку и подпись после того, как пользователь
// нажимает Done на экране Tag Location — быстрая визуальная обратная
// связь вместо немедленного простого закрытия экрана.
final class HudView: UIView {

    var text = ""

    class func hud(inView view: UIView, animated: Bool) -> HudView {
        let hudView = HudView(frame: view.bounds)
        hudView.isOpaque = false

        view.addSubview(hudView)
        view.isUserInteractionEnabled = false

        hudView.show(animated: animated)
        return hudView
    }
//
    override func draw(_ rect: CGRect) {
        let boxWidth: CGFloat = 96
        let boxHeight: CGFloat = 96

        let boxRect = CGRect(
            x: round((bounds.size.width - boxWidth) / 2),
            y: round((bounds.size.height - boxHeight) / 2),
            width: boxWidth,
            height: boxHeight)

        let roundedRect = UIBezierPath(roundedRect: boxRect, cornerRadius: 10)
        UIColor(white: 0.3, alpha: 0.8).setFill()
        roundedRect.fill()

        drawCheckmark(in: boxRect)

        let attribs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.white
        ]
        let textSize = text.size(withAttributes: attribs)
        let textPoint = CGPoint(
            x: center.x - round(textSize.width / 2),
            y: boxRect.maxY - 24)
        text.draw(at: textPoint, withAttributes: attribs)
    }

    // Рисуем галочку сами, без отдельного файла-картинки в Assets —
    // так же, как книга рисует её на CoreGraphics-канвасе HUD'а.
    private func drawCheckmark(in boxRect: CGRect) {
        let checkWidth: CGFloat = 40
        let checkHeight: CGFloat = 32
        let originX = boxRect.midX - checkWidth / 2
        let originY = boxRect.minY + 16

        let path = UIBezierPath()
        path.move(to: CGPoint(x: originX, y: originY + checkHeight * 0.55))
        path.addLine(to: CGPoint(x: originX + checkWidth * 0.35, y: originY + checkHeight))
        path.addLine(to: CGPoint(x: originX + checkWidth, y: originY))

        path.lineWidth = 6
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        UIColor.white.setStroke()
        path.stroke()
    }

    func show(animated: Bool) {
        if animated {
            alpha = 0
            transform = CGAffineTransform(scaleX: 1.3, y: 1.3)

            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                options: [.curveEaseOut],
                animations: {
                    self.alpha = 1
                    self.transform = CGAffineTransform.identity
                })
        }
    }

    func hide() {
        superview?.isUserInteractionEnabled = true
        removeFromSuperview()
    }
}
