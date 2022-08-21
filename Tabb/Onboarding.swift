//
//  Onboarding.swift
//  Tabb
//
//  Created by Ben Gray on 17/09/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AsyncDisplayKit
import Pastel

class OnboardingViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
	
	@IBOutlet weak var tabbLabel: UILabel!
	@IBOutlet weak var instructionLabel: UILabel!
	@IBOutlet weak var tableView: UITableView!
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return services.count }
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Service", for: indexPath) as! ServiceCell, service = services[indexPath.row]
		cell.setup(service.rawValue, UIImage(named: service.rawValue + " White 24pt")!, service.hasAccount ? .checkmark : .disclosureIndicator)
		return cell
	}
	
	@IBAction func getStarted() {
		if servicesWithAccounts.isEmpty {
			let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
			animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
			animation.duration = 0.6
			animation.values = [-10.0, 10.0, -7.0, 7.0, -4.0, 4.0, 0.0]
			instructionLabel.layer.add(animation, forKey: "shake")
		} else {
			dismiss(animated: true, completion: nil)
		}
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let service = services[indexPath.row]
		if let account = service.account {
			let alertController = UIAlertController(title: "Sign Out \(account.name)",
				message: "This will disable \(service.rawValue), meaning you will no longer be able to use it in any channels",
				preferredStyle: .actionSheet
			)
			alertController.addAction(UIAlertAction(title: "Sign Out", style: .destructive, handler: { action in
				service.removeAccount()
				tableView.reloadRows(at: [indexPath], with: .none)
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
				
				tableView.reloadRows(at: [indexPath], with: .none)
				if let account = account, let tracker = GAI.sharedInstance().defaultTracker {
					tracker.send(GAIDictionaryBuilder.createEvent(withCategory: "Interaction", action: "Sign Up",
																  label: account.service.rawValue + " - " + account.name,
																  value: nil).build() as! [AnyHashable : Any]!)
				}
			}
		}
		tableView.deselectRow(at: indexPath, animated: true)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		let pastelView = PastelView(frame: UIScreen.main.bounds)
		pastelView.startPastelPoint = .bottom
		pastelView.endPastelPoint = .topRight
		pastelView.setColors([UIColor(red: 0, green: 0.88, blue: 1, alpha: 1), UIColor(red: 0.88, green: 0, blue: 1, alpha: 1)])
		pastelView.animationDuration = 6
		pastelView.startAnimation()
		view.insertSubview(pastelView, at: 0)
		if w < 375 {
			tabbLabel.font = tabbLabel.font.withSize(56)
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if let pastelView = view.subviews.first as? PastelView {
			pastelView.startAnimation()
		}
		guard let tracker = GAI.sharedInstance().defaultTracker,
			let builder = GAIDictionaryBuilder.createScreenView() else { return }
		tracker.set(kGAIScreenName, value: "Onboarding")
		tracker.send(builder.build() as [NSObject : AnyObject])
		GAI.sharedInstance().dispatch()
	}
	
}

class WelcomeViewController: PresentableViewController {
	
	var height: CGFloat!
	
	override init(_ style: UITableViewStyle) {
		super.init(style)
		navigationItem.title = "Welcome"
		node.view.isScrollEnabled = false
		node.view.bounces = false
		height = node.frame.height
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError()
	}
	
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return 1
	}
	
	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		return {
			return WelcomeCellNode()
		}
	}
	
}

class WelcomeCellNode: ASCellNode {
	
	override init() {
		super.init()
		separatorInset.left = w
		style.preferredSize.height = h - 128
		selectionStyle = .none
		DispatchQueue.main.async {
			let welcomeView = Bundle.main.loadNibNamed("Welcome", owner: nil, options: nil)![0] as! WelcomeView
			welcomeView.frame = UIScreen.main.bounds
			welcomeView.frame.size.height -= 128
			self.addSubnode(ASDisplayNode(viewBlock: {
				return welcomeView
			}))
		}
	}
	
}

class WelcomeView: UIView {
		
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
}

class ServiceCell: UITableViewCell {
	
	@IBOutlet weak var serviceImage: UIImageView!
	@IBOutlet weak var label: UILabel!
	
	func setup(_ title: String, _ image: UIImage, _ accessoryType: UITableViewCellAccessoryType) {
		label.text = title
		serviceImage.image = image
		self.accessoryType = accessoryType
	}
	
	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		super.setHighlighted(highlighted, animated: animated)
		backgroundColor = UIColor(white: 1, alpha: highlighted ? 0.125 : 0.25)
	}
	
	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		backgroundColor = UIColor(white: 1, alpha: selected ? 0.125 : 0.25)
	}
	
}
