//
//  Post.swift
//  Tabb
//
//  Created by Ben Gray on 08/05/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AsyncDisplayKit
import AVKit
import youtube_ios_player_helper
import SafariServices

class Post: NSObject {
	
	@objc dynamic var id = ""
	@objc dynamic var user = User()
	@objc dynamic var date = Date()
	@objc dynamic var text: String?
	@objc dynamic var media: [Media]?
	@objc dynamic var counts: [String : Int]?
	@objc dynamic var shortcode: String?
	
	// Tweet
	@objc dynamic var inReplyToUserId: String?
	@objc dynamic var inReplyToScreenName: String?
	@objc dynamic var inReplyToStatusId: String?
	@objc dynamic var quote: Post?
	@objc dynamic var retweeter: User?
	
	init(_ dictionary: [String : Any?]) {
		super.init()
		for (key, value) in dictionary {
			setValue(value, forKey: key)
		}
	}
	
}
class RedditLink: Post {
	@objc dynamic var link: String?
}

class RedditComment: RedditLink {
	@objc dynamic var depth: Int = 0
}

class PostsViewController: PresentableViewController, PostDelegate, YTPlayerViewDelegate {
	
	var posts: [Post]!
	var loading: Bool {
		return posts == nil
	}
	var refreshing = false
	var paging = false
	var progressNode = ProgressNode()
	var refreshDate = Date().addingTimeInterval(20)
	var postCells = [[ASCellNode]]()
	var maxPost = postCount
	var pagingData = [String : [String : String]]()
	
