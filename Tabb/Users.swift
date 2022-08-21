//
//  Users.swift
//  Tabb
//
//  Created by Ben Gray on 09/04/2017.
//  Copyright © 2017 crisignIngray. All rights reserved.
//

import UIKit
import RealmSwift
import AsyncDisplayKit

class User: Object {
	
	@objc dynamic var id: String = ""
	@objc dynamic var name: String = ""
	@objc dynamic var username: String? = nil
	@objc dynamic var picture: String = ""
	@objc dynamic var service: String = ""
	@objc dynamic var verified: Bool = false
	
}

extension Channel {
	func contains(_ user: User) -> Bool {
		return users.contains {$0.id == user.id && $0.service == user.service}
	}
	
	func index(of user: User) -> Int? {
		return users.index(where: {$0.id == user.id && $0.service == user.service})
	}
	
	func toggle(_ user: User, _ realm: Realm, _ sender: UIViewController) {
		try! realm.write {
			if let index = index(of: user) {
				users.remove(objectAtIndex: index)
			} else {
				users.insert(user, at: 0)
				if let tracker = GAI.sharedInstance().defaultTracker {
					tracker.send(GAIDictionaryBuilder.createEvent(withCategory: "Interaction", action: "Add User",
					                                              label: user.username ?? user.name,
					                                              value: nil).build() as! [AnyHashable : Any]!)
				}
			}
		}
		NotificationCenter.default.post(name: Notification.Name("Update"), object: (user, id, sender))
	}
}

class UsersViewController: PresentableViewController, UISearchControllerDelegate, UISearchBarDelegate, UserCellDelegate {
	
	var channel: Channel!
	var _channel: ThreadSafeReference<Channel>!
	var showSignIn = servicesWithAccounts.count < services.count
	var signIn: Int {
		return showSignIn ? 1 : 0
	}
	
	convenience init(channel: Channel) {
		self.init(.grouped)
		self.channel = channel
		_channel = ThreadSafeReference(to: channel)
		navigationItem.title = "Users"
		NotificationCenter.default.removeObserver(self)
		NotificationCenter.default.addObserver(self, selector: #selector(UsersViewController.onUpdate(_:)), name: NSNotification.Name("Update"), object: nil)
		navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "Add Users 24pt"), style: .plain, target: self, action: #selector(UsersViewController.addUsers))
		node.view.backgroundView = UIView()
		node.view.backgroundColor = .white
		node.view.separatorColor = shadowGray
		DispatchQueue.global(qos: .utility).async {
			let realm = try! Realm(), channel = realm.resolve(self._channel)
			if let channel = channel {
				for (index, user) in channel.users.enumerated() {
					let picture = user.picture, name = user.name
					service(user.service).getUser(from: user.service == instagram.rawValue ? user.username ?? user.name : user.id) { u in
						DispatchQueue.main.async {
							if let u = u, u.picture != picture || u.name != name {
								try! Realm().write {
									self.channel.users[index] = u
									DispatchQueue.main.async {
										self.node.reloadRows(at: [IndexPath(row: index, section: self.signIn)], with: .none)
									}
								}
							}
						}
					}
				}
			}
		}
	}
	
	deinit {
		print("SDGSFHGSH")
	}
	
	@objc func addUsers() {
		show(AddUsersViewController(channel: channel), sender: nil)
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return section == signIn - 1 ? "Disabled Services" : channel.users.isEmpty ? nil : "Members of \(channel.name)"
	}
	
	@IBAction func back() {
		navigationController?.popViewController(animated: true)
	}
	
