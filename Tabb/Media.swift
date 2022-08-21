//
//  Media.swift
//  Tabb
//
//  Created by Ben Gray on 09/05/2017.
//  Copyright © 2017 crisogray. All rights reserved.
//

import UIKit
import AVFoundation
import AsyncDisplayKit
import youtube_ios_player_helper

class Media: NSObject {
	@objc dynamic var id = ""
	@objc dynamic var type = ""
	@objc dynamic var imageUrl = ""
	@objc dynamic var scale: CGFloat = 9 / 16
	@objc dynamic var service: String = ""
	@objc dynamic var contentUrl: String?
	
	init(_ dictionary: [String : Any?]) {
		super.init()
		for (key, value) in dictionary {
			setValue(value, forKey: key)
		}
	}
}

class MediaViewController: ASViewController<ASScrollNode>, UIScrollViewDelegate {
	
	var zoomNode: ASScrollNode!
	var mediaNode: ASNetworkImageNode!
	var presentationCompleted = false
	var currentOrientation: UIDeviceOrientation = .portrait
	var scale: CGFloat = 1
	
	convenience init(_ imageNode: ASNetworkImageNode) {
		self.init(node: ASScrollNode())
		modalPresentationStyle = .overCurrentContext
		if let gifNode = imageNode as? GIFNode {
			mediaNode = InstaGIFNode(gifNode)
		} else if let imageNode = imageNode as? ImageNode {
			mediaNode = InstaNode(imageNode)
		}
		if let image = imageNode.image {
			scale = image.size.height / image.size.width
		}
		node.frame.size.height = h
		node.view.contentSize = CGSize(width: w, height: h * 3)
		node.view.delegate = self
		node.view.isPagingEnabled = true
		node.view.showsVerticalScrollIndicator = false
		zoomNode = ASScrollNode()
		zoomNode.frame = CGRect(x: 0, y: h, width: w, height: h)
		zoomNode.view.contentSize = CGSize(width: w, height: h)
		zoomNode.addSubnode(mediaNode)
		node.addSubnode(zoomNode)
		NotificationCenter.default.addObserver(self, selector: #selector(MediaViewController.rotate(_:)), name: .UIDeviceOrientationDidChange, object: nil)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		node.view.contentOffset.y = h
		let height = min(h, w * scale), width = height / scale, x = (w - width) / 2, y = (h - height) / 2
		UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
			self.view.backgroundColor = .black
			self.mediaNode.frame = CGRect(x: x, y: y, width: width, height: height)
		}) { success in
			if let gifNode = self.mediaNode as? GIFNode {
				gifNode.play()
			}
			self.presentationCompleted = true
		}
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		var diff = h - scrollView.contentOffset.y, negative = diff <= 0
		if negative { diff *= -1 }
		let y = 1 - diff / (h - mediaNode.frame.origin.y)
		if let window = UIApplication.shared.delegate?.window {
			window?.windowLevel = y == 1 || negative ? UIWindowLevelStatusBar : UIWindowLevelNormal
		}
		if presentationCompleted, scrollView == node.view {
			self.view.backgroundColor = UIColor(white: 0, alpha: y)
			if y <= 0, !scrollView.isTracking {
				dismiss()
			}
		}
	}
	
	@objc func rotate(_ notification: NSNotification) {
		let orientation = UIDevice.current.orientation
		if !orientation.isFlat {
			let maxWidth = orientation.isPortrait ? w : h, maxHeight = orientation.isPortrait ? h : w
			let height = min(maxHeight, maxWidth * scale), width = height / scale, x = (w - width) / 2, y = (h - height) / 2
			UIView.animate(withDuration: 0.25) {
				self.mediaNode.frame = CGRect(x: x, y: y, width: width, height: height)
				if orientation.isPortrait {
					self.mediaNode.view.transform = .identity
				} else {
					let rotation = CGFloat.pi / 2 * (orientation == .landscapeLeft ? 1 : -1)
					self.mediaNode.view.transform = CGAffineTransform(rotationAngle: rotation)
				}
			}
			node.view.isScrollEnabled = orientation.isPortrait
		}
		currentOrientation = orientation
	}
	
	func dismiss() {
		if let window = UIApplication.shared.delegate?.window {
			window?.windowLevel = UIWindowLevelNormal
		}
		dismiss(animated: false, completion: nil)
	}
	
}

class GIFNode: ASVideoNode, ASVideoNodeDelegate {
	
	func didTap(_ videoNode: ASVideoNode) {}
	var assetUrl: URL?
	
	override func placeholderShouldPersist() -> Bool {
		return true
	}
	