	func setup() {
		node.backgroundColor = .white
		node.view.tableFooterView = UIView()
		node.view.separatorColor = shadowGray
		node.displaysAsynchronously = false
		let refreshControl = UIRefreshControl()
		refreshControl.addTarget(self, action: #selector(PostsViewController.refreshChannel(sender:)), for: .valueChanged)
		node.view.refreshControl = refreshControl
		initialGet()
//		node.leadingScreensForBatching = 0.25
	}
	
	func initialGet() {
		getPosts(progressBlock: { progress, service in
			self.progressNode.updateProgress(progress, service: service)
		}) { posts, paging in
			self.posts = posts
			DispatchQueue.main.sync {
				self.node.reloadData()
			}
		}
	}
	
	@IBAction func refreshChannel(sender: UIRefreshControl) {
		sender.endRefreshing()
		if refreshDate < Date(), !loading, !refreshing {
			refreshing = true
			node.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
			for service in servicesWithAccounts {
				progressNode.updateProgress(0, service: service)
			}
			getPosts(progressBlock: { (progress, service) in
				self.progressNode.updateProgress(progress, service: service)
			}, callbackBlock: { posts, _ in
				self.refreshing = false
				self.refreshDate = Date().addingTimeInterval(20)
				DispatchQueue.main.async {
					self.node.deleteRows(at: [IndexPath(row: 0, section: 0)], with: .top)
				}
				var count = 0, needsRefresh = false
				if let posts = self.posts, posts.isEmpty {
					needsRefresh = true
				}
				for post in posts.sorted(by: {return $0.date < $1.date}) where
					!self.posts.contains(where: {$0.id == post.id && $0.user.service == post.user.service}) {
						if let p = self.posts.first, post.date < p.date {} else {
							count += 1
							self.posts.insert(post, at: 0)
						}
				}
				if count > 0 {
					self.maxPost += count
					let indexPaths = (0...count - 1).map {return IndexPath(row: $0, section: 0)}
					DispatchQueue.main.async {
						self.node.performBatchUpdates({
							if needsRefresh {
								self.node.deleteRows(at: [IndexPath(row: 0, section: 0)], with: .top)
							}
							self.node.insertRows(at: indexPaths, with: .top)
						}, completion: nil)
					}
				}
			})
		}
	}
	
	/*func shouldBatchFetch(for tableNode: ASTableNode) -> Bool {
		return false
		//return !loading && !refreshing && !paging && maxPost <= posts?.count ?? 0 && !pagingData.isEmpty && tempMaxPost == nil
		// return false
	}*/
	
	func handlePaging(_ paging: [String : [String : String]]) {
		var date = Date(timeIntervalSince1970: 0)
//		pagingData = paging // REComment
		for item in paging {
			if let timeInterval = item.value["date"], let double = Double(timeInterval)/*, item.key != reddit.rawValue*/ {
				let d = Date(timeIntervalSince1970: double)
				if d > date {
					date = d
				}
			}
		}
		posts.sort { return $0.date > $1.date }
		if let index = posts.index(where: {$0.date == date}), !refreshing {
			maxPost = index + 1
		} else {
			maxPost = posts?.count ?? 0
		}
	}
	
	/*func getBatch(_ callback: @escaping () -> Void) {
		if !loading, !refreshing, !paging, tempMaxPost == nil {
			paging = true
			node.insertRows(at: [IndexPath(row: maxPost, section: 0)], with: .none)
			for service in servicesWithAccounts {
				progressNode.updateProgress(0, service: service)
			}
			getPosts(progressBlock: { (progress, service) in
				self.progressNode.updateProgress(progress, service: service)
			}, callbackBlock: { posts, paging in
				DispatchQueue.global().async {
					self.tempMaxPost = self.maxPost
					for post in posts where !self.posts.contains(where: {$0.id == post.id && $0.user.service == post.user.service}) && post.date < self.posts[self.maxPost - 1].date {
						self.posts.append(post)
					}
					if let paging = paging {
						self.handlePaging(paging)
					}
					print("New maxPost: \(self.maxPost)")
					callback()
				}
			})
		} else {
			callback()
		}
	}
	
	var tempMaxPost: Int?*/
	
	/*func insetRows(from tempMaxPost: Int) {
		paging = false
		if self.maxPost - tempMaxPost > 0 {
			let indexPaths = (tempMaxPost...self.maxPost - 1).map {return IndexPath(row: $0, section: 0)}
			DispatchQueue.main.async {
				self.node.performBatchUpdates({
					self.node.deleteRows(at: [IndexPath(row: tempMaxPost, section: 0)], with: .none)
					self.node.insertRows(at: indexPaths, with: .none)
				}, completion: nil)
			}
		} else {
			DispatchQueue.main.async {
				self.pagingData = [String : [String : String]]()
				self.node.deleteRows(at: [IndexPath(row: tempMaxPost, section: 0)], with: .none)
			}
		}
	}*/
	
	/*func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		if let tempMaxPost = tempMaxPost, scrollView.contentOffset.y > scrollView.contentSize.height - h * 1.5 {
			self.tempMaxPost = nil
			insetRows(from: tempMaxPost)
		}
	}
	
	func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		if let tempMaxPost = tempMaxPost, scrollView.contentOffset.y > scrollView.contentSize.height - h * 1.5 {
			self.tempMaxPost = nil
			insetRows(from: tempMaxPost)
		}
	}
	
	func tableNode(_ tableNode: ASTableNode, willBeginBatchFetchWith context: ASBatchContext) {
		DispatchQueue.main.async {
			self.getBatch {
				DispatchQueue.global().async {
					context.completeBatchFetching(true)
				}
			}
		}
	}*/
	
	func getPosts(progressBlock: @escaping (Float, Service.Type) -> Void, callbackBlock: @escaping ([Post], [String : [String : String]]?) -> Void) {}
	
	override func didPresent() {
		super.didPresent()
	}
	
	override func didUnpresent() {
		super.didUnpresent()
		
	}
	
	func showUser(_ user: User) {
		var user = user
		if user.service == reddit.rawValue {
			user = User(value: ["id" : user.id, "name" : user.name, "service" : reddit.rawValue, "picture" : user.picture])
		}
		show(UserViewController(user: user), sender: nil)
	}
	
	func showUser(_ screenName: String, service: Service.Type) {
		show(UserViewController(screenName, service: service), sender: nil)
	}
	
	func showHashtag(_ hashtag: String, service: Service.Type) {
		show(HashtagViewController(hashtag, service: service), sender: nil)
	}
	
	func showPost(id: String) {
		show(DetailViewController(postId: id), sender: nil)
	}
	
	func showPost(_ post: Post) {
		show(DetailViewController(post: post), sender: nil)
	}
	
	var loadingView: UIView?
	
	func showImage(_ node: ASNetworkImageNode) {
		if node.image == nil {
			return
		}
		if let videoNode = node as? VideoNode, let supernode = node.supernode, videoNode.media.contentUrl == nil {
			let imageNode = InstaNode(videoNode), darkenNode = ASDisplayNode()
			darkenNode.frame.size = imageNode.frame.size
			darkenNode.backgroundColor = UIColor(white: 0, alpha: 0.75)
			imageNode.addSubnode(darkenNode)
			loadingView = imageNode.view
			let playerNode = ASDisplayNode(viewBlock: { () -> UIView in
				let playerView = YTPlayerView(frame: node.frame)
				playerView.delegate = self
				playerView.load(withVideoId: videoNode.media.id, playerVars: ["controls" : 2, "fs" : 1, "modestbranding" : 1,
				                                                              "origin" : "http://www.crisogray.com", "playsinline" : 0,
																			  "rel" : 0, "showinfo" : 0, "iv_load_policy" : 3])
				playerView.setPlaybackQuality(.HD1080)
				return playerView
			})
			supernode.addSubnode(playerNode)
		} else if let videoNode = node as? VideoNode, let string = videoNode.media.contentUrl, let url = URL(string: string) {
			if videoNode.media.service == reddit.rawValue {
				present(SFSafariViewController(url: url), animated: true, completion: nil)
			} else {
				let playerController = AVPlayerViewController(), player = AVPlayer(url: url)
				playerController.player = player
				present(playerController, animated: true, completion: { player.play() })
			}
		} else if let mediaNode = node as? MediaImageNode, let string = mediaNode.media.contentUrl, let url = URL(string: string) {
			present(SFSafariViewController(url: url), animated: true, completion: nil)
		} else {
			present(MediaViewController(node), animated: false, completion: nil)
		}
	}
	
	func playerViewPreferredInitialLoading(_ playerView: YTPlayerView) -> UIView? {
		return loadingView
	}
	
	func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
		playerView.playVideo()
	}
	
