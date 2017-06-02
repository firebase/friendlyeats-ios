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
import SDWebImage
import Firestore
import Firebase
import FirebaseAuthUI

class RestaurantDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ReviewFormTableViewCellDelegate {

  var titleImageURL: URL?
  var restaurant: Restaurant?
  var restaurantReference: DocumentReference?

  var localCollection: LocalCollection<Review>!

  static func fromStoryboard(_ storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)) -> RestaurantDetailViewController {
    let controller = storyboard.instantiateViewController(withIdentifier: "RestaurantDetailViewController") as! RestaurantDetailViewController
    return controller
  }

  @IBOutlet var tableView: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.dataSource = self
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.estimatedRowHeight = 140

    let query = restaurantReference!.collection("ratings")
    localCollection = LocalCollection(query: query) { [unowned self] (changes) in
      if self.localCollection.count == 0 { return }
      var indexPaths: [IndexPath] = []

      // Only care about additions in this block, updating existing reviews probably not important
      // as there's no way to edit reviews.
      for addition in changes.filter({ $0.type == .added }) {
        let index = self.localCollection.index(of: addition.document)!
        let indexPath = IndexPath(row: index + 2, section: 0)
        indexPaths.append(indexPath)
      }
      self.tableView.insertRows(at: indexPaths, with: .automatic)
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    localCollection.listen()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    localCollection.stopListening()
  }

  // MARK: - UITableViewDataSource

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 2 + localCollection.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    switch indexPath.row {
    case 0:
      let cell = tableView.dequeueReusableCell(withIdentifier: "RestaurantTitleTableViewCell",
                                               for: indexPath) as! RestaurantTitleTableViewCell
      if let url = titleImageURL {
        cell.populateImage(url: url)
      }
      cell.populate(restaurant: restaurant!)
      return cell
    case 1:
      let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewFormTableViewCell",
                                               for: indexPath) as! ReviewFormTableViewCell
      cell.delegate = self
      return cell
    case _:
      let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewTableViewCell",
                                               for: indexPath) as! ReviewTableViewCell
      let review = localCollection[indexPath.row - 2]
      cell.populate(review: review)
      return cell
    }
  }

  // MARK: - ReviewFormTableViewCellDelegate

  func reviewFormCell(_ cell: ReviewFormTableViewCell, didSubmitFormWithReview review: Review) {
    guard let reference = restaurantReference, let restaurant = restaurant else { return }
    let reviewsCollection = reference.collection("ratings")
    let newReviewReference = reviewsCollection.document()
    let newAverage = (Float(restaurant.ratingCount) * restaurant.averageRating + Float(review.rating))
        / Float(restaurant.ratingCount + 1)

    let firestore = Firestore.firestore()
    firestore.runTransaction({ (transaction, errorPointer) -> Any? in
      transaction.setData(review.dictionary, forDocument: newReviewReference)
      transaction.updateData([
        "numRatings": restaurant.ratingCount + 1,
        "avgRating": newAverage
      ], forDocument: reference)
      return nil
    }) { (object, error) in
      if let error = error {
        print(error)
      }
    }
  }

}

class RestaurantTitleTableViewCell: UITableViewCell {

  @IBOutlet var nameLabel: UILabel! {
    didSet {
      nameLabel.textColor = .white
      nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
    }
  }

  @IBOutlet var starsView: ImmutableStarsView!

  @IBOutlet var categoryLabel: UILabel! {
    didSet {
      categoryLabel.textColor = .white
      categoryLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    }
  }
  @IBOutlet var cityLabel: UILabel! {
    didSet {
      cityLabel.textColor = .white
      cityLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    }
  }
  @IBOutlet var priceLabel: UILabel! {
    didSet {
      priceLabel.textColor = .white
      priceLabel.font = UIFont.preferredFont(forTextStyle: .body)
    }
  }
  @IBOutlet var titleImageView: UIImageView! {
    didSet {
      let gradient = CAGradientLayer()
      gradient.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
      gradient.startPoint = CGPoint(x: 0, y: 0)
      gradient.endPoint = CGPoint(x: 0, y: 1.4)
      gradient.opacity = 0.42
      gradient.frame = titleImageView.layer.bounds

      titleImageView.layer.addSublayer(gradient)
      titleImageView.contentMode = .scaleAspectFill
    }
  }

  func populateImage(url: URL) {
    titleImageView.sd_setImage(with: url)
  }

  func populate(restaurant: Restaurant) {
    nameLabel.text = restaurant.name
    starsView.rating = Int(restaurant.averageRating.rounded())
    categoryLabel.text = restaurant.category
    cityLabel.text = restaurant.city
    priceLabel.text = priceString(from: restaurant.price)
  }

}

protocol ReviewFormTableViewCellDelegate: NSObjectProtocol {
  func reviewFormCell(_ cell: ReviewFormTableViewCell, didSubmitFormWithReview review: Review)
}

class ReviewFormTableViewCell: UITableViewCell, UITextFieldDelegate {

  weak var delegate: ReviewFormTableViewCellDelegate?

  @IBOutlet var textField: UITextField! {
    didSet {
      textField.addTarget(self, action: #selector(textFieldTextDidChange(_:)), for: .editingChanged)
    }
  }
  @IBOutlet var ratingView: RatingView! {
    didSet {
      ratingView.addTarget(self, action: #selector(ratingDidChange(_:)), for: .valueChanged)
    }
  }
  @IBOutlet var submitButton: UIButton! {
    didSet {
      submitButton.isEnabled = false
    }
  }

  @objc func ratingDidChange(_ sender: Any) {
    updateSubmitButton()
  }

  func textFieldIsEmpty() -> Bool {
    guard let text = textField.text else { return true }
    return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func updateSubmitButton() {
    submitButton.isEnabled = (ratingView.rating != nil && !textFieldIsEmpty())
  }

  @IBAction func didTapSubmitButton(_ sender: Any) {
    let review = Review(rating: ratingView.rating!,
                        userID: Auth.auth().currentUser!.uid,
                        username: Auth.auth().currentUser?.displayName ?? "Anonymous",
                        text: textField.text!, date: Date())
    delegate?.reviewFormCell(self, didSubmitFormWithReview: review)
  }

  @objc func textFieldTextDidChange(_ sender: Any) {
    updateSubmitButton()
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    delegate = nil
  }

}

class ReviewTableViewCell: UITableViewCell {

  @IBOutlet var usernameLabel: UILabel! {
    didSet {
      usernameLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }
  }
  @IBOutlet var reviewContentsLabel: UILabel! {
    didSet {
      reviewContentsLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    }
  }
  @IBOutlet var starsView: ImmutableStarsView!

  func populate(review: Review) {
    usernameLabel.text = review.username
    reviewContentsLabel.text = review.text
    starsView.rating = review.rating
  }

}
