//
//  WidgetBundle.swift
//  Widget
//
//  Created by Karl Koch on 14/11/2024.
//

import WidgetKit
import SwiftUI

@main
struct SkateWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        QuickGlanceWidget()
        LatestSessionWidget()
        SessionStatsWidget()
        LearnNextWidget()
        JournalControlWidget()
    }
}
