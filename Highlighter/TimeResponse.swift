//
//  Time.swift
//  Highlighter
//
//  Created by YOONJONG on 2022/04/19.
//

import Foundation

struct TimeResponse: Codable{
    let success:Bool?
    let time:[Time]
}
struct Time:Codable{
    let min:Int?
    let max:Int?
}
