//
//  CategoryPickerViewController.swift
//  MyLocations
//

import UIKit

protocol CategoryPickerViewControllerDelegate: AnyObject {
    func categoryPicker(_ picker: CategoryPickerViewController, didPick categoryName: String)
}

// Экран выбора категории для метки локации — в книге это статический
// UITableViewController из сториборда, здесь строим список кодом.
class CategoryPickerViewController: UITableViewController {

    var selectedCategoryName = "No Category"
    weak var delegate: CategoryPickerViewControllerDelegate?

    // Тот же набор категорий, что в книге.
    let categories = [
        "No Category",
        "Apple Store",
        "Bar",
        "Bookstore",
        "Club",
        "Grocery Store",
        "Historic Building",
        "House",
        "Icecream Vendor",
        "Landmark",
        "Park"
    ]

    private let cellReuseID = "CategoryCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Category"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseID)
    }

    // MARK: - Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        categories.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseID, for: indexPath)
        let categoryName = categories[indexPath.row]

        cell.textLabel?.text = categoryName
        cell.accessoryType = (categoryName == selectedCategoryName) ? .checkmark : .none

        return cell
    }

    // MARK: - Table View Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let newCategoryName = categories[indexPath.row]
        selectedCategoryName = newCategoryName

        delegate?.categoryPicker(self, didPick: newCategoryName)
        navigationController?.popViewController(animated: true)
    }
}
