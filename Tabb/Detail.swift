//
//  Detail.swift
//  Tabb
//
//  Created by Ben Gray on 19/08/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AsyncDisplayKit
import RealmSwift
import SafariServices

class DetailViewController: PostsViewController {
	
	var post: Post!
	var loadingPost: Bool {
		return post == nil
	}
	var cells = [ASCellNode]()
	
	override init(_ style: UITableViewStyle) {
		super.init(style)
		node.backgroundColor = .white
		node.view.refreshControl = nil
	}
	
	convenience init(post: Post) {
		self.init(.grouped)
		setup(post)
	}
	
	convenience init(postId: String) {
		self.init(.grouped)
		navigationItem.title = "Tweet"
		twitter.getPost(from: postId) { posts in
			if let post = posts.first {
				DispatchQueue.main.async {
					self.setup(post)
				}
			}
		}
	}
	
	required init?(coder aDecoder: NSCoder) { fatalError() }
	
	override func showPost(id: String) {
		if id != post.id {
			super.showPost(id: id)
		}
	}
	
	override func showPost(_ post: Post) {
		if post.id != self.post.id {
			super.showPost(post)
		}
	}
	
	func setup(_ post: Post) {
		self.post = post
		setup()
		navigationItem.title = "Post"
		if post.user.service == twitter.rawValue {
			navigationItem.title = "Tweet"
			if let retweeter = post.retweeter {
				cells.append(PostRetweetNode("\(retweeter.name) retweeted", #imageLiteral(resourceName: "Retweeted 16pt"), self, post))
			} else if let screenName = post.inReplyToScreenName {
				cells.append(PostRetweetNode("Replying to \(screenName)", #imageLiteral(resourceName: "Reply 16pt"), self, post))
			}
		}
		let userNode = DetailUserNode(user: post.user, addFunc: add)
		set(userNode.addButton)
		cells.append(userNode)
		if let text = post.text, text != "" {
			cells.append(PostTextNode(text: text, service: service(post.user.service), delegate: self))
		}
		if let quote = post.quote {
			cells.append(PostQuoteNode(quote: quote, delegate: self))
		}
		var topSpace: CGFloat = 0
		if let counts = post.counts, counts.contains(where: {$0.1 > 0}) {
			cells.append(DetailCountsNode(counts: counts, delegate: self))
			topSpace = 12
		}
		cells.append(DetailDateNode(date: post.date, delegate: self, topSpace: topSpace))
		cells.append(DetailShowNode(service: service(post.user.service), delegate: self))
		if let media = post.media {
			cells.append(PostMediaNode(media: media, delegate: self))
		}
	}
	
	override func getPosts(progressBlock: @escaping (Float, Service.Type) -> Void, callbackBlock: @escaping ([Post], [String : [String : String]]?) -> Void) {
		service(post.user.service).getComments(forPost: post, paging: nil) { posts, paging in callbackBlock(posts, nil) }
	}
	
	func numberOfSections(in tableNode: ASTableNode) -> Int {
		return loadingPost ? 1 : 2
	}
	
	override func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
		if let userNode = tableNode.nodeForRow(at: indexPath) as? UserNode {
			showUser(userNode.user)
		} else if let postNode = tableNode.nodeForRow(at: indexPath) as? PostNode, !(postNode is CommentNode) {
			showPost(postNode.post)
		} else if let showNode = tableNode.nodeForRow(at: indexPath) as? DetailShowNode {
			if let url = URL(string: showNode.service.iosHook + post.id), UIApplication.shared.canOpenURL(url) {
				UIApplication.shared.open(url, options: [:], completionHandler: nil)
			} else if let link = post as? RedditLink, let string = link.link, let url = URL(string: string) {
				present(SFSafariViewController(url: url), animated: true, completion: nil)
			} else {
				let hook = showNode.service.webHook, string = post.user.service == reddit.rawValue ? hook + post.user.id + "/comments/\(post.id)" : hook + post.id
				if let url = URL(string: string) {
					present(SFSafariViewController(url: url), animated: true, completion: nil)
				}
			}
		}
	}
	
	override func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return section == 0 ? loadingPost ? 1 : cells.count : super.tableNode(tableNode, numberOfRowsInSection: 0)
	}
	
	override func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
		if (indexPath.section == 0 && loadingPost) || (indexPath.section == 1 && loading) {
			return { return LoadingNode() }
		} else if indexPath.section == 0 {
			let cell = cells[indexPath.row]
			return { return cell }
		} else {
			let post = posts[indexPath.row]
			if post.user.service == twitter.rawValue {
				return { return PostNode(post, self) }
			} else {
				var indentation = 0
				if let comment = posts[indexPath.row] as? RedditComment {
					indentation = comment.depth
				}
				let commentNode = CommentNode(post, self, indentation)
				if let nextComment = posts[safe: indexPath.row + 1] as? RedditComment, nextComment.depth > 0 {
					commentNode.separatorInset.left = space * CGFloat((nextComment.depth > indentation ? indentation : nextComment.depth) + 1)
				}
				return { return commentNode }
			}
		}
	}
	
	/*func tableNode(_ tableNode: ASTableNode, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
		if indexPath.section == 0 {
			return loadingPost ? LoadingNode() : cells[indexPath.row]
		} else {
			if loading {
				return LoadingNode()
			} else if post.user.service == twitter.rawValue {
				return PostNode(posts[indexPath.row], self)
			} else {
				var indentation = 0
				if let comment = posts[indexPath.row] as? RedditComment {
					indentation = comment.depth
				}
				let commentNode = CommentNode(posts[indexPath.row], self, indentation)
				if let nextComment = posts[safe: indexPath.row + 1] as? RedditComment, nextComment.depth > 0 {
					commentNode.separatorInset.left = space * CGFloat((nextComment.depth > indentation ? indentation : nextComment.depth) + 1)
				}
				return commentNode
			}
		}
	}*/
	
}

class CommentNode: PostNode {
	
