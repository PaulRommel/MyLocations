//
//  LocationDetailsViewController.swift
//  MyLocations
//

import UIKit
import CoreLocation

// Вспомогательная ячейка со стилем .value1 — обычная UITableViewCell
// в .default не показывает detailTextLabel (то же ограничение UIKit,
// что мы уже встречали в Checklists/ListCell).
private final class ValueCell: UITableViewCell {
    static let reuseID = "ValueCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Ячейка с UITextView для описания локации.
private final class DescriptionCell: UITableViewCell {
    static let reuseID = "DescriptionCell"
    let textView = UITextView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        textView.font = .preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            textView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 88)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Экран "Tag Location" — показывает описание, категорию, координаты,
// адрес и дату для новой метки. В этой главе ничего ещё не сохраняется —
// это задача следующей главы книги.
class LocationDetailsViewController: UITableViewController {

    var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var placemark: CLPlacemark?

    var categoryName = "No Category"
    let date = Date()

    private enum Section: Int, CaseIterable {
        case description
        case category
        case info
        case date
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tag Location"

        tableView.register(DescriptionCell.self, forCellReuseIdentifier: DescriptionCell.reuseID)
        tableView.register(ValueCell.self, forCellReuseIdentifier: ValueCell.reuseID)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(done))
    }

    // MARK: - Actions
    @objc func cancel() {
        dismiss(animated: true)
    }

    @objc func done() {
        // Сохранение метки в хранилище — тема следующей главы книги.
        dismiss(animated: true)
    }

    // MARK: - Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .description: return 1
        case .category: return 1
        case .info: return placemark != nil ? 3 : 2   // Latitude, Longitude, (Address)
        case .date: return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .description:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: DescriptionCell.reuseID, for: indexPath) as! DescriptionCell
            return cell

        case .category:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ValueCell.reuseID, for: indexPath) as! ValueCell
            cell.textLabel?.text = "Category"
            cell.detailTextLabel?.text = categoryName
            cell.accessoryType = .disclosureIndicator
            return cell

        case .info:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ValueCell.reuseID, for: indexPath) as! ValueCell
            cell.selectionStyle = .none
            cell.accessoryType = .none

            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Latitude"
                cell.detailTextLabel?.text = String(format: "%.8f", coordinate.latitude)
            case 1:
                cell.textLabel?.text = "Longitude"
                cell.detailTextLabel?.text = String(format: "%.8f", coordinate.longitude)
            case 2:
                cell.textLabel?.text = "Address"
                cell.detailTextLabel?.text = placemark.map(string(from:))
                cell.detailTextLabel?.numberOfLines = 0
            default:
                break
            }
            return cell

        case .date:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ValueCell.reuseID, for: indexPath) as! ValueCell
            cell.selectionStyle = .none
            cell.textLabel?.text = "Date"
            cell.detailTextLabel?.text = format(date: date)
            return cell
        }
    }

    // MARK: - Table View Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if Section(rawValue: indexPath.section) == .category {
            let picker = CategoryPickerViewController()
            picker.selectedCategoryName = categoryName
            picker.delegate = self
            navigationController?.pushViewController(picker, animated: true)
        }
    }

    // MARK: - Helpers
    private func string(from placemark: CLPlacemark) -> String {
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

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - CategoryPickerViewControllerDelegate
extension LocationDetailsViewController: CategoryPickerViewControllerDelegate {
    func categoryPicker(_ picker: CategoryPickerViewController, didPick categoryName: String) {
        self.categoryName = categoryName
        tableView.reloadSections(IndexSet(integer: Section.category.rawValue), with: .automatic)
    }
}