	func numberOfSections(in tableNode: ASTableNode) -> Int {
		return 1 + signIn
	}
	
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return section == signIn - 1 ? 1 : channel.users.count
	}
	
	func instructionView() -> InstructionView {
		let instructionView = Bundle.main.loadNibNamed("Instruction", owner: nil, options: [:])![0] as! InstructionView
		instructionView.titleLabel.text = "No Users Yet"
		instructionView.instructionLabel.text = "Users you add to this channel will appear here.\n\nTap the button in the top right to add some."
		return instructionView
	}
	
	override func viewWillAppear(_ animated: Bool) {
		node.view.isUserInteractionEnabled = !channel.users.isEmpty
		node.view.tableHeaderView = channel.users.isEmpty ? instructionView() : UIView(frame: CGRect(x: 0, y: 0, width: w, height: .leastNonzeroMagnitude))
		if showSignIn && servicesWithAccounts.count == services.count {
			showSignIn = servicesWithAccounts.count < services.count
			node.reloadData()
		} else if servicesWithAccounts.count < services.count {
			showSignIn = servicesWithAccounts.count < services.count
			node.reloadSections([0], with: .none)
		}
	}
	
	@objc func onUpdate(_ notification: NSNotification) {
		if !channel.isInvalidated {
			_channel = ThreadSafeReference(to: channel)
			if let o = notification.object as? (User?, String, UIViewController), o.1 == channel.id, o.2 != self {
				node.reloadSections(IndexSet([signIn]), with: .none)
			}
		} else {
			NotificationCenter.default.removeObserver(self)
		}
	}
	
	func toggle(_ user: User) {
		if let index = channel.index(of: user) {
			channel.toggle(user, realm, self)
			node.deleteRows(at: [IndexPath(row: index, section: signIn)], with: index == 0 ? .automatic : .top)
			if channel.users.isEmpty {
				UIView.animate(withDuration: 0.25, animations: {
					self.node.view.tableHeaderView = self.instructionView()
				})
			}
		}
	}
	
	var c: Channel!
	
	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		if indexPath.section == signIn - 1 {
			return { return ServiceNode() }
		}
		let user = channel.users[indexPath.row]
		return { return UserNode(user, added: true, delegate: self) }
	}
	
	func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		if let userNode = tableNode.nodeForRow(at: indexPath) as? UserNode {
			show(UserViewController(user: userNode.user), sender: nil)
		} else if let _ = tableNode.nodeForRow(at: indexPath) as? ServiceNode {
			show(SettingsViewController(), sender: nil)
		}
		tableNode.deselectRow(at: indexPath, animated: true)
	}
	
}

class ViewUsersNode: ASCellNode {
	
	var s: Service.Type!
	
	convenience init(_ service: Service.Type) {
		self.init()
		self.s = service
		automaticallyManagesSubnodes = true
		accessoryType = .disclosureIndicator
		backgroundColor = .white
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return Text("View All \(s.rawValue) Users", .systemFont(ofSize: 16, weight: .semibold), .black).inset(UIEdgeInsetsMake(12, 72, 12, 0))
	}
	
}

class ViewUsersViewController: PresentableViewController, UserCellDelegate {
	
	var users: [User]!
	var channel: Channel!
	
	convenience init(_ users: [User], _ channel: Channel) {
		self.init(.plain)
		self.users = users
		self.channel = channel
		if let user = users.first {
			navigationItem.title = "\(user.service) Users"
		}
		node.view.tableFooterView = UIView()
		NotificationCenter.default.removeObserver(self)
		NotificationCenter.default.addObserver(self, selector: #selector(ViewUsersViewController.onUpdate(_:)), name: NSNotification.Name("Update"), object: nil)
		print("hi")
	}
	
	@objc func onUpdate(_ notification: NSNotification) {
		if let o = notification.object as? (User, String, UIViewController),
			let row = users.index(of: o.0), o.1 == channel.id, o.2 != self {
			node.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
		}
	}
	
	func toggle(_ user: User) {
		channel.toggle(user, realm, self)
	}
	
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return users.count
	}
	
	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		let user = users[indexPath.row], contains = channel.contains(user)
		return { return UserNode(user, added: contains, delegate: self) }
	}
	
