//
//  LocationsViewController.swift
//  MyLocations
//

import UIKit
import CoreData
import CoreLocation

// Ячейка списка сохранённых локаций: заголовок — описание (или
// заглушка, если оно пустое), подзаголовок — адрес/координаты вместе
// с категорией.
private final class LocationCell: UITableViewCell {
    static let reuseID = "LocationCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(for location: Location) {
        let description = location.locationDescription ?? ""
        textLabel?.text = description.isEmpty ? "(No Description)" : description

        if let placemarkData = location.placemarkData,
           let placemark = try? NSKeyedUnarchiver.unarchivedObject(
               ofClass: CLPlacemark.self, from: placemarkData) {
            var line = ""
            if let subThoroughfare = placemark.subThoroughfare {
                line += subThoroughfare + " "
            }
            if let thoroughfare = placemark.thoroughfare {
                line += thoroughfare
            }
            detailTextLabel?.text = "\(line) (\(location.category ?? "No Category"))"
        } else {
            detailTextLabel?.text = String(
                format: "Lat: %.8f, Long: %.8f (%@)",
                location.latitude, location.longitude, location.category ?? "No Category")
        }
    }
}

// Глава 28 "The Locations Tab": показывает все сохранённые локации,
// сгруппированные по категории, во второй вкладке приложения.
class LocationsViewController: UITableViewController {

    var managedObjectContext: NSManagedObjectContext!

    private lazy var fetchedResultsController: NSFetchedResultsController<Location> = {
        let fetchRequest = Location.fetchRequest()

        let sortByCategory = NSSortDescriptor(key: "category", ascending: true)
        let sortByDate = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [sortByCategory, sortByDate]
        fetchRequest.fetchBatchSize = 20

        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: "category",
            cacheName: nil)
        controller.delegate = self
        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Locations"
        navigationItem.rightBarButtonItem = editButtonItem

        tableView.register(LocationCell.self, forCellReuseIdentifier: LocationCell.reuseID)
        performFetch()
    }

    deinit {
        fetchedResultsController.delegate = nil
    }

    private func performFetch() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalCoreDataError(error)
        }
    }

    // MARK: - Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        fetchedResultsController.sections?[section].name
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: LocationCell.reuseID, for: indexPath) as! LocationCell
        let location = fetchedResultsController.object(at: indexPath)
        cell.configure(for: location)
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }

        let location = fetchedResultsController.object(at: indexPath)
        managedObjectContext.delete(location)

        do {
            try managedObjectContext.save()
        } catch {
            fatalCoreDataError(error)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension LocationsViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            if let indexPath = indexPath,
               let cell = tableView.cellForRow(at: indexPath) as? LocationCell {
                let location = controller.object(at: indexPath) as! Location
                cell.configure(for: location)
            }
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .fade)
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        @unknown default:
            break
        }
    }

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange sectionInfo: NSFetchedResultsSectionInfo,
        atSectionIndex sectionIndex: Int,
        for type: NSFetchedResultsChangeType
    ) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
