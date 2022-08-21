//
//  Menu.swift
//  Tabb
//
//  Created by Ben Gray on 07/04/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import RealmSwift

extension ContainerViewController: UITableViewDataSource, UITableViewDelegate {
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return section == 0 ? titles.count : channels.count + (showNewCell ? 1 : 0)
	}

	func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let cell = tableView.cellForRow(at: indexPath), !(cell is NewChannelCell) {
			if currentIndex != indexPath, let cell = tableView.cellForRow(at: currentIndex) {
				cell.contentView.backgroundColor = .clear
			}
			cell.contentView.backgroundColor = UIColor(white: 1, alpha: 0.25)
		}
		if currentIndex == indexPath {
			toggleMenu()
		} else if indexPath.section == 0 {
			currentIndex = indexPath
			[trending, discoverChannels][indexPath.row]()
		} else if let channel = channels[safe: indexPath.row] {
			currentIndex = indexPath
			load(channel: channel)
		}
	}
	
	func handleLongPress(channel: Channel) {
		let alert = UIAlertController(title: "Edit Channel", message: "Delete or rename \"\(channel.name)\"", preferredStyle: .alert)
		alert.addTextField { textField in
			textField.text = channel.name
			textField.textAlignment = .center
		}
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
			try! realm.write {
				guard let index = self.channels.index(of: channel) else {
					return
				}
				if let channelViewController = self.channelViewControllers[channel.id] {
					NotificationCenter.default.removeObserver(channelViewController)
					self.channelViewControllers.removeValue(forKey: channel.id)
				}
				realm.delete(channel)
				let iP = IndexPath(row: index, section: 1)
				if iP == self.currentIndex {
					self.currentIndex = IndexPath(row: -1, section: -1)
					let welcomeViewController = WelcomeViewController(.plain)
					welcomeViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "Menu 24pt"), style: .plain, target: self, action: #selector(ContainerViewController.toggleMenu))
					self.navController.viewControllers = [welcomeViewController]
				} else if iP.row < self.currentIndex.row, self.currentIndex.section == 1 {
					self.currentIndex.row -= 1
				}
				self.menuTableView.deleteRows(at: [iP], with: .left)
				if self.channels.isEmpty {
					self.instructionView.alpha = 0
					self.instructionView.isHidden = false
					UIView.animate(withDuration: 0.25, animations: {
						self.instructionView.alpha = 1
					})
				}
			}
		}))
		alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
			if let textField = alert.textFields?.first, let text = textField.text, text != "", text != channel.name {
				try! realm.write {
					guard let index = self.channels.index(of: channel) else {
						return
					}
					channel.name = text
					if let cell = self.menuTableView.cellForRow(at: IndexPath(row: index, section: 1)), let titleLabel = cell.textLabel {
						titleLabel.text = text
					}
					if let channelViewController = self.channelViewControllers[channel.id] {
						channelViewController.navigationItem.title = text
					}
				}
			}
		}))
		present(alert, animated: true, completion: nil)
	}
	
	func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		if indexPath == currentIndex {
			cell.setSelected(true, animated: false)
		}
	}
	
	@IBAction func showNewChannel() {
		if !showNewCell {
			showNewCell = true
			newChannelCell.textField.text = nil
			menuTableView.insertRows(at: [IndexPath(row: channels.count, section: 1)], with: .left)
			newChannelCell.textField.becomeFirstResponder()
			menuTableView.scrollToRow(at: IndexPath(row: channels.count, section: 1), at: .top, animated: true)
		}
	}
	
	@IBAction func hideNewChannel() {
		if showNewCell {
			showNewCell = false
			canDismiss = false
			newChannelCell.textField.resignFirstResponder()
			menuTableView.deleteRows(at: [IndexPath(row: channels.count, section: 1)], with: .left)
		}
	}
	
	func returnNewChannel(title: String) {
		if showNewCell {
			showNewCell = false
			let date = Date(), channel = Channel(value: [createId(from: title, date: date), title, "", true, date])
			try! realm.write {
				realm.add(channel)
				let indexPath = IndexPath(row: channels.count - 1, section: 1)
				menuTableView.reloadRows(at: [indexPath], with: .fade)
				newChannelCell.textField.resignFirstResponder()
				menuTableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3, execute: {
					self.tableView(self.menuTableView, didSelectRowAt: indexPath)
				})
				if let tracker = GAI.sharedInstance().defaultTracker {
					tracker.send(GAIDictionaryBuilder.createEvent(withCategory: "Interaction", action: "New Channel", label: title, value: nil).build() as! [AnyHashable : Any]!)
				}
			}
		}
	}
	
	func createId(from title: String, date: Date) -> String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "ddMMyyhhmmssSSSS"
		let dateString = dateFormatter.string(from: date)
		if let vendorString = UIDevice.current.identifierForVendor?.uuidString {
			return dateString + title.lowercased() + vendorString.replacingOccurrences(of: "-", with: "").lowercased()
		}
		return dateString + title.lowercased()
	}
	
	func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
		return !showNewCell
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return channels.count == 0 && indexPath.section == 1 && !showNewCell ? h * 0.5 : 44
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.row == channels.count, showNewCell, indexPath.section == 1 {
			return newChannelCell
		} else if let menuCell = tableView.dequeueReusableCell(withIdentifier: "Menu") as? MenuCell, let textLabel = menuCell.textLabel {
			textLabel.text = indexPath.section == 0 ? titles[indexPath.row] : channels[indexPath.row].name
			if indexPath.section == 1 {
				menuCell.setup(channel: channels[safe: indexPath.row], handleFunction: handleLongPress)
			}
			return menuCell
		}
		return UITableViewCell()
	}
	
}

class MenuCell: UITableViewCell {
	
	var channel: Channel?
	var handleFunction: ((Channel) -> Void)!
	
	@objc func handleLongPress(sender: UILongPressGestureRecognizer) {
		if let channel = channel, sender.state == .began {
			handleFunction(channel)
		}
	}
	
	func setup(channel: Channel?, handleFunction: @escaping (Channel) -> Void) {
		self.channel = channel
		self.handleFunction = handleFunction
		if let gestureRecognizers = gestureRecognizers {
			gestureRecognizers.forEach{removeGestureRecognizer($0)}
		}
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(MenuCell.handleLongPress(sender:)))
		longPress.minimumPressDuration = 0.5
		addGestureRecognizer(longPress)
	}
	
}

class NewChannelCell: UITableViewCell, UITextFieldDelegate {
	
	@IBOutlet var textField: UITextField!
	var returnNewChannel: ((_: String) -> Void)!
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if let text = textField.text, text.replacingOccurrences(of: " ", with: "") != "" {
			returnNewChannel(text)
			return true
		}
		return false
	}
	
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		guard let text = textField.text else { return true }
		return text.count + string.count - range.length <= 20
	}
	
}