	func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		if let postNode = node.nodeForRow(at: indexPath) as? PostNode {
			showPost(postNode.post)
		}
		node.deselectRow(at: indexPath, animated: true)
	}
	
	func tableNode(_ tableNode: ASTableNode, willDisplayRowWith node: ASCellNode) {
		if let postNode = node as? PostNode {
			Timer().perform(#selector(postNode.updateDate), with: nil, afterDelay: 1)
		}
	}
	
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return loading ? 1 : (max(posts.count, self is DetailViewController ? 0 : 1) + (refreshing ? 1 : 0) + (paging ? 1 : 0))
	}
	
	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		if loading || (refreshing && indexPath.row == 0) {
			return {
				return LoadingNode()
			}
		} else if posts.isEmpty {
			return {
				return InstructionCell("No Posts Found", "There was either an error when fetching the posts or there were no posts to fetch.\n\nTry reloading again later.", "Empty")
			}
		} else {
			let post = posts[indexPath.row]
			return {
				return PostNode(post, self)
			}
		}
	}
	
}

protocol PostDelegate {
	func showUser(_ user: User)
	func showUser(_ screenName: String, service: Service.Type)
	func showPost(_ post: Post)
	func showPost(id: String)
	func showHashtag(_ hashtag: String, service: Service.Type)
	func showImage(_ node: ASNetworkImageNode)
}

class PostNode: TextCell {
	
