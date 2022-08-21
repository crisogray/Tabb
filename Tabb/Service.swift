//
//  Service.swift
//  Tabb
//
//  Created by Ben Gray on 17/04/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import Alamofire
import FBSDKLoginKit
import TwitterKit
import GoogleSignIn
import SwiftyJSON
import OAuthSwift
import RealmSwift
import AsyncDisplayKit
import Whisper

var accounts = [String : Account]()

let services: [Service.Type] = [twitter.self, youtube.self, instagram.self, facebook.self, reddit.self]
let postCount = 20

var servicesWithAccounts: [Service.Type] {
	return services.sorted(by: {$0.position < $1.position}).flatMap {
		return $0.hasAccount ? $0 : nil
	}
}

func service(_ rawValue: String) -> Service.Type {
	return ["Twitter" : twitter.self, "YouTube" : youtube.self, "Instagram" : instagram.self, "Facebook" : facebook.self, "Reddit" : reddit.self][rawValue]!
}

protocol Service {
	
	static var rawValue: String {get}
	static var consumerKey: String {get}
	static var consumerSecret: String {get}
	static var baseUrl: String {get}
	static var colour: UIColor {get}
	static var enabledTypes: [String] {get}
	static var iosHook: String {get}
	static var webHook: String {get}
	static var position: Int {get}
	
	static func createOauth() -> OAuthSwift
	static func auth(viewController: UIViewController, callback: @escaping (Account?) -> Void)
	static func signOut()
	
	static func user(from json: JSON) -> User
	static func getUsers(endpoint: String, parameters: [String : Any]?, callback: @escaping (_ users: [User]) -> Void)
	static func getFollowing(callback: @escaping ([User]) -> Void)
	static func searchForUsers(query: String, callback: @escaping ([User]) -> Void)
	
	static func getUser(from id: String, callback: @escaping (User?) -> Void)
	static func getTrending(callback: @escaping ([Any]) -> Void)
	
	static func post(from json: JSON) -> Post
	static func comment(from json: JSON) -> Post
	static func getChannelPosts(from users: [String], paging: [String : String]?, progress: @escaping (Float) -> Void, callback: @escaping ([Post], [String : String]?) -> Void)
	static func getPosts(from searchTerm: String, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void)
	static func getComments(forPost: Post, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void)
	
}

extension Service {
	
	static var image: UIImage {
		return UIImage(named: rawValue + " 24pt")!
	}
	
	static var oauthVersion: OAuthSwiftCredential.Version {
		return self is twitter.Type ? .oauth1 : .oauth2
	}
	
	static var hasAccount: Bool {
		return account != nil
	}
	
	static var account: Account? {
		if let account = accounts[rawValue] {
			return account
		} else if let dictionary = UserDefaults.standard.dictionary(forKey: rawValue) as? [String : String] {
			let account = Account(dictionary: dictionary, service: self)
			accounts[rawValue] = account
			return account
		}
		return nil
	}
	
	static func signIn(viewController: UIViewController, callback: @escaping (Account?) -> Void) {
		auth(viewController: viewController) { account in
			if let account = account {
				account.save()
			} else {
				// Handle Error
			}
			callback(account)
		}
	}
	
	static func removeAccount() {
		UserDefaults.standard.removeObject(forKey: rawValue)
		UserDefaults.standard.synchronize()
		accounts[rawValue] = nil
		signOut()
	}
	
	static func performRequest(endpoint: String, parameters: [String : Any] = [:], callback: @escaping (JSON?, @escaping (String) -> Void) -> Void) {
		if let account = self.account, let url = URL(string: baseUrl + endpoint) {
			let headers = account.oauth.client.credential.makeHeaders(url, method: .GET, parameters: parameters)
			SessionManager.default.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers).responseString { response in
				let errorFunc: ((String) -> Void) = { message in
					DispatchQueue.main.async {
						if let nav = (UIApplication.shared.keyWindow?.rootViewController as? ContainerViewController)?.navController, nav.visibleViewController == nav.viewControllers.first {
							Whisper.show(whisper: Message(title: message, textColor: .white, backgroundColor: colour, images: nil), to: nav)
						} else {
							Whisper.show(whistle: Murmur(title: message, backgroundColor: colour, titleColor: .white, font: .systemFont(ofSize: 14), action: nil))
						}
					}
				}
				DispatchQueue.global(qos: .userInitiated).async {
					if let string = response.result.value, response.error == nil, response.result.isSuccess {
						callback(JSON(parseJSON: string), errorFunc)
					} else {
						if let error = response.error {
							print(error)
						}
						callback(nil, errorFunc)
					}
				}
			}
		}
	}
	
}

class twitter: Service {
	
	static var rawValue = "Twitter"
	static var consumerKey = "si5SQOPqQfh8UmkdDcnjEDlfU"
	static var consumerSecret = "Lk1xz7iVUKq5TKvGIjdPgVNISKtOOVNDaxaqKJ0mrmxHQq0yx4"
	static var baseUrl = "https://api.twitter.com/1.1/"
	static var colour = UIColor(red: 29 / 255, green: 161 / 255, blue: 242 / 255, alpha: 1)
	static var enabledTypes = ["url", "hashtag", "mention"]
	static var iosHook: String = "twitter://status?id="
	static var webHook: String = "https://twitter.com/statuses/"
	static var position: Int = 0
	
	static func createOauth() -> OAuthSwift {
		return OAuth1Swift(consumerKey: consumerKey,
		                   consumerSecret: consumerSecret,
		                   requestTokenUrl: baseUrl + "oauth/request_token",
		                   authorizeUrl: baseUrl + "oauth/authenticate",
		                   accessTokenUrl: baseUrl + "oauth/access_token")
	}
	
	static func auth(viewController: UIViewController, callback: @escaping (Account?) -> Void) {
		Twitter.sharedInstance().logIn { session, error in
			if let session = session, error == nil {
				let oauth = self.createOauth()
				oauth.client.credential.oauthToken = session.authToken
				oauth.client.credential.oauthTokenSecret = session.authTokenSecret
				callback(Account(id: session.userID, name: session.userName, service: self, oauth: oauth))
			} else {
				callback(nil)
			}
		}
	}
	
	static func signOut() {
		let store = Twitter.sharedInstance().sessionStore
		if let userID = store.session()?.userID {
			store.logOutUserID(userID)
		}
	}
	
