//
//  ImageFileData.swift
//  FlatLive
//
//  Created by glediaer on 2020/06/16.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import Foundation

@objcMembers
class ImageFileData: Codable {
    var fileName: String?
    var isSelected: Bool?
    var image: Data?
    var imgUrl: String?
}
