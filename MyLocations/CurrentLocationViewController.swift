//
//  CurrentLocationViewController.swift
//  MyLocations
//

import UIKit
import CoreLocation
import CoreData

class CurrentLocationViewController: UIViewController {

    // Глава 27 "Pass the context": получен из SceneDelegate, передаётся
    // далее в LocationDetailsViewController при открытии Tag Location.
    var managedObjectContext: NSManagedObjectContext!

    // В книге это @IBOutlet, привязанные к сториборду. Без сториборда
    // создаём эти элементы сами и добавляем их в иерархию view вручную.
    let messageLabel = UILabel()
    let latitudeLabel = UILabel()
    let longitudeLabel = UILabel()
    let addressLabel = UILabel()
    let tagButton = UIButton(type: .system)
    let getButton = UIButton(type: .system)

    // Статические подписи "Latitude:" / "Longitude:" — в сториборде это
    // просто текстовые лейблы без outlet'ов.
    private let latitudeTitleLabel = UILabel()
    private let longitudeTitleLabel = UILabel()

    // MARK: - Core Location
    let locationManager = CLLocationManager()
    var location: CLLocation?

    var updatingLocation = false
    var lastLocationError: Error?

    // MARK: - Reverse Geocoding (глава 23)
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?

    // Таймер принудительной остановки — если точной фиксации GPS не
    // случилось за разумное время, не ждём бесконечно (глава 23: Handle
    // GPS errors).
    var timer: Timer?

    // Кэшируем статус авторизации из делегатского колбэка вместо того,
    // чтобы спрашивать locationManager.authorizationStatus синхронно —
    // Apple предупреждает, что такой синхронный вызов может подвиснуть
    // главный поток, пока система ещё не определила статус.
    private var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupViews()
        setupConstraints()

        // Не читаем authorizationStatus напрямую — делегат сам вызовет
        // locationManagerDidChangeAuthorization с актуальным статусом
        // сразу после назначения.
        locationManager.delegate = self