	static func follow() {
		if let account = self.account, let url = URL(string: baseUrl + "friendships/create.json") {
			let parameters = ["screen_name" : "crisogray"], headers = account.oauth.client.credential.makeHeaders(url, method: .POST, parameters: parameters)
			SessionManager.default.request(url, method: .post, parameters: parameters, encoding: URLEncoding.queryString, headers: headers).responseJSON { response in }
		}
	}
	
	static func user(from json: JSON) -> User {
		return User(value: ["id" : json["id_str"].stringValue,
		                    "name" : json["name"].stringValue,
		                    "username" : json["screen_name"].stringValue,
		                    "picture" : json["profile_image_url_https"].stringValue.replacingOccurrences(of: "_normal", with: ""),
		                    "service" : rawValue,
		                    "verified" : json["verified"].boolValue])
	}
	
	static func getUsers(endpoint: String, parameters: [String : Any]?, callback: @escaping ([User]) -> Void) {
		var params = parameters ?? [:]
		params["count"] = "200"
		params["include_user_entities"] = "false"
		params["skip_status"] = "true"
		performRequest(endpoint: endpoint, parameters: params) { json, errorFunc in
			var users = [User]()
			if let items = json?.array {
				items.forEach {users.append(user(from: $0))}
			} else if let json = json, let items = json["users"].array {
				items.forEach {users.append(user(from: $0))}
			} else {
				errorFunc("There was an error fetching \(rawValue) users")
			}
			callback(users)
		}
	}
	
	static func getFollowing(callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "friends/list.json", parameters: nil, callback: callback)
	}
	
	static func searchForUsers(query: String, callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "users/search.json", parameters: ["q" : query, "include_entities" : "false"], callback: callback)
	}
	
	static func post(from json: JSON) -> Post {
		let tweeter = user(from: json["user"])
		if json["retweeted_status"].dictionary != nil {
			let retweet = post(from: json["retweeted_status"])
			retweet.retweeter = tweeter
			return retweet
		}
		var quote: Post?
		if json["quoted_status"].dictionary != nil {
			quote = post(from: json["quoted_status"])
		}
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		var media: [Media]?
		if let m = json["extended_entities"]["media"].array {
			media = [Media]()
			for item in m {
				var contentUrl: String?, id = item["id"].stringValue, type = item["type"].stringValue
				if let variants = item["video_info"]["variants"].array {
					var bitURL = [Int : String]()
					for variant in variants where variant["content_type"].stringValue == "video/mp4" {
						bitURL[variant["bitrate"].intValue] = variant["url"].stringValue
					}
					contentUrl = bitURL.sorted {return $0.key > $1.key}.first!.value
				} else if let url = json["entities"]["urls"].array?.first?["display_url"].string, url.contains("youtu.be") {
					id = url.components(separatedBy: "/").last!
					type = "video"
				}
				media!.append(Media(["id" : id, "type" : type, "imageUrl" : item["media_url_https"].stringValue,
				                     "scale" : CGFloat(item["sizes"]["large"]["h"].floatValue / item["sizes"]["large"]["w"].floatValue),
				                     "contentUrl" : contentUrl, "service" : twitter.rawValue]))
			}
		}
		var text = (json["full_text"].string ?? json["text"].stringValue)
		.replacingOccurrences(of: "&amp;", with: "&")
		.replacingOccurrences(of: "&lt;", with: "<")
		.replacingOccurrences(of: "&gt;", with: ">")
		var nsstring = text as NSString
		do {
			let regex = try NSRegularExpression(pattern: regexes["url"]!, options: [])
			var matches = regex.matches(in: text, options: .init(), range: NSRange(location: 0, length: nsstring.length))
			if let match = matches.last, quote != nil {
				text = nsstring.replacingCharacters(in: match.range, with: "")
				nsstring = text as NSString
				matches = regex.matches(in: text, options: .init(), range: NSRange(location: 0, length: nsstring.length))
			}
			if let match = matches.last, media != nil {
				text = nsstring.replacingCharacters(in: match.range, with: "")
			}
		} catch {}
		return Post(["id" : json["id_str"].stringValue, "user" : tweeter,
		              "date" : dateFormatter.date(from: json["created_at"].stringValue),
		              "text" : text, "media" : media,
		              "inReplyToUserId" : json["in_reply_to_user_id_str"].string,
		              "inReplyToScreenName" : json["in_reply_to_screen_name"].string,
		              "inReplyToStatusId" : json["in_reply_to_status_id_str"].string,
		              "quote" : quote, "counts" : ["likes" : json["favorite_count"].intValue,
		                                           "retweets" : json["retweet_count"].intValue]])
	}
	
	static func getUser(from id: String, callback: @escaping (User?) -> Void) {
		performRequest(endpoint: "users/lookup.json", parameters: ["user_id" : id]) { json, _ in
			if let json = json, let item = json.array?.first {
				callback(user(from: item))
			} else {
				callback(nil)
			}
		}
	}
	
	static func getPost(from id: String, callback: @escaping ([Post]) -> Void) {
		performRequest(endpoint: "statuses/lookup.json", parameters: ["id" : id]) { json, errorFunc in
			if let json = json, let item = json.array?.first {
				callback([post(from: item)])
			} else {
				errorFunc("There was an error fetching \(rawValue) post.")
				callback([Post]())
			}
		}
	}
	
	static func comment(from json: JSON) -> Post {
		return post(from: json)
	}
	
	static func getComments(forPost: Post, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var posts = [Post](), newPaging = [String : String](), parameters = ["since_id" : forPost.id, "count" : "200", "tweet_mode" : "extended", "q" : "to:\(forPost.user.username!)", "result_type" : "recent"]
			if let maxId = paging?[forPost.id] {
				parameters["max_id"] = maxId
			}
			performRequest(endpoint: "search/tweets.json", parameters: parameters, callback: { json, errorFunc in
				if let json = json, let items = json["statuses"].array {
					for item in items where item["in_reply_to_status_id_str"].string == forPost.id {
						let p = post(from: item)
						if !posts.contains(where: {$0.id == p.id}) {
							posts.append(p)
						}
						if item == items.last {
							newPaging[forPost.id] = p.id
						}
					}
				} else {
					errorFunc("There was an error fetching \(rawValue) replies.")
				}
				callback(posts, newPaging)
			})
		}
	}
	
	static func getPosts(from searchTerm: String, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var posts = [Post](), newPaging = [String : String](), parameters = ["q" : searchTerm, "count" : "200", "tweet_mode" : "extended", "result_type" : "mixed"]
			if let maxId = paging?[searchTerm] {
				parameters["max_id"] = maxId
			}
			performRequest(endpoint: "search/tweets.json", parameters: parameters, callback: { json, errorFunc in
				if let json = json, let items = json["statuses"].array {
					for item in items {
						let p = post(from: item)
						if !posts.contains(where: {$0.id == p.id}) {
							posts.append(p)
						}
						if item == items.last {
							newPaging[searchTerm] = p.id
						}
					}
				} else {
					errorFunc("There was an error fetching \(rawValue) posts.")
				}
				callback(posts, newPaging)
			})
		}
	}
	
	static func getChannelPosts(from users: [String], paging: [String : String]?, progress: @escaping (Float) -> Void, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var posts = [Post](), completed = 0, newPaging = [String : String](), date = Date(timeIntervalSince1970: 0), hasErrored = false
			if !users.isEmpty {
				for user in users {
					var parameters = ["user_id" : user, "count" : users.count == 1 ? "200" : "\(postCount)", "tweet_mode" : "extended"]
					if let maxId = paging?[user] {
						parameters["max_id"] = maxId
					}
					performRequest(endpoint: "statuses/user_timeline.json", parameters: parameters, callback: { json, errorFunc in
						completed += 1
						progress(Float(completed) / Float(users.count))
						if let json = json, let items = json.array {
							for item in items {
								let p = post(from: item)
								DispatchQueue.main.sync {
									if !posts.contains(where: {$0.id == p.id}) {
										posts.append(p)
									}
									if let index = items.index(where: {$0 == item}), index == items.count - 1, index == postCount - 1 {
										newPaging[user] = p.id
										if p.date > date {
											date = p.date
										}
									}
								}
							}
						} else if !hasErrored {
							hasErrored = true
							errorFunc("There was an error fetching \(rawValue) posts.")
						}
						if completed == users.count {
							completed += 1
							newPaging["date"] = "\(date.timeIntervalSince1970)"
							callback(posts, newPaging)
						}
					})
				}
			} else {
				callback(posts, nil)
			}
		}
	}
	
	static func getTrending(callback: @escaping ([Any]) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			performRequest(endpoint: "trends/place.json", parameters: ["id" : "23424977"]) { json, errorFunc in
				var hashtags = [String]()
				if let json = json, let items = json.array?.first?["trends"].array {
					for item in items {
						hashtags.append(item["name"].stringValue)
					}
				} else {
					errorFunc("There was an error fetching trending hashtags")
				}
				print(rawValue, "Callback")
				callback(hashtags)
			}
		}
	}
	
}

