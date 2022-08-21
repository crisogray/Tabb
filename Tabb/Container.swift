//
//  Container.swift
//  Tabb
//
//  Created by Ben Gray on 07/04/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import Pastel
import AsyncDisplayKit
import TwitterKit

let menuWidth: CGFloat = 0.55
let collapsedScale: CGFloat = 0.75

class ContainerViewController: UIViewController, UIScrollViewDelegate {
	
	@IBOutlet var containerScrollView: ContainerScrollView!
	@IBOutlet var containerX: NSLayoutConstraint!
	@IBOutlet var settingsButton: UIButton!
	@IBOutlet var settingsX: NSLayoutConstraint!
	@IBOutlet var newContainer: UIView!
	@IBOutlet var newX: NSLayoutConstraint!
	@IBOutlet var tabbContainer: UIView!
	@IBOutlet var tabbX: NSLayoutConstraint!
	@IBOutlet var menuX: NSLayoutConstraint!
	@IBOutlet var menuTableView: UITableView!
	@IBOutlet var containerView: UIView!
	@IBOutlet var backgroundView: UIView!
	@IBOutlet var instructionView: UIView!
	@IBOutlet var tapRecogniser: UITapGestureRecognizer!
	var navController: UINavigationController!
	var navContainer: UIViewController!
	var channelViewControllers = [String : ChannelViewController]()
	var trendingViewController: TrendingViewController?
	var presenting = false
	var hasAppeared = false
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return presenting ? .default : .lightContent
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		guard let container = childViewControllers.first, let nav = container.childViewControllers.first as? UINavigationController else {
			fatalError()
		}
		NotificationCenter.default.addObserver(self, selector: #selector(ContainerViewController.keyboardWillChangeFrame(notification:)), name: .UIKeyboardWillChangeFrame, object: nil)
		navContainer = container
		navController = nav
		newChannelCell = menuTableView.dequeueReusableCell(withIdentifier: "NewChannel") as! NewChannelCell
		newChannelCell.textField.attributedPlaceholder = NSAttributedString(string: "Name", attributes: [
			.foregroundColor : UIColor(white: 1, alpha: 0.25)])
		newChannelCell.returnNewChannel = returnNewChannel
		containerScrollView.shouldScroll = shouldScroll
		let pastelView = PastelView(frame: UIScreen.main.bounds)
		pastelView.startPastelPoint = .bottom
		pastelView.endPastelPoint = .topRight
		pastelView.setColors([UIColor(red: 0, green: 0.88, blue: 1, alpha: 1), UIColor(red: 0.88, green: 0, blue: 1, alpha: 1)])
		pastelView.animationDuration = 6
		pastelView.startAnimation()
		view.insertSubview(pastelView, at: 0)
	}
	
	@objc func keyboardWillChangeFrame(notification: NSNotification) {
		if let userInfo = notification.userInfo, let frame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect {
			let y = menuTableView.frame.origin.y + menuTableView.frame.height - frame.origin.y
			menuTableView.contentInset.bottom = max(0, y + space)
			menuTableView.scrollIndicatorInsets.bottom = max(0, y)
		}
	}
	
