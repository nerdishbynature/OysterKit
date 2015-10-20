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

    let tokenColorMap = [
        "comment" : UIColor.commentColor(),
        "keyword" : UIColor.purpleColor(),
        "type" : UIColor.purpleColor(),
        "string" : UIColor.redColor(),
        "variable" : UIColor.variableColor(),
        "integer": UIColor.purpleColor(),
        "float": UIColor.purpleColor(),
    ]
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
//                layoutManager.removeTemporaryAttribute(__TokenKey, forCharacterRange: inRange)
            }

            tokens.forEach { token in
                let tokenRange = NSMakeRange(inRange.location + token.originalStringIndex!, token.characters.characters.count)

                if tokenRange.end < limit {
//                    layoutManagers.forEach { $0.addTemporaryAttribute(__TokenKey, value: token, forCharacterRange: tokenRange) }
                }
            }
        }

        NSOperationQueue.mainQueue().addOperations([applyColoring], waitUntilFinished: false)
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

    func scheduleHighlighting(){
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

        guard let token = attrs[__TokenKey] as? Token, color = tokenColorMap[token.name] else {
            return attrs
        }

        var returnAttributes = attrs
        returnAttributes[NSForegroundColorAttributeName] = color
        return returnAttributes
    }
}

extension UIColor {
    class func variableColor() -> UIColor{
        return UIColor(red: 0, green: 0.4, blue: 0.4, alpha: 1.0)
    }

    class func commentColor() -> UIColor{
        return UIColor(red: 0, green: 0.6, blue: 0, alpha: 1.0)
    }

    class func stringColor() -> UIColor{
        return UIColor(red: 0.5, green: 0.4, blue: 0.2, alpha: 1.0)
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
