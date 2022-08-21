//
//  Trending.swift
//  Tabb
//
//  Created by Ben Gray on 29/08/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AsyncDisplayKit

class TrendingViewController: PostsViewController {
	
	let trendingServices: [Service.Type] = [twitter.self, youtube.self, reddit.self]
	var disabledServices: [Service.Type] {
		return trendingServices.flatMap { $0.hasAccount ? nil : $0 }
	}
	var enabledServices: [Service.Type] {
		return trendingServices.flatMap { $0.hasAccount ? $0 : nil }
	}
	var hashtags: [String]!
	var loadingTrending = true
	var showSignIn = servicesWithAccounts.count < services.count
	var serviceCount = servicesWithAccounts.count
	var enabledCount = 0
	override var loading: Bool {
		return loadingTrending
	}
	
	convenience init() {
		self.init(.grouped)
		navigationItem.title = "Trending"
		setup()
		node.view.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: w, height: .leastNonzeroMagnitude))
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if serviceCount != servicesWithAccounts.count {
			serviceCount = servicesWithAccounts.count
			if enabledCount != enabledServices.count {
				loadingTrending = true
				node.reloadData()
				initialGet()
			} else {
				servicesWithAccounts.count == services.count ? node.deleteSections([0], with: .none) : node.reloadSections([0], with: .none)
			}
		}
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		let section = section - (servicesWithAccounts.count < services.count ? 1 : 0)
		if section == -1 {
			return "Disabled Services"
		} else if enabledServices.isEmpty || loading || loadingTrending {
			return nil
		} else if section == 0 && hashtags != nil {
			return "Trending Hashtags"
		} else if posts != nil {
			return "Trending Posts"
		}
		return nil
	}
	
	override func getPosts(progressBlock: @escaping (Float, Service.Type) -> Void, callbackBlock: @escaping ([Post], [String : [String : String]]?) -> Void) {
		enabledCount = enabledServices.count
		var completed = 0, posts = [Post]()
		if !enabledServices.isEmpty {
			for service in enabledServices {
				service.getTrending(callback: { result in
					completed += 1
					if let hashtags = result as? [String] {
						self.hashtags = hashtags
					} else if let p = result as? [Post] {
						posts.append(contentsOf: p)
					}
					if completed == self.enabledServices.count {
						self.loadingTrending = false
						self.refreshing = false
						callbackBlock(posts.sorted(by: {$0.date > $1.date}).sorted(by: {_, _ in arc4random() > arc4random()}), nil)
					}
				})
			}
		} else {
			self.posts = posts
		}
	}
	
	override func refreshChannel(sender: UIRefreshControl) {
		sender.endRefreshing()
		node.view.sendSubview(toBack: sender)
		if refreshDate < Date(), !loading, !refreshing {
			refreshing = true
			refreshDate = Date().addingTimeInterval(20)
			loadingTrending = true
			node.reloadData()
			initialGet()
		}
	}
	
	func numberOfSections(in tableNode: ASTableNode) -> Int {
		return (loading ? 1 : 2) + (servicesWithAccounts.count < services.count ? 1 : 0)
	}
	
	override func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		let section = section - (servicesWithAccounts.count < services.count ? 1 : 0)
		return section == -1 || loading || enabledServices.isEmpty ? 1 : section == 0 && hashtags != nil ? min(hashtags.count, 7) : max(posts.count, 1)
	}
	
	override func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		let section = indexPath.section - (servicesWithAccounts.count < services.count ? 1 : 0)
		if section == -1 {
			return {return ServiceNode()}
		} else if enabledServices.isEmpty {
			return {
				return InstructionCell("Trending Unavailable", "You are not signed in with any services that support trending.\n\nSign In with Twitter, YouTube or Reddit above.", "Empty")
			}
		} else if loading {
			return {return LoadingNode()}
		} else if section == 0 && hashtags != nil {
			if indexPath.row == 6, hashtags.count > 7 {
				return {return ViewHashtagsNode()}
			} else {
				let hashtag = hashtags[indexPath.row]
				return {return HashtagNode(hashtag)}
			}
		} else if let post = posts[safe: indexPath.row] {
			return {return PostNode(post, self)}
		}
		return {
			return InstructionCell("No Posts Found", "There was either an error when fetching the posts or there were no posts to fetch.\n\nTry reloading again later.", "Empty")
		}
	}
	
	override func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		super.tableNode(tableNode, didSelectRowAt: indexPath)
		if let hashtagNode = tableNode.nodeForRow(at: indexPath) as? HashtagNode {
			show(HashtagViewController(hashtagNode.hashtag, service: twitter.self), sender: nil)
		} else if let _ = tableNode.nodeForRow(at: indexPath) as? ServiceNode {
			show(SettingsViewController(), sender: nil)
		} else if let _ = tableNode.nodeForRow(at: indexPath) as? ViewHashtagsNode {
			show(ViewHashtagsViewController(hashtags: hashtags), sender: nil)
		}
	}
	
}

class ViewHashtagsNode: ASCellNode {
	
	override init() {
		super.init()
		automaticallyManagesSubnodes = true
		accessoryType = .disclosureIndicator
		backgroundColor = .white
	}

	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return Text("View All Trending Hashtags", .systemFont(ofSize: 16, weight: .semibold), .black).inset(UIEdgeInsetsMake(12, 16, 12, 0))
	}
	
}

class ViewHashtagsViewController: PresentableViewController {
	
	var hashtags: [String]!
	
	convenience init(hashtags: [String]) {
		self.init(.plain)
		self.hashtags = hashtags
		navigationItem.title = "Trending Hashtags"
		node.view.tableFooterView = UIView()
	}
	
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return hashtags.count
	}
	
	func tableNode(_ tableNode: ASTableNode, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
		return HashtagNode(hashtags[indexPath.row])
	}
	
	func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		if let hashtagNode = tableNode.nodeForRow(at: indexPath) as? HashtagNode {
			show(HashtagViewController(hashtagNode.hashtag, service: twitter.self), sender: nil)
		}
		tableNode.deselectRow(at: indexPath, animated: true)
	}
	
}

class HashtagNode: ASCellNode {
	
	var hashtag: String!
	
	convenience init(_ hashtag: String) {
		self.init()
		self.hashtag = hashtag
		accessoryType = .disclosureIndicator
		automaticallyManagesSubnodes = true
		separatorInset.left = space
		backgroundColor = .white
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return Text(hashtag, .systemFont(ofSize: 16, weight: .medium), twitter.colour).inset()
	}
	
}