//	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
//		print(channel)
//		let user = users[indexPath.row], contains = channel.contains(user)
//		return {
//			print("Hikkbjkbjjbkjkb")
//		}
//	}
	
	func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		if let userNode = tableNode.nodeForRow(at: indexPath) as? UserNode {
			show(UserViewController(user: userNode.user), sender: nil)
		}
		tableNode.deselectRow(at: indexPath, animated: true)
	}
	
}

protocol UserCellDelegate {
	func toggle(_ user: User)
}

class UserNode: ASCellNode {
	
	var user: User!
	var _user: ThreadSafeReference<User>!
	var added: Bool!
	var delegate: UserCellDelegate!
	var addButton: UserButton!
	
	convenience init(_ user: User, added: Bool, delegate: UserCellDelegate?) {
		self.init()
		self.user = user
		if user.realm != nil {
			DispatchQueue.main.sync {
				_user = ThreadSafeReference(to: user)
			}
		} else {
			u = user
		}
		self.added = added
		self.delegate = delegate
		automaticallyManagesSubnodes = true
		backgroundColor = .white
		separatorInset.left = 72
	}
	
	var u: User!
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		if let user = _user {
			let realm = try! Realm()
			u = realm.resolve(user)!
			_user = ThreadSafeReference(to: u)
		}
		let name = Text(u.name, .systemFont(ofSize: 16, weight: .semibold), .black)
		name.maximumNumberOfLines = 1
		name.style.flexShrink = 1
		var nameStack = Stack(.horizontal, space / 3, u.verified ? [name, VerifiedNode(u.service)] : [name])
		nameStack.alignItems = .center
		if let uname = u.username {
			let username = Text((u.service == reddit.rawValue ? "" : "@") + uname, .systemFont(ofSize: 15), .darkGray)
			username.maximumNumberOfLines = 1
			username.style.flexShrink = 1
			nameStack = Stack(.vertical, 0, [nameStack, username])
		}
		var rightItem: ASLayoutElement!
		if let toggle = delegate?.toggle {
			addButton = AddButton(u, added, toggle)
			rightItem = addButton
		} else if let addButton = addButton {
			rightItem = addButton
		}
		let contentStack = Stack(.horizontal, self is DetailUserNode ? 12 : 16, [UserImageNode(u, 40), nameStack, ServiceImageNode(u.service), rightItem])
		contentStack.alignItems = .center
		return contentStack.inset()
	}
	
}

class UserButton: ASButtonNode {
	
	var user: User!
	var s: Service.Type!
	var _user: ThreadSafeReference<User>!
	var toggle: ((User) -> Void)!
	
	convenience init(_ user: User, _ toggle: @escaping (User) -> Void) {
		self.init()
		self.toggle = toggle
		self.user = user
		self.s = service(user.service)
		user.realm != nil ? (_user = ThreadSafeReference(to: user)) : (u = user)
		cornerRadius = 3
		borderColor = s.colour.cgColor
		borderWidth = 1
		style.preferredSize.height = 34
		addTarget(self, action: #selector(UserButton.target), forControlEvents: .touchUpInside)
	}
	
	var u: User!
	
	@objc func target() {
		if let user = _user {
			let realm = try! Realm()
			u = realm.resolve(user)!
			_user = ThreadSafeReference(to: u)
		}
		if let toggle = toggle {
			toggle(u)
		}
	}
	
	func set(_ added: Bool) {
		DispatchQueue.main.async {
			self.setTitle((added ? "✓" : "Add"), with: .systemFont(ofSize: 14, weight: .medium), with: (added ? .white : self.s.colour), for: .normal)
			self.backgroundColor = added ? self.s.colour : .white
		}
	}
	
}

class AddButton: UserButton {
	
	var added: Bool!
	
	convenience init(_ user: User, _ added: Bool, _ toggle: @escaping (User) -> Void) {
		self.init(user, toggle)
		self.added = added
		style.preferredSize.width = 56
		set(added)
	}
	
	@objc override func target() {
		DispatchQueue.main.async {
			self.added = !self.added
			self.set(self.added)
			super.target()
		}
	}
	
}
