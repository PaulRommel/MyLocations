//
//  LocationsMapViewController.swift
//  MyLocations
//

import UIKit
import MapKit
import CoreData

// Глава 29 "Maps": третья вкладка — показывает все сохранённые локации
// булавками на карте. При появлении экрана карта сама подстраивается
// под все точки; кнопка "User" в навбаре центрирует её на пользователе,
// кнопка "Locations" переключает на вкладку со списком.
class LocationsMapViewController: UIViewController {

    var managedObjectContext: NSManagedObjectContext!

    private let mapView = MKMapView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Map"

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsUserLocation = true
        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Locations", style: .plain, target: self, action: #selector(showLocations))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "User", style: .plain, target: self, action: #selector(showUser))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Простой re-fetch при каждом появлении экрана — проще, чем тянуть
        // сюда ещё и NSFetchedResultsController ради того же списка,
        // который уже показывает вкладка Locations.
        updateLocations()
    }

    // MARK: - Actions
    @objc private func showUser() {
        let region = MKCoordinateRegion(
            center: mapView.userLocation.coordinate,
            latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(mapView.regionThatFits(region), animated: true)
    }

    // Кнопка "Locations" по книге не переключает вкладку, а приближает
    // карту так, чтобы были видны все сохранённые локации.
    @objc private func showLocations() {
        mapView.setRegion(region(for: mapView.annotations), animated: true)
    }

    // MARK: - Helpers
    private func updateLocations() {
        mapView.removeAnnotations(mapView.annotations)

        let fetchRequest = Location.fetchRequest()
        guard let locations = try? managedObjectContext.fetch(fetchRequest) else { return }

        mapView.addAnnotations(locations)

        if !locations.isEmpty {
            mapView.setRegion(region(for: mapView.annotations), animated: true)
        }
    }

    // Вычисляет регион карты, вмещающий все переданные аннотации, с
    // небольшим запасом по краям (extraSpace).
    private func region(for annotations: [MKAnnotation]) -> MKCoordinateRegion {
        guard !annotations.isEmpty else {
            return MKCoordinateRegion(
                center: mapView.userLocation.coordinate,
                latitudinalMeters: 1000, longitudinalMeters: 1000)
        }

        var topLeftCoord = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCoord = CLLocationCoordinate2D(latitude: 90, longitude: -180)

        for annotation in annotations {
            topLeftCoord.latitude = max(topLeftCoord.latitude, annotation.coordinate.latitude)
            topLeftCoord.longitude = min(topLeftCoord.longitude, annotation.coordinate.longitude)
            bottomRightCoord.latitude = min(bottomRightCoord.latitude, annotation.coordinate.latitude)
            bottomRightCoord.longitude = max(bottomRightCoord.longitude, annotation.coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: topLeftCoord.latitude - (topLeftCoord.latitude - bottomRightCoord.latitude) / 2,
            longitude: topLeftCoord.longitude - (topLeftCoord.longitude - bottomRightCoord.longitude) / 2)

        let extraSpace = 1.1
        let span = MKCoordinateSpan(
            latitudeDelta: abs(topLeftCoord.latitude - bottomRightCoord.latitude) * extraSpace,
            longitudeDelta: abs(topLeftCoord.longitude - bottomRightCoord.longitude) * extraSpace)

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - MKMapViewDelegate
extension LocationsMapViewController: MKMapViewDelegate {

    // Глава 29 "Make your own pins": стандартная красная булавка — через
    // современный MKMarkerAnnotationView (MKPinAnnotationView устарел в
    // iOS 16), но с тем же видом и callout-аксессуаром, что и в книге.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is Location else { return nil }

        let identifier = "Location"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            pinView!.isEnabled = true
            pinView!.canShowCallout = true
            pinView!.animatesWhenAdded = false
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        } else {
            pinView!.annotation = annotation
        }

        return pinView
    }

    func mapView(
        _ mapView: MKMapView,
        annotationView view: MKAnnotationView,
        calloutAccessoryControlTapped control: UIControl
    ) {
        // Экран редактирования локации появится в одной из следующих глав.
    }
}