	var post: Post!
	var date: Text!
	
	convenience init(_ post: Post, _ delegate: PostDelegate) {
		self.init()
		self.post = post
		self.delegate = delegate
		s = service(post.user.service)
		automaticallyManagesSubnodes = true
		separatorInset.left = 0
		backgroundColor = .white
		selectionStyle = .none
	}
	
	@objc func showUser() {
		delegate.showUser(post.user)
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let name = Text(post.user.name, .systemFont(ofSize: 16, weight: .semibold), .black)
		name.style.flexShrink = 1
		name.maximumNumberOfLines = 1
		name.truncationMode = .byTruncatingTail
		var nameStack = Stack(.horizontal, space / 3, post.user.verified ? [name, VerifiedNode(post.user.service)] : [name])
		nameStack.alignItems = .center
		date = Text(post.date.timeAgoSinceNow, .systemFont(ofSize: 16), .black)
		if let u = post.user.username {
			let username = Text((post.user.service == reddit.rawValue ? "" : "@") + u, .systemFont(ofSize: 15), .darkGray)
			username.style.flexGrow = 1
			username.style.flexShrink = 1
			username.truncationMode = .byTruncatingTail
			username.maximumNumberOfLines = 1
			username.addTarget(self, action: #selector(PostNode.showUser), forControlEvents: .touchUpInside)
			nameStack = Stack(.vertical, 0, [nameStack, username])
		}
		let imageNode = UserImageNode(post.user, 40)
		[name, date, imageNode].forEach {
			$0.addTarget(self, action: #selector(PostNode.showUser), forControlEvents: .touchUpInside)
		}
		let headerStack = Stack(.horizontal, 12, [imageNode, nameStack, ServiceImageNode(post.user.service), date])
		headerStack.alignItems = .center
		var content: [ASLayoutElement] = [headerStack]
		if let t = post.text, t != "" {
			content.append(TapText(t, .systemFont(ofSize: 17), .black, service(post.user.service), self))
		}
		if let quote = post.quote {
			content.append(QuoteNode(quote, delegate, self, w - space * 2))
		}
		let stack = Stack(.vertical, 12, content)
		stack.alignItems = .stretch
		var contentStack: ASLayoutSpec = stack, retweetStack: RetweetStack?
		if let retweeter = post.retweeter {
			retweetStack = RetweetStack(retweeter.name, #imageLiteral(resourceName: "Retweeted 16pt"), self, #selector(PostNode.showRetweet))
		} else if let screenName = post.inReplyToScreenName {
			retweetStack = RetweetStack("Replying to \(screenName)", #imageLiteral(resourceName: "Reply 16pt"), self, #selector(PostNode.showRetweet))
		}
		if let rtStack = retweetStack {
			let stack = Stack(.vertical, 12, [rtStack, contentStack])
			stack.alignItems = .stretch
			contentStack = stack
		}
		contentStack = contentStack.inset()
		if let media = post.media  {
			let stack = Stack(.vertical, 0, [contentStack, MediaNode(media, w, delegate.showImage)])
			stack.alignItems = .stretch
			contentStack = stack
		}
		return contentStack
	}

	/*override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let name = Text(post.user.name, .systemFont(ofSize: 16, weight: .semibold), .black)
		name.maximumNumberOfLines = 1
		date = Text(post.date.timeAgoSinceNow, .systemFont(ofSize: 16), .black)
		var nameContent: [ASLayoutElement] = [name, ServiceImageNode(post.user.service).inset(UIEdgeInsetsMake(0, 4, 0, 4)), date]
		if let u = post.user.username {
			let username = Text((post.user.service == reddit.rawValue ? "" : "@") + u, .systemFont(ofSize: 15), .darkGray)
			username.style.flexGrow = 1
			username.style.flexShrink = 1
			username.maximumNumberOfLines = 1
			username.addTarget(self, action: #selector(PostNode.showUser), forControlEvents: .touchUpInside)
			nameContent.insert(username, at: 1)
		} else {
			name.style.flexShrink = 1
			name.style.flexGrow = 1
		}
		if post.user.verified {
			nameContent.insert(VerifiedNode(post.user.service), at: 1)
		}
		let nameStack = Stack(.horizontal, space / 3, nameContent)
		nameStack.alignItems = .center
		let imageNode = UserImageNode(post.user, userWidth)
		[name, date, imageNode].forEach {
			$0.addTarget(self, action: #selector(PostNode.showUser), forControlEvents: .touchUpInside)
		}
		var content: [ASLayoutElement] = [nameStack]
		if let t = post.text, t != "" {
			content.append(TapText(t.truncated, .systemFont(ofSize: 17), .black, service(post.user.service), self).inset(UIEdgeInsetsMake(-4, 0, 0, 0)))
		}
		if let quote = post.quote {
			content.append(QuoteNode(quote, delegate, self, w - (userWidth + 44)))
		} else if let media = post.media  {
			let mediaNode = MediaNode(media, w - (userWidth + 44), delegate.showImage)
			mediaNode.cornerRadius = 3
			content.append(mediaNode)
		}
		let stack = Stack(.vertical, 8, content)
		stack.alignItems = .stretch
		var contentStack: ASLayoutSpec = Stack(.horizontal, 12, [imageNode, stack]), retweetStack: RetweetStack?
		if let retweeter = post.retweeter {
			retweetStack = RetweetStack(retweeter.name, #imageLiteral(resourceName: "Retweeted 16pt"), self, #selector(PostNode.showRetweet))
		} else if let screenName = post.inReplyToScreenName, post.inReplyToStatusId != nil {
			retweetStack = RetweetStack("Replying to \(screenName)", #imageLiteral(resourceName: "Reply 16pt"), self, #selector(PostNode.showRetweet))
		}
		if let rtStack = retweetStack {
			let stack = Stack(.vertical, 8, [rtStack, contentStack])
			stack.alignItems = .stretch
			contentStack = stack
		}
		return contentStack.inset()
	}*/
	
	@objc func showRetweet() {
		if let retweeter = post.retweeter {
			delegate.showUser(retweeter)
		} else if let inReplyToStatusId = post.inReplyToStatusId {
			delegate.showPost(id: inReplyToStatusId)
		}
	}
	
	@objc func updateDate() {
		for subnode in self.subnodes where subnode is QuoteNode {
			if let quoteNode = subnode as? QuoteNode {
				quoteNode.date.set(quoteNode.quote.date.timeAgoSinceNow, .systemFont(ofSize: 15), .black)
			}
		}
		date.set(post.date.timeAgoSinceNow, .systemFont(ofSize: 15), .black)
	}
	
}

class RetweetStack: Stack {
	
	convenience init(_ text: String, _ image: UIImage, _ target: Any?, _ selector: Selector, _ width: CGFloat = userWidth) {
		let t = Text(text, .systemFont(ofSize: 16, weight: .medium), .black), i = ASDisplayNode { () -> UIView in
			let button = UIButton(type: .system)
			button.setImage(image, for: .normal)
			button.addTarget(target, action: selector, for: .touchUpInside)
			button.contentMode = .scaleAspectFit
			button.tintColor = .black
			return button
		}
		i.style.preferredSize = CGSize(width: width, height: 16)
		t.addTarget(target, action: selector, forControlEvents: .touchUpInside)
		self.init(.horizontal, 12, [i, t])
		self.alignItems = .center
	}
	
}

class UserImageNode: ImageNode {
	
	convenience init(_ user: User, _ width: CGFloat) {
		self.init(url: URL(string: user.picture), frame: CGRect(x: 0, y: 0, width: width, height: width))
		cornerRadius = width / 2
		backgroundColor = .white
		if user.service == reddit.rawValue, user.picture == "" {
			defaultImage = #imageLiteral(resourceName: "Reddit 40pt")
		}
	}
	
}

extension ASLayoutElement {
	func inset(_ insets: UIEdgeInsets = UIEdgeInsetsMake(12, space, 12, space)) -> ASLayoutSpec {
		return ASInsetLayoutSpec(insets: insets, child: self)
	}
}

class Text: ASTextNode {
	
	convenience init(_ text: String, _ font: UIFont, _ colour: UIColor) {
		self.init()
		truncationMode = .byTruncatingTail
		set(text, font, colour)
	}
	
	func set(_ text: String, _ font: UIFont, _ colour: UIColor) {
		attributedText = NSAttributedString(string: text, attributes: [.font : font, .foregroundColor : colour])
	}
	
}

class TapText: ASTextNode {
	
	var service: Service.Type!
	
	convenience init(_ text: String, _ font: UIFont, _ colour: UIColor, _ service: Service.Type, _ delegate: ASTextNodeDelegate) {
		self.init()
		self.service = service
		self.delegate = delegate
		isUserInteractionEnabled = true
		passthroughNonlinkTouches = true
		set(text, font, colour)
	}
	
	func set(_ text: String, _ font: UIFont, _ colour: UIColor) {
		let string = NSMutableAttributedString(string: text, attributes: [.font : font, .foregroundColor : colour])
		for r in service.enabledTypes {
			do {
				let regex = try NSRegularExpression(pattern: regexes[r]!, options: [])
				regex.matches(in: text, options: [], range: NSRange(location: 0, length: string.length)).forEach {
					string.addAttributes([.link : r, .foregroundColor : service.colour, .font : font, .underlineColor : UIColor.clear], range: $0.range)
				}
			} catch {}
		}
		attributedText = string
	}
	
}

class ServiceImageNode: ASImageNode {
	
	convenience init(_ s: String, _ width: CGFloat = 16) {
		self.init()
		self.image = service(s).image
		style.preferredSize = CGSize(width: width, height: width)
	}
	
}

class VerifiedNode: ASButtonNode {
	
	convenience init(_ s: String) {
		self.init { () -> UIView in
			let button = UIButton(type: .system)
			button.setImage(#imageLiteral(resourceName: "Verified 20pt"), for: .normal)
			button.tintColor = service(s).colour
			button.isUserInteractionEnabled = false
			button.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
			return button
		}
		style.preferredSize = CGSize(width: 16, height: 16)
	}
	
}

class Stack: ASStackLayoutSpec {
	
	convenience init(_ direction: ASStackLayoutDirection, _ spacing: CGFloat, _ children: [ASLayoutElement]) {
		self.init(direction: direction, spacing: spacing, justifyContent: .start, alignItems: .start, children: children)
		style.flexGrow = 1
		style.flexShrink = 1
		style.flexBasis = ASDimension(unit: .fraction, value: 1)
	}
	
}

class QuoteNode: ASDisplayNode {
	
	var quote: Post!
	var postDelegate: PostDelegate!
	var textDelegate: ASTextNodeDelegate!
	var contentWidth: CGFloat!
	var shouldShowUser = false
	var date: Text!
	
	convenience init(_ quote: Post, _ postDelegate: PostDelegate, _ textDelegate: ASTextNodeDelegate, _ contentWidth: CGFloat, _ shouldShowUser: Bool = false) {
		self.init()
		self.quote = quote
		self.postDelegate = postDelegate
		self.textDelegate = textDelegate
		self.contentWidth = contentWidth
		self.shouldShowUser = shouldShowUser
		automaticallyManagesSubnodes = true
		cornerRadius = 3
		borderWidth = 0.5
		borderColor = shadowGray.cgColor
		clipsToBounds = true
	}
	
	@objc func showUser() {
		postDelegate.showUser(quote.user)
	}
	
	@objc func highlight() {
		backgroundColor = lightGray
	}
	
	@objc func unhighlight() {
		backgroundColor = .white
	}
	
	@objc func showPost() {
		unhighlight()
		postDelegate.showPost(quote)
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let name = Text(quote.user.name, .systemFont(ofSize: 16, weight: .semibold), .black)
		name.addTarget(self, action: #selector(QuoteNode.showUser), forControlEvents: .touchUpInside)
		let username = Text("@\(quote.user.username!)", .systemFont(ofSize: 15), .darkGray)
		username.addTarget(self, action: #selector(QuoteNode.showUser), forControlEvents: .touchUpInside)
		username.style.flexShrink = 1
		username.style.flexGrow = 1
		username.maximumNumberOfLines = 1
		date = Text(quote.date.timeAgoSinceNow, .systemFont(ofSize: 16), .black)
		let nameContent: [ASLayoutElement] = quote.user.verified ? [name, VerifiedNode(quote.user.service), username, date] : [name, username, date]
		let nameStack = Stack(.horizontal, space / 3, nameContent)
		nameStack.alignItems = .center
		var content: [ASLayoutElement] = [Stack(.horizontal, space / 2, [UserImageNode(quote.user, 20), nameStack])]
		if let t = quote.text, t != "" {
			let text = TapText(t, .systemFont(ofSize: 16), .black, service(quote.user.service), textDelegate)
			text.passthroughNonlinkTouches = false
			text.addTarget(self, action: #selector(QuoteNode.highlight), forControlEvents: .touchDown)
			text.addTarget(self, action: #selector(QuoteNode.unhighlight), forControlEvents: .touchCancel)
			text.addTarget(self, action: #selector(QuoteNode.showPost), forControlEvents: .touchUpInside)
			content.append(text)
		}
		let stack = Stack(.vertical, space / 2, content)
		stack.alignItems = .stretch
		var contentStack = stack.inset(UIEdgeInsetsMake(space, space, 12, space))
		if let media = quote.media {
			let stack = Stack(.vertical, 0, [contentStack, MediaNode(media, contentWidth, postDelegate.showImage)])
			stack.alignItems = .stretch
			contentStack = stack
		}
		return contentStack
	}
	
}

class ProgressNode: ASCellNode {
	
	var bars = [String : UIProgressView]()
	
	convenience init(_ services: [Service.Type]) {
		self.init()
		services.forEach {
			let bar = UIProgressView(progressViewStyle: .bar)
			bar.progressTintColor = $0.colour
			bar.progress = 0
			bar.trackTintColor = shadowGray
			bar.frame.size.width = w - space * 2
			bars[$0.rawValue] = bar
		}
		backgroundColor = .white
		selectionStyle = .none
		automaticallyManagesSubnodes = true
	}
	
	convenience init(channel: Channel) {
		self.init(servicesWithAccounts.flatMap { service in
			return channel.users.contains(where: {$0.service == service.rawValue}) ? service : nil
		})
	}
	
	func updateProgress(_ progress: Float, service: Service.Type) {
		if let bar = bars[service.rawValue] {
			DispatchQueue.main.async {
				bar.progress = progress
			}
		}
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let stack = Stack(.vertical, space * 3 / 4, bars.sorted(by: {service($0.0).position < service($1.0).position}).map { _, bar in return ASDisplayNode(viewBlock: { () -> UIView in return bar})})
		stack.alignItems = .stretch
		return stack.inset(UIEdgeInsetsMake(space, space, space, space))
	}
	
}

class LoadingNode: ASCellNode {
	
	override init() {
		super.init()
		automaticallyManagesSubnodes = true
		backgroundColor = .white
		selectionStyle = .none
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let node = ASDisplayNode { () -> UIView in
			let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
			activityIndicator.startAnimating()
			return activityIndicator
		}
		node.style.preferredSize = CGSize(width: 32, height: 32)
		return ASCenterLayoutSpec(centeringOptions: .XY, sizingOptions: .minimumXY, child: node).inset()
		
	}
	
}