	var indentationLevel: Int!
	
	convenience init(_ post: Post, _ delegate: PostDelegate, _ indentationLevel: Int) {
		self.init(post, delegate)
		self.indentationLevel = indentationLevel
	}
	
	@objc func showPost() {
		delegate.showPost(post)
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let name = Text(post.user.name, .systemFont(ofSize: 16, weight: .semibold), .black)
		name.maximumNumberOfLines = 1
		date = Text(post.date.timeAgoSinceNow, .systemFont(ofSize: 16), .black)
		var nameContent: [ASLayoutElement] = post.user.verified ? [name, VerifiedNode(post.user.service), date] : [name, date]
		if let u = post.user.username {
			let username = Text((post.user.service == reddit.rawValue ? "" : "@") + u, .systemFont(ofSize: 15), .darkGray)
			username.style.flexShrink = 1
			username.style.flexGrow = 1
			username.maximumNumberOfLines = 1
			nameContent.insert(username, at: nameContent.count - 1)
		} else {
			name.style.flexGrow = 1
			name.style.flexShrink = 1
		}
		var nameStack = Stack(.horizontal, space / 3, nameContent)
		nameStack.alignItems = .center
		if post.user.service != reddit.rawValue && post.user.picture != "" {
			nameStack = Stack(.horizontal, space / 2, [UserImageNode(post.user, 20), nameStack])
		}
		var content: [ASLayoutElement] = [nameStack]
		if let t = post.text, t != "" {
			content.append(TapText(t, .systemFont(ofSize: 16), .black, service(post.user.service), self))
		}
		let stack = Stack(.vertical, space / 2, content)
		stack.alignItems = .stretch
		var contentStack = stack.inset(UIEdgeInsetsMake(12, space * CGFloat(indentationLevel + 1), 12, space))
		if let media = post.media {
			let stack = Stack(.vertical, 0, [contentStack, MediaNode(media, w, delegate.showImage)])
			stack.alignItems = .stretch
			contentStack = stack
		}
		return contentStack
	}
	
}

class PostRetweetNode: DetailNode {
	
	var retweetStack: RetweetStack!
	var post: Post!
	
	@objc func showRetweet() {
		if let retweeter = post.retweeter {
			delegate.showUser(retweeter)
		} else if let inReplyToStatusId = post.inReplyToStatusId {
			delegate.showPost(id: inReplyToStatusId)
		}
	}
	
	convenience init(_ text: String, _ image: UIImage, _ delegate: PostDelegate, _ post: Post) {
		self.init(delegate: delegate)
		self.post = post
		retweetStack = RetweetStack(text, image, self, #selector(PostRetweetNode.showRetweet), 40)
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return retweetStack.inset(UIEdgeInsetsMake(12, space, 0, space))
	}
	
}


class DetailUserNode: UserNode {
	
	var addFunc: ((User, UserButton) -> Void)!
	
	convenience init(user: User, addFunc: @escaping (User, UserButton) -> Void) {
		self.init(user, added: false, delegate: nil)
		self.addFunc = addFunc
		addButton = UserButton(User(value: ["id" : user.id, "name" : user.name,
		                                    "username" : user.service == reddit.rawValue ? nil : user.username,
		                                    "service" : user.service, "picture" : user.picture])) { user in self.addFunc(user, self.addButton) }
		addButton.style.preferredSize.width = 56
		separatorInset.left = w
		selectionStyle = .none
	}
	
}

class TextCell: DetailNode, ASTextNodeDelegate {
	var s: Service.Type!

