//
//  LocationManager.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    @Published var locationAccessGranted: Bool = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationAccessGranted = true
        } else {
            locationAccessGranted = false
        }
    }
}
