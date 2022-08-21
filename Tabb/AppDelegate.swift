//
//  AppDelegate.swift
//  Tabb
//
//  Created by Ben Gray on 07/04/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import TwitterKit
import FBSDKCoreKit
import GoogleSignIn
import OAuthSwift
import RealmSwift
import Pastel
import Alamofire

let w = UIScreen.main.bounds.width, h = UIScreen.main.bounds.height, space: CGFloat = 16
let regexes = ["hashtag" : "#\\w+", "mention" : "@\\w+",
               "url" : "((?:http|https)://)?(?:www\\.)?[\\w\\d\\-_]+\\.\\w{2,3}(\\.\\w{2})?(/(?<=/)(?:[\\w\\d\\-./_]+)?)?"]
let shadowGray = UIColor(red: 0.79, green: 0.80, blue: 0.81, alpha: 1), realm = try! Realm(), userWidth: CGFloat = 40
let lightGray = UIColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	
	var window: UIWindow?
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		Realm.Configuration.defaultConfiguration.deleteRealmIfMigrationNeeded = true
		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
		} catch {
			fatalError(error.localizedDescription)
		}
		refreshTokens()
		Twitter.sharedInstance().start(withConsumerKey: twitter.consumerKey, consumerSecret: twitter.consumerSecret)
		FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
		GIDSignIn.sharedInstance().clientID = youtube.consumerKey
		GIDSignIn.sharedInstance().scopes = ["https://www.googleapis.com/auth/youtube.force-ssl"]
		guard let gai = GAI.sharedInstance() else {
			fatalError()
		}
		GAI.sharedInstance().defaultTracker = gai.tracker(withTrackingId: "UA-106314448-1")
		gai.trackUncaughtExceptions = true
		if let name = servicesWithAccounts.first?.account?.name, let tracker = GAI.sharedInstance().defaultTracker {
			tracker.send(GAIDictionaryBuilder.createEvent(withCategory: "Interaction", action: "Launch", label: name, value: nil).build() as! [AnyHashable : Any]!)
		}
		return true
	}
	
	func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
		if let scheme = url.scheme, scheme.hasPrefix("com.googleusercontent") {
			return GIDSignIn.sharedInstance().handle(url, sourceApplication: options[.sourceApplication] as? String, annotation: options[.annotation])
		} else if url.scheme == "fb116567582169517" {
			return FBSDKApplicationDelegate.sharedInstance().application(app, open: url, options: options)
		} else if url.host == "oauth-callback" {
			OAuthSwift.handle(url: url)
		} else if url.absoluteString.hasPrefix("twitterkit") {
			Twitter.sharedInstance().application(app, open: url, options: options)
		}
		return true
	}
	
	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}
	
	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}
	
	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
		if let pastelView = window?.rootViewController?.view.subviews.first as? PastelView {
			pastelView.startAnimation()
		}
		if let pastelView = window?.rootViewController?.presentedViewController?.view.subviews.first as? PastelView {
			pastelView.startAnimation()
		}
	}
	
	func applicationDidBecomeActive(_ application: UIApplication) {
		if Date(timeIntervalSinceReferenceDate: UserDefaults.standard.double(forKey: "refreshDate")).timeIntervalSinceNow < 0 {
			refreshTokens()
		}
		
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}
	
	func refreshTokens() {
		for service in [youtube.self, reddit.self] as [Service.Type] {
			if let account = service.account, let oauth = account.oauth as? OAuth2Swift {
				oauth.renewAccessToken(withRefreshToken: oauth.client.credential.oauthRefreshToken, success: { credential, _, _ in
					account.oauth.client.credential.oauthToken = credential.oauthToken
					account.save()
				}, failure: { error in
					// Handle Error
					print(error)
				})
			}
		}
		/*if let _ = instagram.account {
			Alamofire.request(instagram.baseUrl + "accounts/login/ajax/", method: .post, parameters: ["username" : "testcrisogray", "password" : "gbrsailing"], encoding: URLEncoding.queryString, headers: nil).responseJSON(completionHandler: { response in
				if let headers = response.response?.allHeaderFields as? [String: String], let cookie = headers["Set-Cookie"] {
					print(cookie)
					UserDefaults.standard.set(cookie, forKey: "IGCOOKIE")
				}
			})
		}*/
		UserDefaults.standard.set(Date(timeIntervalSinceNow: 900).timeIntervalSinceReferenceDate, forKey: "refreshDate")
		UserDefaults.standard.synchronize()
	}
	
	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
	
}