	func textNode(_ textNode: ASTextNode, shouldHighlightLinkAttribute attribute: String, value: Any, at point: CGPoint) -> Bool {
		return true
	}
	
	func textNode(_ textNode: ASTextNode, tappedLinkAttribute attribute: String, value: Any, at point: CGPoint, textRange: NSRange) {
		if let string = textNode.attributedText?.string {
			let nsstring = string as NSString, subrange = nsstring.substring(with: textRange) as String, sanitised = subrange
				.replacingOccurrences(of: " ", with: "")
				.replacingOccurrences(of: "@", with: "")
			switch value as! String {
			case "mention":
				delegate.showUser(sanitised, service: s)
			case "hashtag":
				delegate.showHashtag(sanitised, service: s)
			default:
				if let url = URL(string: sanitised), UIApplication.shared.canOpenURL(url) {
					UIApplication.shared.open(url, options: [:], completionHandler: nil)
				}
			}
		}
	}
}

class DetailNode: ASCellNode {
	
	var delegate: PostDelegate!
	
	convenience init(delegate: PostDelegate) {
		self.init()
		self.delegate = delegate
		automaticallyManagesSubnodes = true
		backgroundColor = .white
		separatorInset.left = w
		selectionStyle = .none
	}
	
}

class PostTextNode: TextCell {
	
	var text: String!
	
	convenience init(text: String, service: Service.Type, delegate: PostDelegate) {
		self.init(delegate: delegate)
		self.text = text
		s = service
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return TapText(text, .systemFont(ofSize: 17), .black, s, self).inset(UIEdgeInsetsMake(0, space, 12, space))
	}
	
}

class PostMediaNode: DetailNode {
	
	var media: [Media]!
	
	convenience init(media: [Media], delegate: PostDelegate) {
		self.init(delegate: delegate)
		self.media = media
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return ASWrapperLayoutSpec(layoutElement: MediaNode(media, w, delegate.showImage))
	}
}

class PostQuoteNode: TextCell {
	
	var quote: Post!
	
	convenience init(quote: Post, delegate: PostDelegate) {
		self.init(delegate: delegate)
		self.quote = quote
		s = twitter.self
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return QuoteNode(quote, delegate, self, w - space * 2, true).inset(UIEdgeInsetsMake(0, space, 12, space))
	}
	
}

class DetailCountsNode: DetailNode {
	
	var counts: [String : Int]!

	convenience init(counts: [String : Int], delegate: PostDelegate) {
		self.init(delegate: delegate)
		self.counts = counts
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		var content = [ASLayoutElement]()
		for (label, count) in counts.sorted(by: { return $0.0.characters.count < $1.0.characters.count }) where count != 0 {
			let l = count == 1 ? String(label[..<label.index(label.endIndex, offsetBy: -1)]) : label
			content.append(Text("\(count.formatted) \(l.capitalized)", .systemFont(ofSize: 15), .darkGray))
		}
		return Stack(.horizontal, space, content).inset(UIEdgeInsetsMake(0, space, 0, space))
	}
	
}

class DetailDateNode: DetailNode {
	
	var date: Date!
	var topSpace: CGFloat!
	
	convenience init(date: Date, delegate: PostDelegate, topSpace: CGFloat = 12) {
		self.init(delegate: delegate)
		self.date = date
		self.topSpace = topSpace
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "d MMM yyyy h:mm a"
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		return Text(dateFormatter.string(from: date).uppercased(), .systemFont(ofSize: 15), .darkGray).inset(UIEdgeInsetsMake(topSpace, space, 0, space))
	}
	
	
}

class DetailShowNode: DetailNode {
	
	var service: Service.Type!
	
	convenience init(service: Service.Type, delegate: PostDelegate) {
		self.init(delegate: delegate)
		self.service = service
		accessoryType = .disclosureIndicator
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		return Text("View on \(service.rawValue)", .systemFont(ofSize: 15, weight: .semibold), service.colour).inset(UIEdgeInsetsMake(12, space, 12, space))
	}
	
}

extension Int {
	
	var formatted: String {
		var string = "\(self)"
		let i = Float(self)
		if i >= 1000 && i < 100000 {
			string = "\(String(format: "%.1f", i / 1000))K"
		} else if i >= 100000 && i < 1000000 {
			string = "\(self / 1000)K"
		} else if i >= 1000000 {
			string = "\(String(format:  i >= 10000000 ? "%.1f" : "%.2f", i / 1000000))M"
		}
		return string.replacingOccurrences(of: ".0", with: "")
	}
	
}