class youtube: Service {
	
	static var rawValue = "YouTube"
	static var consumerKey = "563812178253-bbegsrf38os4ee0ms895dvjedjqph87g.apps.googleusercontent.com"
	static var consumerSecret = ""
	static var baseUrl = "https://www.googleapis.com/youtube/v3/"
	static var colour = UIColor(red: 229 / 255, green: 45 / 255, blue: 39 / 255, alpha: 1)
	static var enabledTypes = ["url"]
	static var iosHook: String = "youtube://www.youtube.com/v/"
	static var webHook: String = "https://www.youtube.com/watch?v="
	static var position: Int = 1

	static func createOauth() -> OAuthSwift {
		return OAuth2Swift(
			consumerKey: consumerKey, consumerSecret: consumerSecret,
			authorizeUrl: "https://accounts.google.com/o/oauth2/v2/auth",
			accessTokenUrl: "https://www.googleapis.com/oauth2/v4/token",
			responseType: "code"
		)
	}
	
	static func auth(viewController: UIViewController, callback: @escaping (Account?) -> Void) {
		let googleSignIn = GoogleSignIn()
		googleSignIn.modalPresentationStyle = .overFullScreen
		GIDSignIn.sharedInstance().delegate = googleSignIn
		GIDSignIn.sharedInstance().uiDelegate = googleSignIn
		googleSignIn.callback = { user in
			googleSignIn.dismiss(animated: false) {
				if let user = user {
					let oauth = self.createOauth()
					oauth.client.credential.oauthToken = user.authentication.accessToken
					oauth.client.credential.oauthRefreshToken = user.authentication.refreshToken
					callback(Account(id: user.userID, name: user.profile.name, service: self, oauth: oauth))
				} else {
					callback(nil)
				}
			}
		}
		viewController.present(googleSignIn, animated: false) {
			GIDSignIn.sharedInstance().signIn()
		}
	}
	
	static func signOut() {
		GIDSignIn.sharedInstance().signOut()
		GIDSignIn.sharedInstance().disconnect()
	}
	
	static func user(from json: JSON) -> User {
		return User(value: [
			"id" : json["snippet"]["resourceId"]["channelId"].string ?? json["id"]["channelId"].stringValue,
			"name" : json["snippet"]["title"].stringValue,
			"picture" : json["snippet"]["thumbnails"]["default"]["url"].stringValue,
			"service" : rawValue
		])
	}
	
	static func getUsers(endpoint: String, parameters: [String : Any]?, callback: @escaping ([User]) -> Void) {
		var params = parameters ?? [:]
		params["part"] = "snippet"
		params["maxResults"] = 50
		performRequest(endpoint: endpoint, parameters: params) { json, errorFunc in
			var users = [User]()
			if let json = json, let items = json["items"].array {
				for item in items {
					users.append(user(from: item))
				}
			} else {
				errorFunc("There was an error fetching \(rawValue) channels.")
			}
			callback(users)
		}
	}
	
