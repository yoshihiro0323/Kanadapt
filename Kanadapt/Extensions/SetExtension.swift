//
//  SetExtension.swift
//
//  Fluor
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import DefaultsWrapper

struct DefaultsSet<Element: UserDefaultsConvertible & Hashable>: UserDefaultsConvertible {
    var value: Set<Element>
    
    // UserDefaultsへ保存するための変換メソッド
    func convertedObject() -> [Element.PropertyListSerializableType] {
        return value.map { $0.convertedObject() }
    }
    
    // UserDefaultsからインスタンス化するためのメソッド
    static func instanciate(from object: [Element.PropertyListSerializableType]) -> DefaultsSet? {
        let set = Set(object.compactMap { Element.instanciate(from: $0) })
        return DefaultsSet(value: set)
    }
}
