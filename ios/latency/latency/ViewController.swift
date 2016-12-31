import UIKit

class ViewController: UIViewController, Watcher {

    @IBOutlet weak var dist: UILabel!
    var loaded = false
    var connector: Connector?
    
    @IBAction func restart() {
        if let prior = connector {
            prior.stop()
        }
        dist.text = "started"
        connector = Connector()
        connector!.watchers.append(self)
        connector!.start()
        self.onUpdate(sender: connector!)
    }
    
    func onUpdate(sender: Connector) {
        guard loaded else { return }
        var val = ""
        if sender.observations.count == 0 {
            val = "connecting..."
        } else {
            val += "    Round Trip Times  \n\n"
            val += "   min:" + toHuman(sender.quantile(0)) + "\n"
            val += "median:" + toHuman(sender.quantile(0.5)) + "\n"
            val += "  75th:" + toHuman(sender.quantile(0.75)) + "\n"
            val += "  95th:" + toHuman(sender.quantile(0.95)) + "\n"
            val += "  99th:" + toHuman(sender.quantile(0.99)) + "\n"
            val += "   max:" + toHuman(sender.quantile(1.0)) + "\n\n"
            var c = String(sender.observations.count)
            while c.characters.count < 7 {
                c = " " + c
            }
            val += c + " observations\n"
            if !sender.connected {
                val += "               done!"
            }
            val += "\n\n\n"
        }
        dist.text = val
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loaded = true
        restart()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