	static func getFollowing(callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "subscriptions", parameters: ["mine" : "true"], callback: callback)
	}
	
	static func searchForUsers(query: String, callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "search", parameters: ["q" : query, "type" : "channel"], callback: callback)
	}
	
	static func post(from json: JSON) -> Post {
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		dateFormatter.timeZone = TimeZone(identifier: "UTC")
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
		let thumbnail = json["thumbnails"].dictionaryValue.sorted(by: {$0.1["width"].intValue > $1.1["width"].intValue}).first!
		return Post(["id" : json["resourceId"]["videoId"].stringValue,
		                     "date" : dateFormatter.date(from: json["publishedAt"].stringValue),
		                     "text" : json["title"].stringValue,
		                     "user" : User(value: [
								"id" : json["channelId"].stringValue,
								"name" : json["channelTitle"].stringValue,
								"service" : rawValue]),
		                     "media" : [Media([
								"id" : json["resourceId"]["videoId"].stringValue,
								"type" : "video",
								"imageUrl" : thumbnail.1["url"].stringValue,
								"service" : youtube.rawValue])]])
	}
	
	static func comment(from json: JSON) -> Post {
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		dateFormatter.timeZone = TimeZone(identifier: "UTC")
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
		return Post(["id" : json["id"].stringValue,
		             "date" : dateFormatter.date(from: json["snippet"]["publishedAt"].stringValue),
		             "text" : json["snippet"]["textOriginal"].stringValue,
		             "user" : User(value: [
						"id" : json["snippet"]["authorChannelId"].stringValue,
						"name" : json["snippet"]["authorDisplayName"].stringValue,
						"picture" : json["snippet"]["authorProfileImageUrl"].stringValue,
						"service" : rawValue])])
	}
	
	static func getComments(forPost: Post, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var posts = [Post](), parameters = ["videoId" : forPost.id, "part" : "snippet", "maxResults" : "100", "key" : consumerKey, "order" : "relevance"]
			performRequest(endpoint: "commentThreads", parameters: parameters, callback: { json, errorFunc in
				if let json = json, let items = json["items"].array {
					for item in items {
						posts.append(comment(from: item["snippet"]["topLevelComment"]))
					}
				} else {
					errorFunc("There was an error fetching \(rawValue) comments.")
				}
				callback(posts, nil)
			})
		}
	}
	
	static func getUser(from id: String, callback: @escaping (User?) -> Void) {
		getUsers(endpoint: "channels", parameters: ["id" : id]) { users in
			if let user = users.first {
				user.id = id
				callback(user)
			} else {
				callback(nil)
			}
		}
	}
	
	static func getPosts(from searchTerm: String, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		callback([Post](), nil)
	}
	
	static func getChannelPosts(from users: [String], paging: [String : String]?, progress: @escaping (Float) -> Void, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			let userArrays = users.chunked(by: 20)
			var playlists = [String](), playlistCompleted = 0, posts = [Post](), newPaging = [String : String](), date = Date(timeIntervalSince1970: 0), hasErrored = false
			if !userArrays.isEmpty {
				for array in userArrays {
					var string = ""
					for u in array {
						string += u + ","
					}
					string.remove(at: string.index(before: string.endIndex))
					performRequest(endpoint: "channels", parameters: ["part" : "contentDetails", "id" : string], callback: { json, errorFunc in
						if let json = json, let items = json["items"].array {
							playlists += items.map { return $0["contentDetails"]["relatedPlaylists"]["uploads"].stringValue }
						} else if !hasErrored {
							hasErrored = true
							errorFunc("There was an error fetching \(rawValue) videos.")
						}
						playlistCompleted += 1
						progress(Float(playlistCompleted) / Float(users.count + userArrays.count))
						if playlistCompleted == userArrays.count {
							var completed = 0
							if !playlists.isEmpty {
								for playlist in playlists {
									var parameters = ["part" : "snippet", "playlistId" : playlist, "maxResults" : users.count == 1 ? "50" : "\(postCount)"]
									if let pageToken = paging?[playlist] {
										parameters["pageToken"] = pageToken
									}
									performRequest(endpoint: "playlistItems", parameters: parameters, callback: { json, errorFunc in
										completed += 1
										progress(Float(playlistCompleted + completed) / Float(playlists.count + userArrays.count))
										if let json = json, let items = json["items"].array {
											if let pageToken = json["nextPageToken"].string {
												newPaging[playlist] = pageToken
											}
											for item in items {
												let p = post(from: item["snippet"])
												DispatchQueue.main.sync {
													if p.id != "" {
														posts.append(p)
													}
													if let index = items.index(where: {$0 == item}), index == items.count - 1, index == postCount - 1, p.date > date {
														date = p.date
													}
												}
											}
										} else if !hasErrored {
											hasErrored = true
											errorFunc("There was an error fetching \(rawValue) videos.")
										}
										if completed == playlists.count {
											completed += 1 // Safeguard
											print("Here")
											newPaging["date"] = "\(date.timeIntervalSince1970)"
											callback(posts, newPaging)
										}
									})
								}
							} else {
								callback(posts, nil)
							}
						}
					})
				}
			} else {
				callback(posts, nil)
			}
		}
	}
	
	static func getTrending(callback: @escaping ([Any]) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			performRequest(endpoint: "videos", parameters: ["maxResults" : "50", "chart" : "mostPopular", "part" : "snippet"]) { json, errorFunc in
				var posts = [Post]()
				if let json = json, let items = json["items"].array {
					for item in items {
						let p = post(from: item["snippet"]), id = item["id"].stringValue
						p.id = id
						if let media = p.media?.first {
							media.id = id
						}
						getUser(from: p.user.id, callback: { user in
							if let user = user {
								user.id = p.user.id
								p.user = user
							}
							DispatchQueue.main.sync {
								posts.append(p)
							}
							if posts.count == items.count {
								callback(posts)
							}
						})
					}
				} else {
					errorFunc("There was an error fetching trending \(rawValue) videos.")
					callback(posts)
				}
			}
		}
	}
	
}

class instagram: Service {
	
	static var rawValue = "Instagram"
	static var consumerKey = "93b66e5027a14d8a83cd2627e8d36351"
	static var consumerSecret = "8c40f0d3b5a242d49bdec72fbc62ce03"
	static var baseUrl = "https://www.instagram.com/"
	static var colour = UIColor.black
	static var enabledTypes = ["url", /*"hashtag",*/ "mention"]
	static var iosHook: String = "instagram://media?id="
	static var webHook: String = "https://instagram.com/p/"
	static var position: Int = 2

	static func createOauth() -> OAuthSwift {
		return OAuth2Swift(consumerKey: consumerKey,
						   consumerSecret: consumerSecret,
						   authorizeUrl: "https://api.instagram.com/oauth/authorize",
						   accessTokenUrl: "https://api.instagram.com/oauth/access_token",
						   responseType: "code")
	}
	
	static func auth(viewController: UIViewController, callback: @escaping (Account?) -> Void) {
		let oauth = self.createOauth() as! OAuth2Swift, safariViewController = SafariURLHandler(viewController: viewController, oauthSwift: oauth)
		oauth.authorizeURLHandler = safariViewController
		oauth.allowMissingStateCheck = true
		oauth.authorize(withCallbackURL: "https://tinyurl.com/n6n3gnh", scope: "basic+public_content+follower_list", state: "", success: {
			credential, response, parameters in
			oauth.client.credential.oauthToken = credential.oauthToken
			let json = JSON(parameters), u = json["user"]
			callback(Account(id: u["id"].stringValue, name: u["username"].stringValue, service: self, oauth: oauth))
		}) { error in
			callback(nil)
		}
	}
	
