import UIKit
import OysterKit

class ViewController: UIViewController {
    lazy var highlighter: SwiftHighlighter = {
        let highlighter = SwiftHighlighter()
        highlighter.textStorage = self.textView.textStorage
        highlighter.tokenizer = OKStandard.parseTokenizer(self.tokenizerDefinition)!
        return highlighter
    }()

    lazy var textView: UITextView = {
        let textView = UITextView()
        let swiftOysterTestFile = NSBundle.mainBundle().URLForResource("oystertest", withExtension: "txt")!
        textView.text = try! String(contentsOfURL: swiftOysterTestFile, encoding: NSUTF8StringEncoding)
        self.view.addSubview(textView)
        return textView
    }()

    lazy var tokenizerDefinition: String = {
        let swiftOyster = NSBundle.mainBundle().URLForResource("Swift", withExtension: "oyster")!
        return try! String(contentsOfURL: swiftOyster, encoding: NSUTF8StringEncoding)
    }()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        textView.frame = view.frame.insetBy(dx: 0, dy: topLayoutGuide.length)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        highlighter.scheduleHighlighting()
    }
}
