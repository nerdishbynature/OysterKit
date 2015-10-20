/*
Copyright (c) 2014, RED When Excited
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import OysterKit
import Cocoa

let __TokenKey = "OKToken"

@objc class TokenHighlighter : NSObject, NSTextStorageDelegate, NSLayoutManagerDelegate{
    var textDidChange: Void -> Void = {}
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

    var tokenColorMap: [String: NSColor] = [:]
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
                layoutManager.removeTemporaryAttribute(__TokenKey, forCharacterRange: inRange)
            }

            tokens.forEach { token in
                let tokenRange = NSMakeRange(inRange.location + token.originalStringIndex!, token.characters.characters.count)

                if tokenRange.end < limit {
                    layoutManagers.forEach { $0.addTemporaryAttribute(__TokenKey, value: token, forCharacterRange: tokenRange) }
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

        textDidChange()

        let finalRange = (editedRange != nil) ? editedRange! : self.textStorage.editedRange
        editedRange = nil


        var actualRangeStart = finalRange.location
        var actualRangeEnd = finalRange.end
        var parseLocation = 0

        for character in (self.textStorage.string as String).characters {
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

    override func textStorageDidProcessEditing(notification: NSNotification) {
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

extension NSRange{
    var end : Int {
        return length + location
    }

    func unionWith(range:NSRange)->NSRange{
        let newLocation = range.location < self.location ? range.location : self.location
        let newEnd = range.end > self.end ? range.end : self.end

        return NSMakeRange(newLocation, newEnd-newLocation)
    }
}