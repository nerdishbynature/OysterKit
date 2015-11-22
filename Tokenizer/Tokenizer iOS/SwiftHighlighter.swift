import UIKit
import OysterKit

let __TokenKey = "OKToken"

class SwiftHighlighter: NSObject, NSTextStorageDelegate, NSLayoutManagerDelegate {
    var backgroundQueue = NSOperationQueue()
    var tokenizationOperation = NSOperation()
    var editedRange: NSRange?

    var textStorage:NSTextStorage!{
        willSet{
            if let _ = textStorage, oldValue = textStorage {
                oldValue.delegate = nil
            }
        }
        didSet{
            textStorage.delegate = self
        }
    }

    var tokenizer: Tokenizer = Tokenizer() {
        didSet{
            editedRange = NSMakeRange(0, textStorage.string.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
            scheduleHighlighting()
        }
    }

    func tokenize(string:String, usesRange:NSRange){
        let layoutManagers = self.textStorage.layoutManagers
        let limit = (self.textStorage.string as String).characters.count
        let tokens = tokenizer.tokenize(string)


        let applyColoring = NSBlockOperation(){
            var inRange = usesRange

            if usesRange.end > limit {
                inRange = NSMakeRange(usesRange.location, limit - usesRange.location)
            }

            layoutManagers.forEach { layoutManager in
                layoutManager.delegate = self
            }

            tokens.forEach { token in
                let tokenRange = NSMakeRange(inRange.location + token.originalStringIndex!, token.characters.characters.count)

                if tokenRange.end < limit {
                    self.textStorage.addAttribute(NSForegroundColorAttributeName, value: self.colorForToken(token), range: tokenRange)
                }
            }
        }

        NSOperationQueue.mainQueue().addOperations([applyColoring], waitUntilFinished: false)
    }

    func colorForToken(token: Token) -> UIColor {
        switch token.name {
        case "comment":
            return UIColor.highlighting_commentColor()
        case "keyword":
            return UIColor.highlighting_keywordColor()
        case "type":
            return UIColor.highlighting_typeColor()
        case "string":
            return UIColor.highlighting_stringColor()
        case "variable":
            return UIColor.highlighting_variableColor()
        case "integer", "float":
            return UIColor.highlighting_numberColor()
        case "import":
            return UIColor.highlighting_importColor()
        default:
            return UIColor.whiteColor()
        }
    }

    func tokenize(){
        tokenize(textStorage.string,usesRange: NSMakeRange(0, textStorage.length))
    }

    func prepareToHighlight(){
        if tokenizationOperation.executing {
            scheduleHighlighting()
            return
        }

        var finalRange: NSRange
        if let editedRange = editedRange {
            finalRange = editedRange
        } else {
            finalRange = textStorage.editedRange
        }
        editedRange = nil


        var actualRangeStart = finalRange.location
        var actualRangeEnd = finalRange.end
        var parseLocation = 0

        for character in textStorage.string.characters {
            if character == "\n" {
                if parseLocation < finalRange.location {
                    actualRangeStart = parseLocation
                } else if parseLocation > finalRange.end{
                    actualRangeEnd = parseLocation
                    break
                }
            }

            parseLocation++
        }

        let adaptiveRange = NSMakeRange(actualRangeStart, actualRangeEnd - actualRangeStart)
        if adaptiveRange.end > textStorage.string.characters.count {
            return
        }
        let adaptiveString = (textStorage.string as NSString).substringWithRange(adaptiveRange)

        tokenizationOperation = NSBlockOperation() {
            self.tokenize(adaptiveString, usesRange:adaptiveRange)
        }

        backgroundQueue.addOperation(tokenizationOperation)
    }

    func scheduleHighlighting() {
        if tokenizationOperation.executing {
            return
        }

        prepareToHighlight()
    }

    func textStorageDidProcessEditing(notification: NSNotification) {
        if let editedRange = editedRange {
            self.editedRange = editedRange.unionWith(textStorage.editedRange)
        } else {
            editedRange = textStorage.editedRange
        }
        scheduleHighlighting()
    }

    func layoutManager(layoutManager: NSLayoutManager, shouldUseTemporaryAttributes attrs: [String : AnyObject], forDrawingToScreen toScreen: Bool, atCharacterIndex charIndex: Int, effectiveRange effectiveCharRange: NSRangePointer) -> [String : AnyObject]? {
        if !toScreen || attrs.count == 0 {
            return attrs
        }

        guard let token = attrs[__TokenKey] as? Token else {
            return attrs
        }

        var returnAttributes = attrs
        returnAttributes[NSForegroundColorAttributeName] = colorForToken(token)
        return returnAttributes
    }
}

extension UIColor {
    convenience private init(hex: UInt) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

    static func highlighting_commentColor() -> UIColor {
        return UIColor(hex: 0x41B645)
    }

    static func highlighting_keywordColor() -> UIColor {
        return UIColor(hex: 0xB21889)
    }

    static func highlighting_typeColor() -> UIColor {
        return UIColor(hex: 0x00A0BE)
    }

    static func highlighting_stringColor() -> UIColor {
        return UIColor(hex: 0xDB2C38)
    }

    static func highlighting_variableColor() -> UIColor {
        return UIColor(hex: 0x55747C)
    }

    static func highlighting_numberColor() -> UIColor {
        return UIColor(hex: 0x786DC4)
    }

    static func highlighting_importColor() -> UIColor {
        return UIColor(hex: 0xC67C48)
    }
}

extension NSRange{
    var end : Int {
        if location == Int.max {
            return location
        }
        return length + location
    }

    func unionWith(range:NSRange)->NSRange{
        let newLocation = range.location < self.location ? range.location : self.location
        let newEnd = range.end > self.end ? range.end : self.end
        
        return NSMakeRange(newLocation, newEnd-newLocation)
    }
}
