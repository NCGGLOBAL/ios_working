//
//  ImageModel.swift
//  UnniTv
//
//  Created by glediaer on 2020/06/13.
//  Copyright © 2020 ncgglobal. All rights reserved.
//

import Foundation

@objcMembers
class ImageModel: Codable {
    var token: String?  // 사진 임시저장시 토큰값
    var imgArr: Array<ImageData>?  // 이미지 정보
    var pageGbn: String?    // 1 : 신규페이지에서 진입, 2 : 수정페이지에서 진입
    var cnt: Int?
}
