//
//  User.swift
//  Tabb
//
//  Created by Ben Gray on 03/07/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import Alamofire
import RealmSwift
import AsyncDisplayKit

extension PresentableViewController {
	func set(_ button: UserButton) {
		var channels = [Channel]()
		let realm = try! Realm()
		for channel in realm.objects(Channel.self) where !channel.contains(button.user) {
			channels.append(channel)
		}
		button.set(channels.isEmpty)
	}
	
	func add(_ user: User, _ button: UserButton) {
		let channels = realm.objects(Channel.self).map{ return $0 }
		let alert = UIAlertController(title: "Select a Channel", message: "Choose a channel for \(user.name)\nto be added to or removed from", preferredStyle: .actionSheet)
		for channel in channels {
			let remove = channel.contains(user)
			alert.addAction(UIAlertAction(title: channel.name, style: (remove ? .destructive : .default), handler: { action in
				channel.toggle(user, realm, self)
				self.set(button)
			}))
		}
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		self.present(alert, animated: true, completion: nil)
	}
}

class UserViewController: PostsViewController {
	var user: User?
	
	convenience init(user: User) {
		self.init(.plain)
		setup(user)
	}
	
	convenience init(_ screenName: String, service: Service.Type){
		self.init(.plain)
		self.setup()
		navigationItem.title = "@\(screenName)"
		service.searchForUsers(query: "@\(screenName)".lowercased()) { users in
			DispatchQueue.main.async {
				if let user = users.first, user.username?.lowercased() == screenName.lowercased() {
					self.setup(user)
					self.node.reloadData()
				} else {
					if let navController = self.navigationController {
						navController.popViewController(animated: true)
					}
				}
			}
		}
	}
	
	override func setup() {
		isPresented = true
		super.setup()
	}
	
	func setup(_ user: User) {
		self.user = user
		self.setup()
		progressNode = ProgressNode([service(user.service)])
		navigationItem.title = user.name
		let header = UserHeader(user, add)
		set(header.addButton)
		node.view.tableHeaderView = header.view
	}
	
	override func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		if let user = user, !service(user.service).hasAccount {
			return {
				return InstructionCell("Not Signed In", "You are not signed in with any services that this channel gets posts from.\n\nGo to Settings by swiping right then clicking the button in the bottom right.", "Empty")
			}
		}
		return super.tableNode(tableNode, nodeBlockForRowAt: indexPath)
	}
	
	override func showUser(_ user: User) {
		if let u = self.user, !(user.id == u.id && user.service == u.service) {
			super.showUser(user)
		}
	}
    
    override func showUser(_ screenName: String, service: Service.Type) {
        if let u = self.user, !(user?.username == screenName && service.rawValue == u.service) {
            super.showUser(screenName, service: service)
        }
    }
	
	override func getPosts(progressBlock: @escaping (Float, Service.Type) -> Void, callbackBlock: @escaping ([Post], [String : [String : String]]?) -> Void) {
		if let user = self.user {
			let s = service(user.service), picture = user.picture, verified = user.verified
			s.getChannelPosts(from: [user.service == instagram.rawValue ? user.username ?? user.name : user.id], paging: pagingData[user.service], progress: { progress in
				progressBlock(progress, s)
			}) { posts, paging in
				self.refreshDate = Date().addingTimeInterval(20)
				posts.forEach {
					$0.user.picture = picture
					$0.user.verified = verified
				}
				callbackBlock(posts, nil)
			}
		}
	}
	
}

class UserHeader: ASDisplayNode {
	
	var user: User!
	var _user: ThreadSafeReference<User>!
	var addButton: UserButton!
	var addFunc: ((User, UserButton) -> Void)!
	
	convenience init(_ user: User, _ addFunc: @escaping (User, UserButton) -> Void) {
		self.init()
		self.user = user
		self.addFunc = addFunc
		user.realm != nil ? (_user = ThreadSafeReference(to: user)) : (u = user)
		addButton = UserButton(user) { user in self.addFunc(user, self.addButton)}
		addButton.style.preferredSize.width = 56
		automaticallyManagesSubnodes = true
		style.preferredSize.height = 88
		frame.size.height = 88
		backgroundColor = .white
		let n = ASDisplayNode()
		n.backgroundColor = shadowGray
		n.frame.size = CGSize(width: w, height: 0.5)
		n.frame.origin.y = 87.5
		addSubnode(n)
	}
	
	var u: User!
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		if u == nil {
			let realm = try! Realm()
			u = realm.resolve(_user)!
		}
		let name = Text(u.name, .systemFont(ofSize: 18, weight: .semibold), .black)
		name.maximumNumberOfLines = 1
		name.style.flexShrink = 1
		var nameStack = Stack(.horizontal, space / 3, u.verified ? [name, VerifiedNode(u.service)] : [name])
		nameStack.alignItems = .center
		if let u = u.username {
			let username = Text("@\(u)", .systemFont(ofSize: 17), .darkGray)
			username.maximumNumberOfLines = 1
			username.style.flexShrink = 1
			nameStack = Stack(.vertical, 0, [nameStack, username])
		}
		let serviceStack = Stack(.horizontal, 12, [nameStack, ServiceImageNode(u.service), addButton])
		serviceStack.alignItems = .center
		let wholeStack = Stack(.horizontal, 12, [UserImageNode(u, 64), serviceStack])
		wholeStack.alignItems = .center
		return wholeStack.inset()
	}
	
}

class HashtagViewController: PostsViewController {
	
	var hashtag: String!
	var service: Service.Type!
	
	convenience init(_ hashtag: String, service: Service.Type) {
		self.init(.plain)
		self.hashtag = hashtag
		self.service = service
		isPresented = true
		self.setup()
		navigationItem.title = hashtag
	}
	
	override func getPosts(progressBlock: @escaping (Float, Service.Type) -> Void, callbackBlock: @escaping ([Post], [String : [String : String]]?) -> Void) {
		service.getPosts(from: hashtag, paging: nil) { posts, paging in callbackBlock(posts, nil)}
	}
	
	override func showHashtag(_ hashtag: String, service: Service.Type) {
		if hashtag.lowercased() != self.hashtag.lowercased() {
			super.showHashtag(hashtag, service: service)
		}
	}
	
}

