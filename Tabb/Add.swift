//
//  Add.swift
//  Tabb
//
//  Created by Ben Gray on 14/08/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AsyncDisplayKit
import RealmSwift

class AddUsersViewController: PresentableViewController, UISearchControllerDelegate, UISearchBarDelegate, UserCellDelegate {
	
	var searchController: UISearchController!
	var searchQuery = ""
	var returned = false
	var loading: Bool {
		return returned ? searchedUsers == nil : followedUsers == nil
	}
	var followedUsers: [String : [User]]?
	var searchedUsers: [String : [User]]?
	var channel: Channel!
	var _channel: ThreadSafeReference<Channel>!
	
	convenience init(channel: Channel) {
		self.init(.grouped)
		self.channel = channel
		_channel = ThreadSafeReference(to: channel)
		navigationItem.title = "Add Users"
		definesPresentationContext = true
		NotificationCenter.default.addObserver(self, selector: #selector(UsersViewController.onUpdate(_:)), name: NSNotification.Name("Update"), object: nil)
		searchController = UISearchController(searchResultsController: nil)
		searchController.dimsBackgroundDuringPresentation = false
		searchController.hidesNavigationBarDuringPresentation = true
		searchController.delegate = self
		searchController.searchBar.autocapitalizationType = .words
		searchController.searchBar.placeholder = "Search For Users"
		searchController.searchBar.delegate = self
		if #available(iOS 11.0, *) {
			navigationItem.searchController = searchController
			navigationItem.hidesSearchBarWhenScrolling = false
		} else {
			searchController.searchBar.searchBarStyle = .minimal
			searchController.searchBar.backgroundColor = .white
			searchController.hidesNavigationBarDuringPresentation = false
			node.view.tableHeaderView = searchController.searchBar
		}
		node.view.backgroundColor = .white
		node.view.separatorColor = shadowGray
		getFollowing()
	}
	
	func getFollowing() {
		followedUsers = nil
		var completed = 0, users = [String : [User]]()
		for service in servicesWithAccounts {
			service.getFollowing(callback: { u in
				completed += 1
				users[service.rawValue] = u.sorted { _, _ in arc4random() > arc4random() }
				if completed == servicesWithAccounts.count {
					self.followedUsers = users
					if !self.returned {
						DispatchQueue.main.async {
							self.node.reloadData()
						}
					}
				}
			})
		}
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		if let query = searchBar.text, query != searchQuery, query != "" {
			search(query)
			if let tracker = GAI.sharedInstance().defaultTracker {
				tracker.send(GAIDictionaryBuilder.createEvent(withCategory: "Interaction", action: "Search", label: query, value: nil).build() as! [AnyHashable : Any]!)
			}
		}
	}
	
	func search(_ query: String) {
		searchQuery = query
		returned = true
		searchedUsers = nil
		node.reloadData()
		var completed = 0, users = [String : [User]]()
		for service in servicesWithAccounts {
			service.searchForUsers(query: query, callback: { u in
				completed += 1
				users[service.rawValue] = u
				if completed == servicesWithAccounts.count {
					self.searchedUsers = users
					if self.returned {
						DispatchQueue.main.async {
							self.node.reloadData()
						}
					}
				}
			})
		}
	}
	
	func didDismissSearchController(_ searchController: UISearchController) {
		searchQuery = ""
		if returned {
			returned = false
			node.reloadData()
		}
		returned = false
	}
	
	func willDismissSearchController(_ searchController: UISearchController) {
//		searchQuery = ""
//		if returned {
//			returned = false
//			node.reloadData()
//		}
//		returned = false
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if !loading {
			let service = servicesWithAccounts[section].rawValue
			return section == 0 ? returned ? "\(service) Results For \"\(searchQuery)\"" : "Followed \(service) Users" : service
		}
		return " "
	}
	
	func numberOfSections(in tableNode: ASTableNode) -> Int {
		return loading ? 1 : servicesWithAccounts.count
	}
	
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		if let users = (returned ? searchedUsers : followedUsers)?[servicesWithAccounts[section].rawValue], !loading {
			return max(min(3, users.count), 1)
		}
		return 1
	}
	
	@objc func onUpdate(_ notification: NSNotification) {
		if !channel.isInvalidated {
			_channel = ThreadSafeReference(to: channel)
			if let o = notification.object as? (User?, String, UIViewController), o.1 == channel.id, o.2 != self,
			let u = o.0, let users = (returned ? searchedUsers : followedUsers)?[u.service], let index = users.index(of: u), let section = servicesWithAccounts.index(where: {$0.rawValue == u.service}), index < 2 {
				node.reloadRows(at: [IndexPath(row: index, section: section)], with: .none)
			}
		} else {
			NotificationCenter.default.removeObserver(self)
		}
	}
	
	func toggle(_ user: User) {
		channel.toggle(user, realm, self)
	}
	
	var c: Channel!
//
//	func tableNode(_ tableNode: ASTableNode, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
//		if c == nil {
//			c = realm.resolve(_channel)!
//		}
//		let users = returned ? searchedUsers : followedUsers
//		if loading {
//			return LoadingNode()
//		} else if let users = users?[servicesWithAccounts[indexPath.section].rawValue], let user = users[safe: indexPath.row], !loading {
//			if indexPath.row == 2 {
//				return ViewUsersNode(servicesWithAccounts[indexPath.section])
//			}
//			return UserNode(user, added: channel.contains(user), delegate: self)
//		}
//		let service = servicesWithAccounts[indexPath.section]
//		var text = "Use another search term or try again later."
//		if !returned {
//			text = "There was an error or you don't " + (service is facebook.Type ? "like" : "follow") + " anyone on \(service.rawValue)."
//		}
//		return InstructionCell("No \(service.rawValue) Users", text, "Empty")
//	}
	
	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		if c == nil {
			c = realm.resolve(_channel)!
		}
		let users = returned ? searchedUsers : followedUsers
		if loading {
			return { return LoadingNode() }
		} else if let users = users?[servicesWithAccounts[indexPath.section].rawValue], let user = users[safe: indexPath.row], !loading {
			if indexPath.row == 2 {
				return { return ViewUsersNode(servicesWithAccounts[indexPath.section]) }
			}
			let contains = channel.contains(user)
			return { return UserNode(user, added: contains, delegate: self)}
		}
		if !returned, servicesWithAccounts[indexPath.section] is instagram.Type {
			return {
				return InstructionCell("Search For Instagram Users", "Due to limitations, quick add is unavailable.\n\nSearch for users to add to this channel.", "Empty")
			}
		}
		let service = servicesWithAccounts[indexPath.section]
		var text = "Use another search term or try again later."
		if !returned {
			text = "There was an error or you don't " + (service is facebook.Type ? "like" : "follow") + " anyone on \(service.rawValue)."
		}
		return { return InstructionCell("No \(service.rawValue) Users", text, "Empty") }
	}
	
	func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		if let userNode = tableNode.nodeForRow(at: indexPath) as? UserNode {
			show(UserViewController(user: userNode.user), sender: nil)
		} else if let viewAllNode = tableNode.nodeForRow(at: indexPath) as? ViewUsersNode, let users = returned ? searchedUsers : followedUsers, let u = users[viewAllNode.s.rawValue] {
			show(ViewUsersViewController(u, channel), sender: nil)
		}
		tableNode.deselectRow(at: indexPath, animated: true)
	}
	
}