	static func signOut() {}
	
	static func user(from json: JSON) -> User {
		let name = json["full_name"].string, username = json["username"].stringValue
		return User(value: [
			"id" : json["pk"].string ?? json["id"].stringValue,
			"name" : name == nil || name == "" ? username : name,
			"username" : name != nil && name != username && name != "" ? username : nil,
			"picture" : json["profile_pic_url"].string ?? json["profile_picture"].stringValue,
			"verified" : json["is_verified"].bool ?? false,
			"service" : rawValue
		])
	}
	
	static func getUsers(endpoint: String, parameters: [String : Any]?, callback: @escaping ([User]) -> Void) {
		//params["access_token"] = account!.oauth.client.credential.oauthToken
		performRequest(endpoint: endpoint, parameters: [:]) { json, errorFunc in
			var users = [User]()
			if let json = json, let items = json["users"].array {
				items.forEach { users.append(user(from: $0["user"])) }
			} else if let json = json, json["user"]["id"].string != nil {
				users = [user(from: json["user"])]
			} else if endpoint != "" {
				print(json)
				errorFunc("There was an error fetching \(rawValue) users")
			}
			callback(users)
		}
	}
	
	static func getFollowing(callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "", parameters: nil, callback: callback)
//		if let account = instagram.account {
//			getUsers(endpoint: "graphql/query/?query_id=17874545323001329&id=\(account.id)&first=40", parameters: nil, callback: callback)
//		} else {
//			callback([User]())
//		}
	}
	
	static func searchForUsers(query: String, callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "web/search/topsearch/?query=\(query.replacingOccurrences(of: " ", with: "+"))", parameters: nil, callback: callback)
	}
	
	static func getUser(from id: String, callback: @escaping (User?) -> Void) {
		getUsers(endpoint: id + "/?__a=1", parameters: nil) { users in callback(users.first) }
	}
	
	static func post(from json: JSON) -> Post {
		let image = json["display_src"].stringValue, dimensions = json["dimensions"]
		let media = Media(["id" : json["id"].stringValue, "type" : "photo", "imageUrl" : image,
						   "scale" : CGFloat(dimensions["height"].floatValue / dimensions["width"].floatValue), "service" : instagram.rawValue])
		if let contentUrl = json["videos"]["standard_resolution"]["url"].string {
			media.type = "video"
			media.contentUrl = contentUrl
		}
		return Post(["id" : json["id"].stringValue,
					 "shortcode" : json["code"].stringValue,
		             "user" : user(from: json["user"]),
		             "date" : Date(timeIntervalSince1970: json["date"].doubleValue),
		             "text" : json["caption"].string, "media" : [media], "counts" : ["likes" : json["likes"]["count"].intValue,
		                                                                                     "comments" : json["comments"]["count"].intValue]])
	}
	
	static func comment(from json: JSON) -> Post {
		return Post(["id" : json["id"].stringValue,
		             "user" : user(from: json["owner"]),
		             "date" : Date(timeIntervalSince1970: json["created_at"].doubleValue),
		             "text" : json["text"].string])
	}
	
	static func getComments(forPost: Post, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			if let accessToken = account?.oauth.client.credential.oauthToken {
				dump(forPost)
				var posts = [Post](), parameters = ["access_token" : accessToken]
				performRequest(endpoint: "graphql/query/?query_id=17852405266163336&shortcode=\(forPost.shortcode ?? forPost.id)&first=50", parameters: parameters, callback: { json, errorFunc in
					print(json)
					if let json = json, let items = json["data"]["shortcode_media"]["edge_media_to_comment"]["edges"].array {
						items.forEach { posts.append(comment(from: $0["node"])) }
					} else {
						errorFunc("There was an error fetching \(rawValue) comments.")
					}
					callback(posts, nil)
				})
			}
		}
	}
	
	static func getPosts(from searchTerm: String, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			if let accessToken = account?.oauth.client.credential.oauthToken {
				var posts = [Post](), newPaging = [String : String](), parameters = ["count" : "200", "access_token" : accessToken]
				if let maxId = paging?[searchTerm] {
					parameters["max_tag_id"] = maxId
				}
				let term = searchTerm.replacingOccurrences(of: "#", with: "")
				performRequest(endpoint: "explore/tags/\(term)/?__a=1", parameters: parameters, callback: { json, errorFunc in
					if let json = json, let items = json.array {
						for item in items {
							let p = post(from: item)
							posts.append(p)
							if item == items.last {
								newPaging[searchTerm] = p.id
							}
						}
					} else {
						errorFunc("There was an error fetching \(rawValue) posts.")
					}
					callback(posts, nil)
				})
			}
		}
	}
	
	static func getChannelPosts(from users: [String], paging: [String : String]?, progress: @escaping (Float) -> Void, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			if let accessToken = account?.oauth.client.credential.oauthToken {
				var completed = 0, posts = [Post](), newPaging = [String : String](), date = Date(timeIntervalSince1970: 0), hasErrored = false
				if !users.isEmpty {
					for user in users {
						if let maxId = paging?[user] {
//							 parameters["max_id"] = maxId
						}
						performRequest(endpoint: user + "/?__a=1", parameters: [:], callback: { json, errorFunc in
							if let json = json, let data = json["user"]["media"]["nodes"].array {
								print(data)
								if let maxId = json["pagination"]["next_max_id"].string {
									newPaging[user] = maxId
								}
								for item in data {
									let p = post(from: item)
									p.user = instagram.user(from: json["user"])
									posts.append(p)
									if let index = data.index(where: {$0 == item}), index == data.count - 1, index == postCount - 1, p.date > date {
										date = p.date
									}
								}
							} else if !hasErrored {
								hasErrored = true
								errorFunc("There was an error fetching \(rawValue) posts.")
							}
							completed += 1
							progress(Float(completed) / Float(users.count))
							if completed == users.count {
								completed += 1
								newPaging["date"] = "\(date.timeIntervalSince1970)"
								callback(posts, newPaging)
							}
						})
					}
				} else {
					callback(posts, nil)
				}
			}
		}
	}
	
	static func getTrending(callback: @escaping ([Any]) -> Void) {
		
	}
	
}

