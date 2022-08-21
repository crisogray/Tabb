//
//  Channel.swift
//  Tabb
//
//  Created by Ben Gray on 07/04/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AsyncDisplayKit
import RealmSwift

class Channel: Object {
	
	@objc dynamic var id: String = ""
	@objc dynamic var name: String = ""
	@objc dynamic var desc: String = ""
	@objc dynamic var isPrivate: Bool = true
	@objc dynamic var date: Date = Date()
	var users = List<User>()
	
	override static func primaryKey() -> String? {
		return "id"
	}
	
}

class ChannelViewController: PostsViewController {
	
	var channel: Channel!
	var needsUpdateOnAppearence = false
	var needsUsers = false
	var needsServices = false
	var servicesCount = -1
	
	convenience init(channel: Channel) {
		self.init(.plain)
		self.channel = channel
		setup()
		navigationItem.title = channel.name
		progressNode = ProgressNode(channel: channel)
		NotificationCenter.default.addObserver(self, selector: #selector(ChannelViewController.onUpdate(_:)), name: NSNotification.Name("Update"), object: nil)
		navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "People 24pt"), style: .plain, target: self, action: #selector(ChannelViewController.showUsers))
	}
	
	override func getPosts(progressBlock: @escaping (Float, Service.Type) -> Void, callbackBlock: @escaping ([Post], [String : [String : String]]?) -> Void) {
		var users = [String : [String]](), pictures = [String : String](), igVerified = [String : Bool](), posts = [Post](), completed = 0, count = 0, pagingData = [String : [String : String]]()
		for service in services {
			users[service.rawValue] = [String]()
		}
		channel.users.forEach {
			users[$0.service]!.append($0.service == instagram.rawValue ? $0.username ?? $0.name : $0.id)
			if $0.service == youtube.rawValue || $0.service == reddit.rawValue {
				pictures[$0.id] = $0.picture
			} else if $0.service == instagram.rawValue {
				igVerified[$0.id] = $0.verified
			}
		}
		needsUsers = channel.users.isEmpty
		node.view.bounces = !channel.users.isEmpty
		for service in servicesWithAccounts where channel.users.contains(where: {$0.service == service.rawValue}) {
			count += 1
			if let u = users[service.rawValue] {
				service.getChannelPosts(from: u, paging: self.pagingData[service.rawValue], progress: { progress in
					progressBlock(progress, service)
				}, callback: { p, paging in
					print(service.rawValue, "Callback")
					DispatchQueue.global().async {
//						if let paging = paging {
							//pagingData[service.rawValue] = paging
//						}
						if service is youtube.Type || service is reddit.Type {
							p.forEach { $0.user.picture = pictures[$0.user.id] ?? "" }
						} else if service is instagram.Type {
							p.forEach { $0.user.verified = igVerified[$0.user.id] ?? false}
						}
						posts += p
						completed += 1
						if completed == count {
							self.refreshDate = Date().addingTimeInterval(20)
							callbackBlock(posts.sorted {$0.date > $1.date}, pagingData)
						}
					}
				})
			} else {
				completed += 1
			}
		}
		servicesCount = count
		needsServices = count == 0
	}
	
	@objc func showUsers() {
		show(UsersViewController(channel: channel), sender: nil)
	}
	
	@objc func onUpdate(_ notification: NSNotification) {
		if let o = notification.object as? (User, String, UIViewController), o.1 == channel.id, o.2 != self {
			needsUpdateOnAppearence = true
		}
	}
	
	override func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return needsUsers || needsServices ? 1 : super.tableNode(tableNode, numberOfRowsInSection: section)
	}
	
	override func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		if needsUsers {
			return {
				return InstructionCell("No Posts Yet", "Posts will appear in this channel once you've added some users.\n\nTap the button in the top right to show the users screen.", "Instruction")
			}
		} else if needsServices {
			return {
				return InstructionCell("Not Signed In", "You are not signed in with any services that this channel gets posts from.\n\nGo to Settings by swiping right then clicking the button in the bottom right.", "Empty")
			}
		}
		return loading || (refreshing && indexPath.row == 0)  ? {return self.progressNode} : super.tableNode(node, nodeBlockForRowAt: indexPath)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		var count = 0
		for service in servicesWithAccounts where channel.users.contains(where: {$0.service == service.rawValue}) {
			count += 1
		}
		if needsUpdateOnAppearence || (count != servicesCount && servicesCount != -1) {
			needsUpdateOnAppearence = false
			servicesCount = count
			progressNode = ProgressNode(channel: channel)
			posts = nil
			needsUsers = channel.users.isEmpty
			needsServices = count == 0
			node.reloadData()
			node.view.contentOffset.y = 0
//			node.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
			initialGet()
		}
	}
	
}

extension Date {
	var timeAgoSinceNow: String {
		let components = Calendar.current.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: Date())
		if let year = components.year, year >= 1 {
			return "\(year)Y"
		} else if let month = components.month, month >= 1 {
			return "\(month)M"
		} else if let week = components.weekOfYear, week >= 1 {
			return "\(week)w"
		} else if let day = components.day, day >= 1 {
			return "\(day)d"
		} else if let hour = components.hour, hour >= 1 {
			return "\(hour)h"
		} else if let minute = components.minute, minute >= 1 {
			return "\(minute)m"
		} else if let second = components.second, second >= 3 {
			return "\(second)s"
		}
		return "Just Now"
	}
}
