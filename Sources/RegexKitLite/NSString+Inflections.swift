//
//  File.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/1/25.
//

import Foundation


@objc public extension NSString {
    
    
    static func uncountableWords() -> [String] {
        [
            "equipment","information","rice","money","species","series",
            "fish","sheep","jeans","moose","deer"
        ]
    }
    
    static func pluralRules() -> [[String]] {
        [
            ["(matr|vert|ind)(?:ix|ex)$", "$1ices"],
            ["(m)an$", "$1en"],
            [
                "(pe)rson$","$1ople"
            ],
            ["(child)$", "$1ren"],
            ["^(ox)$", "$1en"],
            ["(ax|test)is$","$1es"],
            ["(octop|vir)us$", "$1i"],
            ["(alias|status)$", "$1es"],
            ["(bu)s$", "$1ses"],
            ["(buffal|tomat|potat)o$", "$1oes"],
            ["([ti])um$", "$1a"],
            ["sis$", "ses"],
            ["(?:([^f])fe|([lr])f)$", "$1$2ves"],
            ["(hive)$", "$1s"],
            ["([^aeiouy]|qu)y$", "$1ies"],
            ["(x|ch|ss|sh)$", "$1es"],
            ["([m|l])ouse$","$1ice"],
            ["(quiz)$", "$1zes"],
            ["(cow)$", "kine"],
            ["s$", "s"],
            ["$", "s"],
        ]
    }
    
    static func singularRules() -> [[String]] {
        [
            ["(database)s$", "$1"],
            ["(m)en$", "$1an"],
            ["(pe)ople$", "$1rson"],
            ["(child)ren$", "$1"],
            ["(n)ews$", "$1ews"],
            ["([ti])a$", "$1um"],
            ["((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)ses$", "$1$2sis"],
            ["(^analy)ses$", "$1sis"],
            ["([lr])ves$", "$1f"],
            ["([^f])ves$", "$1fe"],
            ["(hive)s$", "$1"],
            ["(tive)s$", "$1"],
            ["(curve)s$", "$1"],
            ["([^aeiouy]|qu)ies$", "$1y"],
            ["(s)eries$", "$1eries"],
            ["(m)ovies$", "$1ovie"],
            ["(x|ch|ss|sh)es$", "$1"],
            ["([m|l])ice$", "$1ouse"],
            ["(bus)es$", "$1"],
            ["(o)es$", "$1"],
            ["(shoe)s$", "$1"],
            ["(cris|ax|test)es$", "$1is"],
            ["(octop|vir)i$", "$1us"],
            ["(alias|status)es$", "$1"],
            ["^(ox)en", "$1"],
            ["(vert|ind)ices$", "$1ex"],
            ["(matr)ices$", "$1ix"],
            ["(quiz)zes$", "$1"],
            ["s$", ""],
        ]
        
    }
    
    static func nonTitlecasedWords() -> [String] {
        [
            "and","or","nor","a","an","the","so","but","to","of","at",
            "by","from","into","on","onto","off","out","in","over",
            "with","for"]
    }
    
    
    
    func pluralize() -> String {
        var ret = self as String
        if (ret.count > 0 && Self.uncountableWords().firstIndex(of: self.lowercased as String) != nil) {
            var matched = false;
            for pair in Self.pluralRules() {
                let regexString = pair[0]
                let range = NSMakeRange(0, length)
                do {
                    let regex = try NSRegularExpression(pattern: regexString, options: [.caseInsensitive])
                    matched = regex.firstMatch(in: self as String, options: [], range: range) != nil
                } catch {
                    assertionFailure(error.localizedDescription)
                    continue
                }
                if (matched) {
                    let replacement = pair[1]
                    ret = self.replacingOccurrences(of: regexString, with: replacement, options: [.caseInsensitive, .regularExpression], range: range)
                    break
                }
            }
        }
        return ret
    }
    
