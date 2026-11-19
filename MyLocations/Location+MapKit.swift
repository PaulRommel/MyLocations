//
//  Location+MapKit.swift
//  MyLocations
//

import MapKit

// Глава 29 "Maps": делаем Location самостоятельной аннотацией для
// MKMapView — координаты берём из latitude/longitude, заголовок из
// описания (как в списке локаций), подзаголовок — из категории.
extension Location: MKAnnotation {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var title: String? {
        let description = locationDescription ?? ""
        return description.isEmpty ? "(No Description)" : description
    }

    public var subtitle: String? {
        category
    }
}
