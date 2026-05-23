//
//  CacheManager.swift
//  ChaptrAssignment
//
//  Created by vaibhav.sad on 23/05/26.
//

import SwiftUI
import AVKit
import CoreMedia
import UIKit

final class VideoCache {
    static let shared = VideoCache()

    private let playerItemCache = NSCache<NSString, AVPlayerItem>()
    private let thumbnailCache  = NSCache<NSString, UIImage>()

    private init() {
        playerItemCache.countLimit      = 10
        thumbnailCache.countLimit       = 50
        thumbnailCache.totalCostLimit   = 50 * 1024 * 1024
    }

    // MARK: Player Items

    func playerItem(for urlString: String) -> AVPlayerItem? {
        guard let url = URL(string: urlString) else { return nil }
        let key = urlString as NSString
        if let cached = playerItemCache.object(forKey: key) {
            return AVPlayerItem(asset: cached.asset)
        }
        let item = AVPlayerItem(url: url)
        playerItemCache.setObject(item, forKey: key)
        return item
    }

    // MARK: Thumbnails

    func thumbnail(for urlString: String) -> UIImage? {
        thumbnailCache.object(forKey: urlString as NSString)
    }

    func cacheThumbnail(_ image: UIImage, for urlString: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        thumbnailCache.setObject(image, forKey: urlString as NSString, cost: cost)
    }

    // MARK: Prefetch
    func prefetchThumbnails(for urlStrings: [String]) {
        for urlString in urlStrings {
            guard
                thumbnail(for: urlString) == nil,
                let url = URL(string: urlString)
            else { continue }

            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self,
                      let data,
                      let img = UIImage(data: data) else { return }
                self.cacheThumbnail(img, for: urlString)
            }.resume()
        }
    }
}

// MARK: - Cached Async Image

struct CachedAsyncImage: View {
    let urlString: String
    var contentMode: ContentMode = .fill
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.black
                    .onAppear { load() }
            }
        }
    }

    private func load() {
        if let cached = VideoCache.shared.thumbnail(for: urlString) {
            self.image = cached
            return
        }
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = UIImage(data: data) else { return }
            VideoCache.shared.cacheThumbnail(img, for: urlString)
            DispatchQueue.main.async { self.image = img }
        }.resume()
    }
}