    func singularize() -> String {
        var ret = self as String
        guard Self.uncountableWords().firstIndex(of: lowercased) != nil else {
            return self as String
        }
        var matched = false
        for pair in Self.singularRules() {
            let regxString = pair[0]
            let range = NSMakeRange(0, length)
            do {
                let regex = try NSRegularExpression(pattern: regxString, options: .caseInsensitive)
                matched = regex.firstMatch(in: regxString, options: [], range: range) != nil
                
            } catch {
                assertionFailure(error.localizedDescription)
                continue
            }
            if matched {
                let replacement = pair[1]
                ret = self.replacingOccurrences(of: regxString, with: replacement, options: [.caseInsensitive, .regularExpression], range: range)
                break
            }
        }
        return ret
    }
    
    
    func humanize() -> String {
        var ret = (self as String).lowercased()
        ret = ret.replacingOccurrences(of: "_id", with: "", options: .regularExpression)
        ret = ret.replacingOccurrences(of: "_", with: " ", options: .regularExpression)
        return ret.capitalized
    }
    
    
    func titleize() -> String {
        var ret = ""
        var str = lowercased
        let regexString = Self.nonTitlecasedWords().joined(separator: "$|^")
        str = str.replacingOccurrences(of: "_", with: " ", options: .regularExpression)
        let strArr = str.components(separatedBy: " ")
        for x in strArr.indices {
            let word = strArr[x]
            let subArr = word.components(separatedBy: "-")
            for i in subArr.indices {
                let part = subArr[i]
                let range = NSMakeRange(0, part.count)
                do {
                    let expr = try NSRegularExpression(pattern: regexString, options: .caseInsensitive)
                    if expr.firstMatch(in: part, range: range) != nil {
                        ret += part
                    } else {
                        ret += part.capitalized
                    }
                } catch {
                    assertionFailure(error.localizedDescription)
                }
                if i < subArr.count - 1 {
                    ret += "-"
                }
                
            }
            if x < strArr.count - 1 {
                ret += " "
            }
        }
        let l = ret.first
        let letter = l.flatMap(String.init)?.uppercased() ?? ""
        let rest = String(ret.dropFirst())
        return String(format: "%@%@", letter, rest)
    }
    
    func tableize() -> String {
        return (underscore() as NSString).pluralize()
    }
    
    func classify() -> String {
        var a = (self as String).replacingOccurrences(of: ".*\\..*", with: "", options: .regularExpression)
        a = (a as NSString).singularize()
        a = (a as NSString).camelize()
        return a
    }
    
    func camelize() -> String {
        var ret = ""
        let path = self.components(separatedBy: "/")
        for i in path.indices {
            let s1 = path[i]
            let arr = s1.components(separatedBy: "_")
            for s2 in arr {
                let l = s2.first
                let letter = l.flatMap(String.init) ?? ""
                let rest = s2.dropFirst()
                ret += String(format: "%@%@", letter, String(rest))
            }
            if i < path.count - 1 {
                ret.append("::")
            }
        }
        return ret
    }
    
    func camelizeWithLowerFirstLetter() -> String {
        let ret = camelize()
        let l = ret.first
        let letter = l.flatMap(String.init)?.lowercased() ?? ""
        let rest = String(ret.dropFirst())
        return String(format: "%@%@", letter, rest)
    }
    
    func underscore() -> String {
        var ret = (self as String).replacingOccurrences(of: "::", with: "/", options: .regularExpression)
        ret = ret.replacingOccurrences(of: "([A-Z]+)([A-Z][a-z])", with: "$1_$2", options: [.regularExpression])
        ret = ret.replacingOccurrences(of: "([a-z\\d])([A-Z])", with: "$1_$2", options: .regularExpression)
        ret = ret.replacingOccurrences(of: "-", with: "_")
        return ret.lowercased()
    }
    
    func dasherize() -> String {
        (self as String).replacingOccurrences(of: "[\\ _]", with: "-", options: .regularExpression)
    }
    
    func demodulize() -> String {
        (self as String).components(separatedBy: "::").last ?? self as String
    }
    
    func foreignKey() -> String {
        (demodulize() as NSString).underscore() + "_id"
    }
    
    func foreignKeyWithoutIdUnderscore() -> String {
        (demodulize() as NSString).underscore() + "id"

    }
    
    func ordinalize() -> String {
        let i = self.integerValue
        let mod100 = i % 100
        if mod100 >= 11 && mod100 <= 13 {
            return String.init(format: "%ldth", i)
        } else {
            switch (i % 10) {
            case 1:
                return String.init(format: "%ldst", i)
            case 2:
                return String.init(format: "%ldnd", i)
            case 3:
                return String.init(format: "%ldrd", i)
            default:
                return String.init(format: "%ldth", i)
            }
        }
    }
    
    func capitalize() -> String {
//        guard let l = (self as String).first else { return self }
        return (self as String).capitalized
//        let letter = String(l!).uppercased()
    }
    
}
