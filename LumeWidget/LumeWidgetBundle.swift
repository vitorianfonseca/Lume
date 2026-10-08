import SwiftUI
import WidgetKit

@main
struct LumeWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetDoMes()
        WidgetDosLimites()
        if #available(iOS 18.0, *) {
            ControloDeRegistoGeral()
            ControloDeRegisto()
        }
    }
}