	override func viewDidLayoutSubviews() {
		if !hasAppeared {
			hasAppeared = true
			if servicesWithAccounts.isEmpty, let onboardingViewController = storyboard?.instantiateViewController(withIdentifier: "Onboarding") {
				present(onboardingViewController, animated: true, completion: nil)
				containerScrollView.contentOffset.x = w
				togglePresentation(true)
				let welcomeViewController = WelcomeViewController(.plain)
				welcomeViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "Menu 24pt"), style: .plain, target: self, action: #selector(ContainerViewController.toggleMenu))
				navController.viewControllers = [welcomeViewController]
			} else {
				containerScrollView.contentOffset.x = 0
				scrollViewDidScroll(containerScrollView)
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
					if let id = UserDefaults.standard.string(forKey: "currentId"), let index = self.channels.index(where: {$0.id == id}) {
						self.tableView(self.menuTableView, didSelectRowAt: IndexPath(row: index, section: 1))
					} else {
						self.tableView(self.menuTableView, didSelectRowAt: IndexPath(row: 0, section: 0))
					}
				})
			}
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if let pastelView = view.subviews.first as? PastelView {
			pastelView.startAnimation()
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
//		if let scrollView = view.subviews[1] as? ContainerScrollView {
//			scrollView.contentOffset.x = w
//		}
	}
	
	func shouldScroll() -> Bool {
		return navController.viewControllers.first == navController.visibleViewController
	}
	
	func trending() {
		trendingViewController = trendingViewController ?? TrendingViewController()
		present(trendingViewController!)
		DispatchQueue.global().async {
			UserDefaults.standard.set("Trending", forKey: "currentId")
		}
	}
	
	func load(channel: Channel) {
		let channelViewController = channelViewControllers[channel.id] ?? ChannelViewController(channel: channel), id = channel.id
		channelViewControllers[id] = channelViewController
		present(channelViewController)
		DispatchQueue.global().async {
			UserDefaults.standard.set(id, forKey: "currentId")
		}
	}
	
	func discoverChannels() {
		toggleMenu()
	}
	
	@IBAction func showSettings() {
		presentNonMenu(viewController: navController.visibleViewController as? SettingsViewController ?? SettingsViewController())
	}
	
	func presentNonMenu(viewController: PresentableViewController) {
		if let cell = menuTableView.cellForRow(at: currentIndex) {
			cell.contentView.backgroundColor = .clear
		}
		currentIndex = IndexPath(row: -1, section: -1)
		present(viewController)
	}
	
	func present(_ viewController: PresentableViewController) {
		if navController.visibleViewController !== viewController {
			navController.setViewControllers([viewController], animated: false)
			viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "Menu 24pt"), style: .plain, target: self, action: #selector(ContainerViewController.toggleMenu))
		}
		toggleMenu()
	}
	
	@IBAction func toggleMenu() {
		if presentedViewController == nil {
			containerScrollView.setContentOffset(CGPoint(x: presenting ? 0 : w, y: 0), animated: true)
		}
	}
	
	func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		if let tableView = scrollView as? UITableView {
			canDismiss = tableView.numberOfRows(inSection: 1) == channels.count + 1
		} else if scrollView.contentOffset.x == w {
			togglePresentation(true)
		}
	}
	
	func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		if scrollView == containerScrollView, scrollView.contentOffset.x == w {
			togglePresentation(true)
		}
	}
	
	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		if scrollView == containerScrollView, scrollView.contentOffset.x == w {
			togglePresentation(true)
		}
	}
	
	func togglePresentation(_ isPresenting: Bool) {
		presenting = isPresenting
		navContainer.view.layer.cornerRadius = isPresenting ? 0 : 6
		tapRecogniser.isEnabled = !isPresenting
		setNeedsStatusBarAppearanceUpdate()
		if let viewController = navController.visibleViewController as? PresentableViewController {
			isPresenting ? viewController.didPresent() : viewController.didUnpresent()
			viewController.view.isUserInteractionEnabled = isPresenting
			navController.navigationBar.isUserInteractionEnabled = isPresenting
		}
		instructionView.isHidden = !(!isPresenting && channels.count == 0)
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if scrollView == menuTableView, showNewCell, scrollView.isTracking, !menuTableView.visibleCells.contains(newChannelCell) {
			hideNewChannel()
		} else if scrollView == containerScrollView {
			let absx = scrollView.contentOffset.x / w, x = absx * (2 - absx), scale = collapsedScale + ((1 - collapsedScale) * absx), xx = (1 - x - collapsedScale) * 1 / (1 - collapsedScale)
			containerView.transform = CGAffineTransform(scaleX: scale, y: scale)
			backgroundView.transform = CGAffineTransform(scaleX: scale, y: scale)
			containerX.constant = menuWidth * w - menuWidth * x * w + scrollView.contentOffset.x - (w - w * scale) / 2
			menuX.constant = -menuWidth * w * x + scrollView.contentOffset.x
			tabbX.constant = -tabbContainer.frame.width + tabbContainer.frame.width * xx + scrollView.contentOffset.x
			newX.constant = -newContainer.frame.width + newContainer.frame.width * xx + scrollView.contentOffset.x
			settingsX.constant = w - xx * (settingsButton.frame.width - 16) + scrollView.contentOffset.x
			[tabbContainer, newContainer, settingsButton, menuTableView, instructionView].forEach { $0!.alpha = 1 - x }
			if presenting { togglePresentation(false) }
			if showNewCell { hideNewChannel() }
		}
	}
	
	// MARK: Menu Table View
	
	var currentIndex = IndexPath(row: -1, section: -1)
	var showNewCell = false
	var canDismiss = false
	var newChannelCell: NewChannelCell!
	var channels: [Channel] {
		return realm.objects(Channel.self).sorted(by: {$0.date < $1.date}).map{return $0}
	}
	let titles = ["Trending"]
	
}

