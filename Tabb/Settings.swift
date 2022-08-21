//
//  Settings.swift
//  Tabb
//
//  Created by Ben Gray on 11/04/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AsyncDisplayKit

class SettingsViewController: PresentableViewController, UINavigationBarDelegate {
	
	init() {
		super.init(.grouped)
		node.backgroundColor = .white
		navigationItem.title = "Settings"
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError()
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return "Enabled Services"
	}
	
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return services.count
	}
	
	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		if indexPath.section == 0 {
			let service = services[indexPath.row]
			return { return SettingsNode(service.rawValue, service.image, service.hasAccount ? .checkmark : .disclosureIndicator) }
		}
		return { return ASCellNode() }
	}
	
	func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		if indexPath.section == 0 {
			let service = services[indexPath.row]
			if let account = service.account {
				let alertController = UIAlertController(title: "Sign Out \(account.name)",
					message: "This will disable \(service.rawValue), meaning you will no longer be able to use it in any channels",
					preferredStyle: .actionSheet
				)
				alertController.addAction(UIAlertAction(title: "Sign Out", style: .destructive, handler: { action in
					service.removeAccount()
					tableNode.reloadRows(at: [indexPath], with: .none)
				}))
				alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
				present(alertController, animated: true, completion: nil)
			} else {
				service.signIn(viewController: self) { account in
					if service is twitter.Type, account != nil {
						let alert = UIAlertController(title: "Follow @crisogray", message: "Keep up to date on Tabb and show support by following on Twitter", preferredStyle: .alert)
						alert.addAction(UIAlertAction(title: "Sure", style: .default, handler: { _ in twitter.follow() }))
						alert.addAction(UIAlertAction(title: "Nah", style: .cancel, handler: nil))
						self.present(alert, animated: true, completion: nil)
					}
					tableNode.reloadRows(at: [indexPath], with: .none)
					if let account = account, let tracker = GAI.sharedInstance().defaultTracker {
						tracker.send(GAIDictionaryBuilder.createEvent(withCategory: "Interaction", action: "Sign Up",
						                                              label: account.service.rawValue + " - " + account.name,
						                                              value: nil).build() as! [AnyHashable : Any]!)
					}
				}
			}
		}
		node.deselectRow(at: indexPath, animated: true)
	}
	
}

class SettingsNode: ASCellNode {
	
	var title: String!
	var image: UIImage!
	
	convenience init(_ title: String, _ image: UIImage, _ accessoryType: UITableViewCellAccessoryType) {
		self.init()
		self.title = title
		self.image = image
		self.accessoryType = accessoryType
		automaticallyManagesSubnodes = true
		separatorInset.left = 50
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let imageNode = ASImageNode()
		imageNode.image = image
		imageNode.style.preferredSize = CGSize(width: 18, height: 18)
		let stack = Stack(.horizontal, space, [imageNode, Text(title, .systemFont(ofSize: 16, weight: .semibold), .black)])
		stack.alignItems = .center
		return stack.inset(UIEdgeInsetsMake(space, space, space, space))
	}
	
}