        updateLabels()
        configureGetButton()
    }

    // MARK: - UI
    private func setupViews() {
        messageLabel.text = "Tap 'Get My Location' to Start"
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.textAlignment = .center   // Alignment attribute = centered
        messageLabel.numberOfLines = 0

        latitudeTitleLabel.text = "Latitude:"
        latitudeTitleLabel.font = .preferredFont(forTextStyle: .body)

        latitudeLabel.text = ""
        latitudeLabel.font = .preferredFont(forTextStyle: .body)
        latitudeLabel.textAlignment = .right   // right-aligned, как в книге

        longitudeTitleLabel.text = "Longitude:"
        longitudeTitleLabel.font = .preferredFont(forTextStyle: .body)

        longitudeLabel.text = ""
        longitudeLabel.font = .preferredFont(forTextStyle: .body)
        longitudeLabel.textAlignment = .right   // right-aligned, как в книге

        addressLabel.text = ""
        addressLabel.font = .preferredFont(forTextStyle: .body)
        addressLabel.textAlignment = .center
        addressLabel.numberOfLines = 0

        tagButton.setTitle("Tag Location", for: .normal)
        tagButton.isHidden = true   // показываем только когда есть координаты
        tagButton.addTarget(self, action: #selector(tagLocation), for: .touchUpInside)

        getButton.setTitle("Get My Location", for: .normal)
        getButton.addTarget(self, action: #selector(getLocation), for: .touchUpInside)

        for label in [messageLabel, latitudeTitleLabel, latitudeLabel,
                      longitudeTitleLabel, longitudeLabel, addressLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
        }

        // По книге обе кнопки — каждая на всю ширину экрана (left/right по
        // 16pt), одна под другой, а не в ряд пополам.
        for button in [tagButton, getButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(button)
        }
    }

    // MARK: - Layout
    private func setupConstraints() {
        let guide = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Message Label — на всю ширину экрана, pinned к Safe Area
            // слева/сверху/справа. Эти относительные констрейнты (вместо
            // жёстких координат/размеров) сами по себе работают одинаково
            // корректно на любом размере экрана — глава 23 "Support
            // different screen sizes" для программной верстки уже решена.
            messageLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),

            // "Latitude:" — left/top/right(к value)/bottom.
            // Отступ сверху от Message Label — 24pt (как в книге).
            latitudeTitleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            latitudeTitleLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),

            // latitudeLabel — top/right/bottom выровнены по строке "Latitude:",
            // leading не закреплён жёстко (значение прижато вправо).
            latitudeLabel.topAnchor.constraint(equalTo: latitudeTitleLabel.topAnchor),
            latitudeLabel.bottomAnchor.constraint(equalTo: latitudeTitleLabel.bottomAnchor),
            latitudeLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            latitudeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: latitudeTitleLabel.trailingAnchor, constant: 8),

            // "Longitude:" — bottom "Latitude:" служит top для этой строки.
            longitudeTitleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            longitudeTitleLabel.topAnchor.constraint(equalTo: latitudeTitleLabel.bottomAnchor, constant: 8),

            // longitudeLabel — bottom/right выровнены по "Longitude:",
            // top не нужен (высота берётся из контента).
            longitudeLabel.bottomAnchor.constraint(equalTo: longitudeTitleLabel.bottomAnchor),
            longitudeLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            longitudeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: longitudeTitleLabel.trailingAnchor, constant: 8),

            // Address Label — top: та же дистанция (24pt), что и сверху у
            // группы широта/долгота. bottom: тоже 24pt — расстояние до
            // кнопки Tag Location.
            addressLabel.topAnchor.constraint(equalTo: longitudeTitleLabel.bottomAnchor, constant: 24),
            addressLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            addressLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            addressLabel.bottomAnchor.constraint(equalTo: tagButton.topAnchor, constant: -24),

            // Tag Location — на всю ширину (left/right 16pt); top задаётся
            // через addressLabel.bottom выше (это одна и та же связь).
            tagButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            tagButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            // Get My Location — на всю ширину, прижата к низу Safe Area
            // (минимум 16pt от низа экрана, над Tab Bar).
            getButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            getButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            getButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Actions
    @objc func getLocation() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            showLocationServicesDeniedAlert()
            updateLabels()
            return
        }

        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil
            placemark = nil
            lastGeocodingError = nil
            startLocationManager()
        }

        updateLabels()
        configureGetButton()
    }

    // Глава 25: открываем экран "Tag Location" с уже полученными
    // координатами/адресом. Пока ничего не сохраняем — это тема
    // следующей главы.
    @objc func tagLocation() {
        guard let location = location else { return }

        let controller = LocationDetailsViewController()
        controller.coordinate = location.coordinate
        controller.placemark = placemark
        controller.managedObjectContext = managedObjectContext
        controller.delegate = self

        let navigationController = UINavigationController(rootViewController: controller)
        present(navigationController, animated: true)
    }

    // MARK: - Helper Methods
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(
            title: "Location Services Disabled",
            message: "Please enable location services for this app in Settings.",
            preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)

        present(alert, animated: true)
    }

    func updateLabels() {
        if let location = location {
            latitudeLabel.text = String(format: "%.8f", location.coordinate.latitude)
            longitudeLabel.text = String(format: "%.8f", location.coordinate.longitude)
            tagButton.isHidden = false
            messageLabel.text = ""

            // Reverse geocoding — показываем адрес, как только он готов,
            // либо промежуточное состояние поиска/ошибки.
            if let placemark = placemark {
                addressLabel.text = string(from: placemark)
            } else if performingReverseGeocoding {
                addressLabel.text = "Searching for Address..."
            } else if lastGeocodingError != nil {
                addressLabel.text = "Error Finding Address"
            } else {
                addressLabel.text = "No Address Found"
            }
        } else {
            latitudeLabel.text = ""
            longitudeLabel.text = ""
            addressLabel.text = ""
            tagButton.isHidden = true

            let statusMessage: String
            // Разрешение именно этому приложению запрещено пользователем —
            // это самая частая причина, и authorizationStatus уже знает
            // об этом из делегата, не дожидаясь ошибки от startUpdatingLocation.
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                statusMessage = "Location Services Disabled"
            } else if let error = lastLocationError as NSError? {
                if error.domain == kCLErrorDomain && error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = "Tap 'Get My Location' to Start"
            }

            messageLabel.text = statusMessage
        }
    }

    // Собирает читаемый адрес из CLPlacemark — улица и дом на первой
    // строке, город/регион/индекс на второй.
    func string(from placemark: CLPlacemark) -> String {
        var line1 = ""
        if let subThoroughfare = placemark.subThoroughfare {
            line1 += subThoroughfare + " "
        }
        if let thoroughfare = placemark.thoroughfare {
            line1 += thoroughfare
        }

        var line2 = ""
        if let locality = placemark.locality {
            line2 += locality + " "
        }
        if let administrativeArea = placemark.administrativeArea {
            line2 += administrativeArea + " "
        }
        if let postalCode = placemark.postalCode {
            line2 += postalCode
        }

        return line1 + "\n" + line2
    }

    func configureGetButton() {
        let title = updatingLocation ? "Stop" : "Get My Location"
        getButton.setTitle(title, for: .normal)
    }

    func startLocationManager() {
        guard CLLocationManager.locationServicesEnabled() else { return }

        // delegate уже назначен в viewDidLoad — он должен быть на месте
        // постоянно, чтобы ловить locationManagerDidChangeAuthorization
        // даже когда обновление координат не идёт.
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
        updatingLocation = true

        // Если точная фиксация не случится за 60 секунд — прекращаем
        // попытки и показываем ошибку, а не ждём бесконечно (книга,
        // глава 23: Handle GPS errors).
        timer = Timer.scheduledTimer(timeInterval: 60, target: self,
                                     selector: #selector(didTimeOut), userInfo: nil, repeats: false)
    }

    func stopLocationManager() {
        guard updatingLocation else { return }

        locationManager.stopUpdatingLocation()
        updatingLocation = false

        timer?.invalidate()
        timer = nil
    }

    @objc func didTimeOut() {
        print("*** Time out")

        if location == nil {
            stopLocationManager()
            lastLocationError = NSError(domain: "MyLocationsErrorDomain", code: 1, userInfo: nil)
            updateLabels()
            configureGetButton()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension CurrentLocationViewController: CLLocationManagerDelegate {

    // Вызывается при запуске (сообщает текущий статус) и при каждом
    // изменении разрешения. Именно здесь, а не в getLocation(), безопасно
    // читать authorizationStatus.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            stopLocationManager()
            lastLocationError = nil
        }

        updateLabels()
        configureGetButton()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError \(error.localizedDescription)")

        // Временная ошибка "не можем определить позицию прямо сейчас" —
        // не повод прекращать попытки.
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            return
        }

        lastLocationError = error
        stopLocationManager()
        updateLabels()
        configureGetButton()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        print("didUpdateLocations \(newLocation)")

        // Отбрасываем устаревшие или заведомо некорректные измерения.
        if newLocation.timestamp.timeIntervalSinceNow < -5 { return }
        if newLocation.horizontalAccuracy < 0 { return }

        // Расстояние между новым и предыдущим измерением — нужно, чтобы
        // понять, действительно ли устройство ещё двигается/уточняет
        // позицию, или это один и тот же результат, который можно
        // зафиксировать принудительно.
        var distance = CLLocationDistance(Double.greatestFiniteMagnitude)
        if let location = location {
            distance = newLocation.distance(from: location)
        }

        if location == nil || location!.horizontalAccuracy > newLocation.horizontalAccuracy {
            // Нашли более точное измерение, чем было раньше.
            lastLocationError = nil
            location = newLocation

            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy {
                print("*** We're done!")
                stopLocationManager()
                configureGetButton()
            }

            updateLabels()

            // Запускаем reverse geocoding только если он ещё не выполняется —
            // иначе один и тот же запрос дублировался бы на каждое
            // обновление координат.
            if !performingReverseGeocoding {
                print("*** Going to geocode")
                performingReverseGeocoding = true

                geocoder.reverseGeocodeLocation(newLocation) { [weak self] placemarks, error in
                    guard let self = self else { return }

                    self.lastGeocodingError = error
                    if error == nil, let p = placemarks, !p.isEmpty {
                        self.placemark = p.last
                    } else {
                        self.placemark = nil
                    }

                    self.performingReverseGeocoding = false
                    self.updateLabels()
                }
            }
        } else if distance < 1 {
            // Координаты почти не меняются уже некоторое время — вероятно,
            // точнее уже не станет. Принудительно останавливаемся, чтобы
            // не ждать desiredAccuracy бесконечно (книга: Improve GPS results).
            let timeInterval = newLocation.timestamp.timeIntervalSince(location!.timestamp)
            if timeInterval > 10 {
                print("*** Force done!")
                stopLocationManager()
                updateLabels()
                configureGetButton()
            }
        }
    }
}

// MARK: - LocationDetailsViewControllerDelegate
// Глава 26 "Adding Polish": после нажатия Done на экране Tag Location
// сначала закрываем модальный экран, а затем — уже на этом экране —
// показываем короткий HUD с галочкой ("Handle the navigation").
extension CurrentLocationViewController: LocationDetailsViewControllerDelegate {
    func locationDetailsViewControllerDidFinish(_ controller: LocationDetailsViewController) {
        dismiss(animated: true) { [weak self] in
            self?.showTaggedHUD()
        }
    }

    private func showTaggedHUD() {
        guard let hostView = navigationController?.view ?? view else { return }

        let hudView = HudView.hud(inView: hostView, animated: true)
        hudView.text = "Tagged"

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            hudView.hide()
        }
    }
}