class facebook: Service {
	
	static var rawValue = "Facebook"
	static var consumerKey = "116567582169517"
	static var consumerSecret = "04f5749110fd177b17cedb375b7aee52"
	static var baseUrl = "https://graph.facebook.com/v2.8/"
	static var colour = UIColor(red: 59 / 255, green: 89 / 255, blue: 152 / 255, alpha: 1)
	static var enabledTypes = ["url"]
	static var iosHook: String = ""
	static var webHook: String = "https://facebook.com/"
	static let fields = "id,created_time,message,source,type,height,width,object_id,link,from.fields(id,name,username,picture,is_verified),attachments.fields(media),comments.summary(true).limit(0),likes.summary(true).limit(0)"
	static var position: Int = 3

	static func createOauth() -> OAuthSwift {
		return OAuth2Swift(consumerKey: consumerKey, consumerSecret: consumerSecret,
		                   authorizeUrl: "https://www.facebook.com/v2.9/dialog/oauth",
		                   accessTokenUrl: "https://graph.facebook.com/v2.9/oauth/access_token",
		                   responseType: "code")
	}
	
	static func auth(viewController: UIViewController, callback: @escaping (Account?) -> Void) {
		FBSDKLoginManager().logIn(withReadPermissions: ["user_likes"], from: viewController) { result, error in
			if let result = result, !result.isCancelled, error == nil {
				let oauth = self.createOauth()
				oauth.client.credential.oauthToken = result.token.tokenString
				FBSDKGraphRequest(graphPath: "me", parameters: ["fields" : "name"]).start(completionHandler: { connection, profile, error in
					if let profile = profile, error == nil {
						callback(Account(id: result.token.userID, name: JSON(profile)["name"].stringValue, service: self, oauth: oauth))
					} else {
						callback(nil)
					}
				})
			} else {
				callback(nil)
			}
		}
	}
	
	static func signOut() {
		FBSDKLoginManager().logOut()
	}
	
	static func user(from json: JSON) -> User {
		return User(value: ["id" : json["id"].stringValue,
		                    "name" : json["name"].stringValue,
		                    "username" : json["username"].string as Any?,
		                    "picture" : "https://graph.facebook.com/\(json["id"].stringValue)/picture?width=256&height=256",
							"service" : rawValue,
							"verified" : json["is_verified"].boolValue])
	}
	
	static func getUsers(endpoint: String, parameters: [String : Any]?, callback: @escaping ([User]) -> Void) {
		var params = parameters ?? [:]
		params["fields"] = "id,name,username,is_verified"
		params["limit"] = 50
		performRequest(endpoint: endpoint, parameters: params) { json, errorFunc in
			var users = [User]()
			if let json = json, let items = json["data"].array {
				for item in items {
					users.append(user(from: item))
				}
			} else {
				errorFunc("There was an error fetching \(rawValue) users.")
			}
			callback(users)
		}
	}
	
	static func getUser(from id: String, callback: @escaping (User?) -> Void) {
		performRequest(endpoint: id, parameters: ["fields" : "id,name,username,is_verified"]) { json, errorFunc in
			if let json = json {
				callback(user(from: json))
			} else {
				callback(nil)
			}
		}
	}
	
	static func getFollowing(callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "me/likes", parameters: nil, callback: callback)
	}
	
	static func searchForUsers(query: String, callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "search", parameters: ["q" : query, "type" : "page"], callback: callback)
	}
	
	static func post(from json: JSON) -> Post {
		let from = user(from: json["from"])
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		var media: [Media]?
		if let source = json["source"].string, json["type"].stringValue == "video",
			let data = json["attachments"]["data"].array?.first?["media"]["image"].dictionary {
			media = [Media(["id" : json["object_id"].stringValue,
			                "type" : "video",
			                "imageUrl" : data["src"]!.stringValue,
			                "scale" : CGFloat(data["height"]!.floatValue / data["width"]!.floatValue),
			                "contentUrl" : source, "service" : facebook.rawValue])]
		} else if let data = json["attachments"]["data"].array {
			media = [Media]()
			for item in data {
				media!.append(Media(["id" : json["object_id"].stringValue,
				                     "type" : "photo",
				                     "imageUrl" : item["media"]["image"]["src"].stringValue,
				                     "scale" : CGFloat(item["media"]["image"]["height"].floatValue / item["media"]["image"]["width"].floatValue),
				                     "contentUrl" : nil, "service" : facebook.rawValue]))
			}
		}
		var counts: [String : Int?]?
		if json["likes"]["summary"]["total_count"].int != nil {
			counts = ["likes" : json["likes"]["summary"]["total_count"].int, "comments" : json["comments"]["summary"]["total_count"].int]
		}
		return Post(["id" : json["id"].stringValue, "user" : from,
		             "date" : dateFormatter.date(from: json["created_time"].stringValue),
		             "text" : json["message"].stringValue, "media" : media, "counts" : counts])
	}
	
	static func comment(from json: JSON) -> Post {
		return post(from: json)
	}
	
	static func getComments(forPost: Post, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var posts = [Post]() // Paging
			let fields = "id,created_time,message,source,type,height,width,object_id,link,from.fields(id,name,picture),attachments.fields(media)"
			let parameters = ["total_count" : "100", "fields" : fields]
			performRequest(endpoint: forPost.id + "/comments", parameters: parameters, callback: { json, errorFunc in
				if let json = json, let items = json["data"].array {
					for item in items {
						posts.append(comment(from: item))
					}
				} else {
					errorFunc("There was an error fetching \(rawValue) comments.")
				}
				callback(posts, nil)
			})
		}
	}
	
	static func getPosts(from searchTerm: String, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		callback([Post](), nil)
	}
	
	static func getChannelPosts(from users: [String], paging: [String : String]?, progress: @escaping (Float) -> Void, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var completed = 0, posts = [Post](), newPaging = [String : String](), date = Date(timeIntervalSince1970: 0), hasErrored = false
			if !users.isEmpty {
				for user in users {
					var endpoint = user + "/posts", parameters = ["fields" : fields, "limit" : users.count == 1 ? "100" : "\(postCount)"]
					if let page = paging?[user] {
						endpoint = String(page.utf8)
						parameters = [:]
					}
					performRequest(endpoint: endpoint, parameters: parameters, callback: { json, errorFunc in
						if let json = json, let items = json["data"].array {
							if let next = json["paging"]["next"].string?.removingPercentEncoding {
								newPaging[user] = next.replacingOccurrences(of: baseUrl, with: "")
							}
							for item in items {
								let p = post(from: item)
								posts.append(p)
								if let index = items.index(where: {$0 == item}), index == items.count - 1, index == postCount - 1, p.date > date {
									date = p.date
								}
							}
						} else if !hasErrored {
							hasErrored = true
							errorFunc("There was an error fetching \(rawValue) posts.")
						}
						completed += 1
						progress(Float(completed) / Float(users.count))
						if completed == users.count {
							completed += 1
							newPaging["date"] = "\(date.timeIntervalSince1970)"
							callback(posts, newPaging)
						}
					})
				}
			} else {
				callback(posts, nil)
			}
		}
	}
	
	static func getTrending(callback: @escaping ([Any]) -> Void) {
		
	}
	
}