	convenience init(url: URL?, assetUrl: URL?, frame: CGRect) {
		self.init()
		self.frame = frame
		clipsToBounds = true
		style.preferredSize = frame.size
		defaultImage = #imageLiteral(resourceName: "Shadow")
		backgroundColor = lightGray
		shouldAutorepeat = true
		shouldAutoplay = true
		self.url = url
		if let url = assetUrl, asset == nil {
			DispatchQueue.main.async {
				self.assetURL = url
			}
		}
		gravity = AVLayerVideoGravity.resizeAspectFill.rawValue
		delegate = self
		
	}

}

class ImageNode: ASNetworkImageNode {
	
	convenience init(url: URL?, frame: CGRect) {
		self.init()
		defaultImage = #imageLiteral(resourceName: "Shadow")
		backgroundColor = lightGray
		clipsToBounds = true
		style.preferredSize = frame.size
		contentMode = .scaleAspectFill
		self.frame = frame
		self.url = url
	}
	
	func didTap(_ videoNode: ASVideoNode) {}
	
}

class MediaNode: ASDisplayNode {
	
	var media: [Media]!
	var stack: Stack!
	var tap: ((ASNetworkImageNode) -> Void)!
	var contentWidth: CGFloat!
	
	convenience init(_ media: [Media], _ contentWidth: CGFloat, _ tap: @escaping (ASNetworkImageNode) -> Void) {
		self.init()
		self.media = media
		self.tap = tap
		self.contentWidth = contentWidth
		automaticallyManagesSubnodes = true
		clipsToBounds = true
	}
	
	@objc func didTap(_ sender: ImageNode) {
		tap(sender)
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		if media.count < 4 {
			let c = CGFloat(media.count), width = (contentWidth - (2 * (c - 1))) / c
			var images = [ASDisplayNode]()
			media.forEach {images.append(imageNode($0, width: width, height: c == 1 ? width * min(media[0].scale, 1) : width + 2))}
			return ASRatioLayoutSpec(ratio: c == 1 ? min(media[0].scale, 1) : 1 / c, child: Stack(.horizontal, 2, images))
		} else {
			let firstStack = Stack(.horizontal, 2, [media[0], media[1]].map {return imageNode($0, width: (contentWidth - 2) / 2, height: w / 2)})
			let secondStack = Stack(.horizontal, 2, [media[2], media[3]].map {return imageNode($0, width: (contentWidth - 2) / 2, height: w / 2)})
			return ASRatioLayoutSpec(ratio: 1, child: Stack(.vertical, 2, [firstStack, secondStack]))
		}
	}
	
	func imageNode(_ media: Media, width: CGFloat, height: CGFloat) -> ASDisplayNode {
		var node: ASNetworkImageNode!
		let frame = CGRect(x: 0, y: 0, width: width, height: height)
		if let assetUrl = media.contentUrl, media.type == "animated_gif" {
			node = GIFNode(url: URL(string: media.imageUrl), assetUrl: URL(string: assetUrl), frame: frame)
		} else if media.type == "video" {
			node = VideoNode(media: media, frame: frame, service: service(media.service))
		} else if media.type == "link" {
			node = MediaImageNode(media: media, frame: frame)
		} else if media.type == "photo" {
			node = ImageNode(url: URL(string: media.imageUrl), frame: frame)
		}
		node.addTarget(self, action: #selector(MediaNode.didTap(_:)), forControlEvents: .touchUpInside)
		return node
	}
	
}

class MediaImageNode: ImageNode {
	
	var media: Media!

	convenience init(media: Media, frame: CGRect) {
		self.init(url: URL(string: media.imageUrl), frame: frame)
		self.media = media
	}
	
	
}

class VideoNode: MediaImageNode {
	
	convenience init(media: Media, frame: CGRect, service: Service.Type) {
		self.init(media: media, frame: frame)
		let button = ASButtonNode()
		button.cornerRadius = 20
		button.frame = CGRect(x: frame.width / 2 - 20, y: frame.height / 2 - 20, width: 40, height: 40)
		button.setImage(#imageLiteral(resourceName: "Play 40pt"), for: .normal)
		button.backgroundColor = service.colour.withAlphaComponent(0.75)
		button.borderColor = UIColor.white.cgColor
		button.borderWidth = 2
		button.isUserInteractionEnabled = false
		addSubnode(button)
	}
	
}

class InstaNode: ImageNode {
	
	convenience init(_ node: ImageNode) {
		self.init(url: node.url, frame: node.convert(node.bounds, to: nil))
		backgroundColor = .clear
		defaultImage = nil
	}
	
}

class InstaGIFNode: GIFNode {
	
	convenience init(_ node: GIFNode) {
		self.init(url: node.url, assetUrl: node.assetURL, frame: node.convert(node.bounds, to: nil))
		if let asset = node.asset {
			self.asset = asset
		}
		backgroundColor = .clear
		defaultImage = nil
		shouldAutoplay = false
	}
}