class PresentableViewController: ASViewController<ASTableNode>, ASTableDelegate, ASTableDataSource {
	
	var isPresented = false
	
	init(_ style: UITableViewStyle) {
		super.init(node: ASTableNode(style: style))
		NotificationCenter.default.addObserver(self, selector: #selector(PresentableViewController.keyboardWillChangeFrame(notification:)), name: .UIKeyboardWillChangeFrame, object: nil)
		node.delegate = self
		node.dataSource = self
	}
	
	override func viewDidAppear(_ animated: Bool) {
		guard let tracker = GAI.sharedInstance().defaultTracker,
			let title = navigationItem.title,
			let builder = GAIDictionaryBuilder.createScreenView() else { return }
		tracker.set(kGAIScreenName, value: title)
		tracker.send(builder.build() as [NSObject : AnyObject])
		GAI.sharedInstance().dispatch()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError()
	}
	
	@objc func keyboardWillChangeFrame(notification: NSNotification) {
		if let userInfo = notification.userInfo, let frame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect {
			let y = h - frame.origin.y
			node.view.contentInset.bottom = max(0, y)
			node.view.scrollIndicatorInsets.bottom = max(0, y)
		}
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if let refreshControl = node.view.refreshControl {
			node.view.sendSubview(toBack: refreshControl)
		}
	}
	
	func didPresent() {
		isPresented = true
	}
	
	func didUnpresent() {
		isPresented = false
	}
	
}

class ContainerScrollView: UIScrollView {
	
	var shouldScroll: (() -> Bool)?
	
	override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		guard let shouldScroll = shouldScroll else {return true}
		return shouldScroll()
	}
	
}

class InstructionCell: ASCellNode {
	
	var title: String!
	var instruction: String!
	
	convenience init(_ title: String, _ instruction: String, _ nib: String) {
		self.init()
		self.title = title
		self.instruction = instruction
		automaticallyManagesSubnodes = true
		DispatchQueue.main.sync {
			let instructionView = Bundle.main.loadNibNamed(nib, owner: nil, options: [:])![0] as! InstructionView
			instructionView.titleLabel.text = title
			instructionView.instructionLabel.text = instruction
			instructionView.frame.size.width = w
			instructionView.layoutIfNeeded()
			let frame = instructionView.instructionLabel.frame
			self.style.preferredSize.height = 16 + frame.origin.y + frame.height
			self.view.addSubview(instructionView)
		}
		selectionStyle = .none
		separatorInset.left = nib == "Empty" ? 0 : w
	}
	
	
}

class InstructionView: UIView {
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var instructionLabel: UILabel!
}