class reddit: Service {
	
	static var rawValue: String = "Reddit"
	static var consumerKey: String = "Ti3SGbALqtA6dw"
	static var consumerSecret: String = ""
	static var baseUrl: String = "https://oauth.reddit.com/"
	static var colour: UIColor = UIColor(red: 1, green: 69 / 255, blue: 0, alpha: 1)
	static var enabledTypes: [String] = ["url"]
	static var iosHook: String = ""
	static var webHook: String = "https://reddit.com/r/"
	static var position: Int = 4

	static func createOauth() -> OAuthSwift {
		let oauth = OAuth2Swift(consumerKey: consumerKey, consumerSecret: consumerSecret, authorizeUrl: "https://www.reddit.com/api/v1/authorize.compact?duration=permanent",
		                   accessTokenUrl: "https://www.reddit.com/api/v1/access_token", responseType: "code")
		oauth.accessTokenBasicAuthentification = true
		return oauth
	}
	
	static func auth(viewController: UIViewController, callback: @escaping (Account?) -> Void) {
		let oauth = self.createOauth() as! OAuth2Swift, safariViewController = SafariURLHandler(viewController: viewController, oauthSwift: oauth)
		oauth.authorizeURLHandler = safariViewController
		oauth.authorize(withCallbackURL: "tabb://oauth-callback", scope: "identity,mysubreddits,read", state: "tabb", success: {
			credential, _, parameters in
			oauth.client.credential.oauthToken = credential.oauthToken
			oauth.client.credential.oauthRefreshToken = credential.oauthRefreshToken
			Account(id: "", name: "", service: self, oauth: oauth).save()
			performRequest(endpoint: "api/v1/me.json", callback: { json, errorFunc in
				DispatchQueue.main.async {
					if let json = json {
						callback(Account(id: json["id"].stringValue, name: json["name"].stringValue, service: self, oauth: oauth))
					} else {
						errorFunc("There was an error fetching \(rawValue) user.")
						callback(nil)
					}
				}
			})
		}) { error in
			callback(nil)
		}
	}
	
	static func signOut() {}
	
	static func user(from json: JSON) -> User {
		return User(value: ["id" : json["display_name"].stringValue, "name" : "r/\(json["display_name"].stringValue)", "service" : rawValue, "picture" : json["icon_img"].stringValue])
	}
	
	static func getUsers(endpoint: String, parameters: [String : Any]?, callback: @escaping ([User]) -> Void) {
		var params = parameters ?? [String : Any]()
		params["limit"] = "30"
		performRequest(endpoint: endpoint, parameters: params) { json, errorFunc in
			var users = [User]()
			if let json = json, let items = json["data"]["children"].array {
				for item in items {
					users.append(user(from: item["data"]))
				}
			} else {
				errorFunc("There was an error fetching \(rawValue) users.")
			}
			callback(users)
		}
	}
	
	static func getUser(from id: String, callback: @escaping (User?) -> Void) {
		performRequest(endpoint: "r/\(id)/about.json", parameters: [:]) { json, errorFunc in
			if let json = json {
				callback(user(from: json["data"]))
			} else {
				callback(nil)
			}
		}
	}
	
