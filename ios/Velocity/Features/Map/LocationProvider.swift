import CoreLocation
import Observation

// Live device location (MAP-6). Publishes the latest coordinate + heading; the map
// falls back to the Khamovniki center until the first fix arrives.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var coordinate: CLLocationCoordinate2D?
    var heading: CLLocationDirection?
    var authorized = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 8
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
            m.startUpdatingLocation()
        default:
            authorized = false
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if let c = locs.last?.coordinate { coordinate = c }
    }

    func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}
}
