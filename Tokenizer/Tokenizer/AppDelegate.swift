// Copyright (c) 2014, RED When Excited
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Cocoa
import OysterKit

class AppDelegate: NSObject, NSApplicationDelegate, NSTextStorageDelegate {
    let keyTokenizerString = "tokString"
    let keyTokenizerText   = "tokText"
    let keyColors = "tokColors"
    let keyColor = "tokColor"
    
    var buildTokenizerTimer : NSTimer?
    
    @IBOutlet var window: NSWindow!
    @IBOutlet var tokenizerDefinitionScrollView: NSScrollView!
    @IBOutlet var testInputScroller : NSScrollView!
    @IBOutlet var buildProgressIndicator: NSProgressIndicator!

    let highlighter = TokenHighlighter()
    let okScriptHighlighter = TokenHighlighter()

    var testInputTextView : NSTextView {
        return testInputScroller.contentView.documentView as! NSTextView
    }
    
    var tokenizerDefinitionTextView : NSTextView {
        return tokenizerDefinitionScrollView.contentView.documentView as! NSTextView
    }

    func prepareTextView(view:NSTextView) {
        view.automaticQuoteSubstitutionEnabled = false
        view.automaticSpellingCorrectionEnabled = false
        view.automaticDashSubstitutionEnabled = false
        
        //Change the font, set myself as a delegate, and set a default string
        view.textStorage?.font = NSFont(name: "Menlo", size: 14.0)
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let swiftOyster = NSBundle.mainBundle().URLForResource("Swift", withExtension: "oyster")!
        let swiftOysterTestFile = NSBundle.mainBundle().URLForResource("oystertest", withExtension: "txt")!
        tokenizerDefinitionTextView.string = try! String(contentsOfURL: swiftOyster, encoding: NSUTF8StringEncoding)
        testInputTextView.string = try! String(contentsOfURL: swiftOysterTestFile, encoding: NSUTF8StringEncoding)

        //Tie the highlighters to their text views
        highlighter.textStorage = testInputTextView.textStorage
        okScriptHighlighter.textStorage = tokenizerDefinitionTextView.textStorage
        
        okScriptHighlighter.textDidChange = {
            self.buildTokenizer()
        }

        okScriptHighlighter.tokenColorMap = [
            "loop" : NSColor.purpleColor(),
            "not" : NSColor.purpleColor(),
            "quote" : NSColor.purpleColor(),
            "Char" : NSColor.stringColor(),
            "keyword" : NSColor.purpleColor(),
            "type" : NSColor.purpleColor(),
            "string" : NSColor.redColor(),
            "single-quote" : NSColor.stringColor(),
            "delimiter" : NSColor.stringColor(),
            "token" : NSColor.purpleColor(),
            "variable" : NSColor.variableColor(),
            "state-name" : NSColor.variableColor(),
            "start-branch" : NSColor.purpleColor(),
            "start-repeat" : NSColor.purpleColor(),
            "start-delimited" : NSColor.purpleColor(),
            "end-branch" : NSColor.purpleColor(),
            "end-repeat" : NSColor.purpleColor(),
            "end-delimited" : NSColor.purpleColor(),
            "tokenizer" : NSColor.purpleColor(),
            "exit-state" : NSColor.purpleColor(),
            "oysterKit" : NSColor.purpleColor()
        ]

        highlighter.tokenColorMap = [
            "comment" : NSColor.commentColor(),
            "keyword" : NSColor.purpleColor(),
            "type" : NSColor.purpleColor(),
            "string" : NSColor.redColor(),
            "variable" : NSColor.variableColor(),
            "integer": NSColor.purpleColor(),
            "float": NSColor.purpleColor(),
        ]

        okScriptHighlighter.tokenizer = OKScriptTokenizer()

        prepareTextView(testInputTextView)
        prepareTextView(tokenizerDefinitionTextView)

    }

    func doBuild(){
        highlighter.backgroundQueue.addOperationWithBlock(){
            if let newTokenizer:Tokenizer = OKStandard.parseTokenizer(self.tokenizerDefinitionTextView.string!) {
                self.highlighter.tokenizer = newTokenizer
            }
        }
        
        buildProgressIndicator.stopAnimation(self)
    }
    
    func buildTokenizer(){
        if let timer = buildTokenizerTimer {
            timer.invalidate()
        }
        
        buildProgressIndicator.startAnimation(self)
        
        buildTokenizerTimer = NSTimer(timeInterval: 1.0, target: self, selector:Selector("doBuild"), userInfo: nil, repeats: false)
        NSRunLoop.mainRunLoop().addTimer(buildTokenizerTimer!, forMode: NSRunLoopCommonModes)
    }
}

extension NSColor{
    class func variableColor()->NSColor{
        return NSColor(calibratedRed: 0, green: 0.4, blue: 0.4, alpha: 1.0)
    }
    
    class func commentColor()->NSColor{
        return NSColor(calibratedRed: 0, green: 0.6, blue: 0, alpha: 1.0)
    }
    
    class func stringColor()->NSColor{
        return NSColor(calibratedRed: 0.5, green: 0.4, blue: 0.2, alpha: 1.0)
    }
}