	static func getFollowing(callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "subreddits/mine/subscriber", parameters: nil, callback: callback)
	}
	
	static func searchForUsers(query: String, callback: @escaping ([User]) -> Void) {
		getUsers(endpoint: "subreddits/search", parameters: ["q" : query], callback: callback)
	}
	
	static func post(from json: JSON) -> Post {
		var media: [Media]?, link: String?
		if let imageUrl = json["preview"]["images"][0]["source"]["url"].string?.replacingOccurrences(of: "amp;", with: "") {
			let height = json["preview"]["images"][0]["source"]["height"].floatValue, width = json["preview"]["images"][0]["source"]["width"].floatValue, scale = CGFloat(height / width)
			if json["media"]["type"].string == "youtube.com" {
				media =  [Media(["id" : json["media"]["oembed"]["thumbnail_url"].stringValue.replacingOccurrences(of: "https://i.ytimg.com/vi/", with: "").replacingOccurrences(of: "/hqdefault.jpg", with: ""),
				                 "imageUrl" : imageUrl, "contentUrl" : nil, "type" : "video", "service" : rawValue])]
			} else if let mp4 = json["preview"]["images"][0]["variants"]["mp4"]["source"]["url"].string {
				media =  [Media(["imageUrl" : imageUrl, "contentUrl" : mp4.replacingOccurrences(of: "amp;", with: ""), "type" : "animated_gif", "service" : rawValue, "scale" : scale])]
			} else if let url = json["url"].string, json["post_hint"].string == "rich:video" {
				media =  [Media(["imageUrl" : imageUrl, "contentUrl" : url, "type" : "video", "service" : rawValue, "scale" : scale])]
			} else if let url = json["url"].string, json["post_hint"].string == "link" {
				media = [Media(["imageUrl" : imageUrl, "contentUrl" : url, "type" : "link", "service" : rawValue, "scale" : scale])]
			} else {
				media = [Media(["imageUrl" : imageUrl, "type" : "photo", "service" : rawValue, "scale" : scale])]
			}
		} else {
			link = json["url"].stringValue
		}
		let text = json["title"].stringValue.replacingOccurrences(of: "&amp;", with: "&")
			.replacingOccurrences(of: "&lt;", with: "<")
			.replacingOccurrences(of: "&gt;", with: ">")
		return RedditLink(["id" : json["id"].stringValue,
		                   "date" : Date(timeIntervalSince1970: json["created_utc"].double ?? json["created"].doubleValue),
		                   "text" : text, "counts" : ["upvotes" : json["ups"].intValue, "comments" : json["num_comments"].intValue],
		                   "link" : link, "media" : media, "user" : User(value: ["id" : json["subreddit"].stringValue,
		                                                                         "name" : "r/" + json["subreddit"].stringValue,
		                                                                         "username" : "u/" + json["author"].stringValue,
		                                                                         "service" : rawValue])])
	}
	
	static func getChannelPosts(from users: [String], paging: [String : String]?, progress: @escaping (Float) -> Void, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var completed = 0, posts = [Post](), newPaging = [String : String](), hasErrored = false
			if !users.isEmpty {
				for user in users {
					var parameters = ["count" : users.count == 1 ? "200" : "\(postCount)"]
					if let maxId = paging?[user] {
						parameters["after"] = maxId
					}
					performRequest(endpoint: "r/\(user)/.json", parameters: parameters, callback: { json, errorFunc in
						if let json = json, let items = json["data"]["children"].array {
							if let after = json["data"]["after"].string {
								newPaging[user] = after
							}
							for item in items {
								posts.append(post(from: item["data"]))
							}
						} else if !hasErrored {
							hasErrored = true
							errorFunc("There was an error fetching \(rawValue) posts.")
						}
						completed += 1
						progress(Float(completed) / Float(users.count))
						if completed == users.count {
							completed += 1
							callback(posts, newPaging)
						}
					})
				}
			} else {
				callback(posts, nil)
			}
		}
	}
	
	static func getPosts(from searchTerm: String, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		callback([Post](), nil)
	}
	
	static func getTrending(callback: @escaping ([Any]) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			performRequest(endpoint: "top", parameters: ["count" : "50"], callback: { json, errorFunc in
				var posts = [Post](), completed = 0
				if let json = json, let items = json["data"]["children"].array {
					for item in items {
						let p = post(from: item["data"])
						getUser(from: p.user.id, callback: { user in
							completed += 1
							if let user = user, let username = p.user.username {
								p.user = user
								p.user.username = username
							}
							DispatchQueue.main.sync {
								posts.append(p)
							}
							if completed == items.count {
								print(rawValue, "Callback")
								callback(posts)
							}
						})
					}
				} else {
					errorFunc("There was an error fetching trending \(rawValue) posts.")
					callback(posts)
				}
			})
		}
	}
	
	static func getComments(forPost: Post, paging: [String : String]?, callback: @escaping ([Post], [String : String]?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var posts = [Post]() // Paging
			let parameters = ["total_count" : "100"]
			performRequest(endpoint: "r/\(forPost.user.id)/comments/\(forPost.id)", parameters: parameters, callback: { json, errorFunc in
				if let json = json, let items = json.array?.last?["data"]["children"].array {
					posts = comments(from: items)
				} else {
					errorFunc("There was an error fetching \(rawValue) comments.")
				}
				callback(posts, nil)
			})
		}
	}
	
	static func comments(from json: [JSON]) -> [Post] {
		var posts = [Post]()
		for i in json {
			if i["data"]["author"].string != nil {
				posts.append(comment(from: i["data"]))
			}
			if let replies = i["data"]["replies"]["data"]["children"].array {
				posts.append(contentsOf: comments(from: replies))
			}
		}
		return posts
	}
	
	static func comment(from json: JSON) -> Post {
		let text = json["body"].stringValue.replacingOccurrences(of: "&amp;", with: "&")
			.replacingOccurrences(of: "&lt;", with: "<")
			.replacingOccurrences(of: "&gt;", with: ">")
		return RedditComment(["id" : json["id"].stringValue,
		                      "date" : Date(timeIntervalSince1970: json["created_utc"].double ?? json["created"].doubleValue),
		                      "depth" : json["depth"].intValue,
		                      "text" : text, "counts" : ["upvotes" : json["ups"].intValue,
		                                                 "comments" : json["num_comments"].intValue],
		                      "user" : User(value: ["id" : json["subreddit"].stringValue,
		                                            "name" : "u/\(json["author"].stringValue)", "service" : rawValue])])
	}
	
	
}

class Account {
	
	var id: String
	var name: String
	var service: Service.Type
	var oauth: OAuthSwift
	
	init(id: String, name: String, service: Service.Type, oauth: OAuthSwift) {
		self.id = id
		self.name = name
		self.service = service
		self.oauth = oauth
	}
	
	init(dictionary: [String : String], service: Service.Type) {
		let oauth = service.createOauth()
		oauth.client.credential.oauthToken = dictionary["oauth_token"]!
		oauth.client.credential.oauthTokenSecret = dictionary["oauth_secret"]!
		oauth.client.credential.oauthRefreshToken = dictionary["refresh_token"] ?? ""
		oauth.client.credential.version = service.oauthVersion
		self.id = dictionary["id"]!
		self.name = dictionary["name"]!
		self.service = service
		self.oauth = oauth
	}
	
	func save() {
		UserDefaults.standard.set(["id" : id, "name" : name,
			"oauth_token" : oauth.client.credential.oauthToken,
			"oauth_secret" : oauth.client.credential.oauthTokenSecret,
			"refresh_token" : oauth.client.credential.oauthRefreshToken], forKey: service.rawValue)
		UserDefaults.standard.synchronize()
		accounts[service.rawValue] = self
	}
	
}

class GoogleSignIn: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate {
	
	var callback: ((GIDGoogleUser?) -> Void)!
	
	func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
		callback(error == nil ? user : nil)
	}
	
	func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
		callback(nil)
	}
}

class ServiceNode: ASCellNode {
	
	override init() {
		super.init()
		automaticallyManagesSubnodes = true
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let text = Text("Sign In to Enable:", .systemFont(ofSize: 16, weight: .semibold), .black), spacer = ASLayoutSpec()
		spacer.style.flexGrow = 1
		let stack = Stack(.horizontal, 12, [text, spacer] + services.flatMap{return $0.hasAccount ? nil : ServiceImageNode($0.rawValue, 16)})
		stack.alignItems = .center
		return stack.inset()
	}
	
}

extension Collection {
	subscript (safe index: Index) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}
}

extension Array {
	func chunked(by chunkSize:Int) -> [[Element]] {
		return stride(from: 0, to: count, by: chunkSize).map {
			Array(self[$0..<[$0 + chunkSize, count].min()!])
		}
	}
}
