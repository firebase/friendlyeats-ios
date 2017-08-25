//
//  Copyright (c) 2016 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import Firestore
import SDWebImage

func priceString(from price: Int) -> String {
  let priceText: String
  switch price {
  case 1:
    priceText = "$"
  case 2:
    priceText = "$$"
  case 3:
    priceText = "$$$"
  case _:
    priceText = ""
  }

  return priceText
}

private func randomImageURL() -> URL {
  let randomImageNumber = Int(arc4random_uniform(22)) + 1
  let randomImageURLString =
  "https://storage.googleapis.com/firestorequickstarts.appspot.com/food_\(randomImageNumber).png"
  return URL(string: randomImageURLString)!
}

class RestaurantsTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

  @IBOutlet var tableView: UITableView!
  @IBOutlet var activeFiltersStackView: UIStackView!
  @IBOutlet var stackViewHeightConstraint: NSLayoutConstraint!

  @IBOutlet var cityFilterLabel: UILabel!
  @IBOutlet var categoryFilterLabel: UILabel!
  @IBOutlet var priceFilterLabel: UILabel!

  var localCollection: LocalCollection<Restaurant>!

  var query: Query? {
    didSet {
      guard let query = query else { return }
      if let collection = localCollection {
        collection.stopListening()
      }
      localCollection = LocalCollection(query: query) { [unowned self] changes in
        self.tableView.reloadData()
      }
    }
  }

  fileprivate func baseQuery() -> Query {
    return Firestore.firestore().collection("restaurants").limit(to: 50)
  }

  lazy private var filters: (navigationController: UINavigationController,
                             filtersController: FiltersViewController) = {
    return FiltersViewController.fromStoryboard(delegate: self)
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Red bar with white color
    navigationController?.navigationBar.barTintColor =
      UIColor.init(red: 211/255, green: 47/255, blue: 47/255, alpha: 1.0)
    navigationController?.navigationBar.isTranslucent = false
    navigationController?.navigationBar.titleTextAttributes =
      [ NSForegroundColorAttributeName: UIColor.white ]

    tableView.dataSource = self
    tableView.delegate = self
    query = baseQuery()
    stackViewHeightConstraint.constant = 0
    activeFiltersStackView.isHidden = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    localCollection.listen()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let auth = FUIAuth.defaultAuthUI()!
    if auth.auth?.currentUser == nil {
      auth.providers = []
      present(auth.authViewController(), animated: true, completion: nil)
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    localCollection.stopListening()
  }

  @IBAction func didTapPopulateButton(_ sender: Any) {
    let words = ["Bar", "Fire", "Grill", "Drive Thru", "Place", "Best", "Spot", "Prime", "Eatin'"]
    let cities = ["San Francisco", "Mountain View", "Palo Alto", "Redwood City", "San Mateo",
                  "Cupertino", "San Jose", "Daly City", "Millbrae", "Belmont"]
    let categories = ["Pizza", "Burgers", "American", "Dim Sum", "Pho", "Mexican", "Hot Pot"]

    for _ in 0 ..< 20 {
      let randomIndexes = (Int(arc4random_uniform(UInt32(words.count))),
                           Int(arc4random_uniform(UInt32(words.count))))
      let name = words[randomIndexes.0] + " " + words[randomIndexes.1]
      let category = categories[Int(arc4random_uniform(UInt32(categories.count)))]
      let city = cities[Int(arc4random_uniform(UInt32(cities.count)))]
      let price = Int(arc4random_uniform(3)) + 1
      let ratingCount = 0
      let averageRating: Float = 0

      let restaurant = Restaurant(
        name: name,
        category: category,
        city: city,
        price: price,
        ratingCount: ratingCount,
        averageRating: averageRating
      )

      Firestore.firestore().collection("restaurants").addDocument(data: restaurant.dictionary)
    }
  }

  @IBAction func didTapClearButton(_ sender: Any) {
    filters.filtersController.clearFilters()
    controller(filters.filtersController, didSelectCategory: nil, city: nil, price: nil, sortBy: nil)
  }

  @IBAction func didTapFilterButton(_ sender: Any) {
    present(filters.navigationController, animated: true, completion: nil)
  }

  // MARK: - UITableViewDataSource

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "RestaurantTableViewCell",
                                             for: indexPath) as! RestaurantTableViewCell
    let restaurant = localCollection[indexPath.row]
    cell.populate(restaurant: restaurant)
    return cell
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return localCollection.count
  }

  // MARK: - UITableViewDelegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let controller = RestaurantDetailViewController.fromStoryboard()
    controller.titleImageURL = randomImageURL()
    controller.restaurant = localCollection[indexPath.row]
    controller.restaurantReference = localCollection.documents[indexPath.row].reference
    self.navigationController?.pushViewController(controller, animated: true)
  }

}

extension RestaurantsTableViewController: FiltersViewControllerDelegate {

  func controller(_ controller: FiltersViewController,
                  didSelectCategory category: String?,
                  city: String?,
                  price: Int?,
                  sortBy: String?) {
    var filtered = baseQuery()

    if let category = category, !category.isEmpty {
      filtered = filtered.whereField("category", isEqualTo: category)

      categoryFilterLabel.text = category
      categoryFilterLabel.isHidden = false
    } else {
      categoryFilterLabel.isHidden = true
    }

    if let city = city, !city.isEmpty {
      filtered = filtered.whereField("city", isEqualTo: city)

      cityFilterLabel.text = city
      cityFilterLabel.isHidden = false
    } else {
      cityFilterLabel.isHidden = true
    }

    if let price = price {
      filtered = filtered.whereField("price", isEqualTo: price)

      priceFilterLabel.text = priceString(from: price)
      priceFilterLabel.isHidden = false
    } else {
      priceFilterLabel.isHidden = true
    }

    // TODO: refactor this method, so we're not using view state to check filter logic.
    if categoryFilterLabel.isHidden && priceFilterLabel.isHidden && cityFilterLabel.isHidden {
      stackViewHeightConstraint.constant = 0
      activeFiltersStackView.isHidden = true
    } else {
      stackViewHeightConstraint.constant = 44
      activeFiltersStackView.isHidden = false
    }

    if let sortBy = sortBy, !sortBy.isEmpty {
      filtered = filtered.order(by: sortBy)
    }

    self.query = filtered
    localCollection.listen()
  }

}

class RestaurantTableViewCell: UITableViewCell {

  @IBOutlet private var thumbnailView: UIImageView!

  @IBOutlet private var nameLabel: UILabel!

  @IBOutlet var starsView: ImmutableStarsView!

  @IBOutlet private var cityLabel: UILabel!

  @IBOutlet private var categoryLabel: UILabel!

  @IBOutlet private var priceLabel: UILabel!

  func populate(restaurant: Restaurant) {
    nameLabel.text = restaurant.name
    cityLabel.text = restaurant.city
    categoryLabel.text = restaurant.category
    starsView.rating = Int(restaurant.averageRating.rounded())

    let imageURL = randomImageURL()
    thumbnailView.sd_setImage(with: imageURL)

    priceLabel.text = priceString(from: restaurant.price)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    thumbnailView.sd_cancelCurrentImageLoad()
  }

}
