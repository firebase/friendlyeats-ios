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

import Foundation
import Firebase

struct Restaurant {

  var name: String
  var category: String // Could become an enum
  var city: String
  var price: Int // from 1-3; could also be an enum
  var ratingCount: Int // numRatings
  var averageRating: Float

  var dictionary: [String: Any] {
    return [
      "name": name,
      "category": category,
      "city": city,
      "price": price,
      "numRatings": ratingCount,
      "avgRating": averageRating,
    ]
  }

}

extension Restaurant: DocumentSerializable {

  static let cities = [
    "Albuquerque",
    "Arlington",
    "Atlanta",
    "Austin",
    "Baltimore",
    "Boston",
    "Charlotte",
    "Chicago",
    "Cleveland",
    "Colorado Springs",
    "Columbus",
    "Dallas",
    "Denver",
    "Detroit",
    "El Paso",
    "Fort Worth",
    "Fresno",
    "Houston",
    "Indianapolis",
    "Jacksonville",
    "Kansas City",
    "Las Vegas",
    "Long Beach",
    "Los Angeles",
    "Louisville",
    "Memphis",
    "Mesa",
    "Miami",
    "Milwaukee",
    "Nashville",
    "New York",
    "Oakland",
    "Oklahoma",
    "Omaha",
    "Philadelphia",
    "Phoenix",
    "Portland",
    "Raleigh",
    "Sacramento",
    "San Antonio",
    "San Diego",
    "San Francisco",
    "San Jose",
    "Tucson",
    "Tulsa",
    "Virginia Beach",
    "Washington"
  ]

  static let categories = [
    "Brunch", "Burgers", "Coffee", "Deli", "Dim Sum", "Indian", "Italian",
    "Mediterranean", "Mexican", "Pizza", "Ramen", "Sushi"
  ]

  init?(dictionary: [String : Any]) {
    guard let name = dictionary["name"] as? String,
        let category = dictionary["category"] as? String,
        let city = dictionary["city"] as? String,
        let price = dictionary["price"] as? Int,
        let ratingCount = dictionary["numRatings"] as? Int,
        let averageRating = dictionary["avgRating"] as? Float else { return nil }

    self.init(name: name,
              category: category,
              city: city,
              price: price,
              ratingCount: ratingCount,
              averageRating: averageRating)
  }

}

struct Review {

  var rating: Int // Can also be enum
  var userID: String
  var username: String
  var text: String
  var date: Date

  var dictionary: [String: Any] {
    return [
      "rating": rating,
      "userId": userID,
      "userName": username,
      "text": text,
      "timestamp": Timestamp(date: date)
    ]
  }

}

extension Review: DocumentSerializable {

  init?(dictionary: [String : Any]) {
    guard let rating = dictionary["rating"] as? Int,
        let userID = dictionary["userId"] as? String,
        let username = dictionary["userName"] as? String,
        let text = dictionary["text"] as? String,
        let date = dictionary["timestamp"] as? Timestamp else { return nil }
    
    self.init(rating: rating, userID: userID, username: username, text: text, date: date.dateValue())
  }

}
