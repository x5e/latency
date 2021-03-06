import UIKit
import CoreLocation
import NotificationCenter

class ViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var dist: UILabel!
    var loaded = false
    var connector: Connector?
    var locationManager = CLLocationManager()
    var location: CLLocation?
    var waiting = false
    var timer: Timer?
    var last = 0
    let center = NotificationCenter.default
    var observer: NSObjectProtocol?
    
    func onNotification(_ n: Notification) {
        // print("on notification")
        breathe()
    }
    
    @IBAction func restart() {
        if let prior = connector {
            prior.stop()
        }
        if observer == nil {
            observer = center.addObserver(
                forName: NSNotification.Name(rawValue: "thump"),
                object: nil, queue: OperationQueue.main,
                using: {self.onNotification($0)})
        }
        connector = Connector()
        onUpdate(sender: connector!)
        connector!.knock(from: location)
        last = 0
        if let t = timer {
            t.invalidate()
        }
        /*
        timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(ViewController.breathe), userInfo:nil, repeats: true)
        */
    }
    
    func breathe() {
        guard let c = connector else { return }
        if last < c.updates {
            onUpdate(sender: c)
            last = c.updates
        }
    }
    
    func onUpdate(sender: Connector) {
        guard loaded else { return }
        var val = ""
        if sender.observations.count == 0 {
            val = sender.state
        } else {
            val += "Round Trip Times to\n"
            val += (sender.remoteName ?? "") + "\n\n"
            
            var i = sender.observations.count
            var j = 1
            while j <= 4 {
                i -= 1
                j += 1
                if i >= 0 {
                    val += toHuman(sender.observations[i])
                }
                val += "\n"
            }
            val += "\n"
            val += " Min:" + toHuman(sender.quantile(0)) + "\n"
            val += " Med:" + toHuman(sender.quantile(0.5)) + "\n"
            val += "75th:" + toHuman(sender.quantile(0.75)) + "\n"
            val += "95th:" + toHuman(sender.quantile(0.95)) + "\n"
            val += "99th:" + toHuman(sender.quantile(0.99)) + "\n"
            val += " Max:" + toHuman(sender.quantile(1.0)) + "\n\n"
            var c = String(sender.observations.count)
            while c.characters.count < 7 {
                c = " " + c
            }
            val += c + " Observations\n"
            val += sender.state
            val += "\n\n\n"
        }
        dist.text = val
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loaded = true
        
        if (CLLocationManager.locationServicesEnabled())
        {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            waiting = true
            dist.text = "getting location..."
        } else {
            restart()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        location = locations.last! as CLLocation
        if waiting {
            waiting = false
            restart()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError: Error)
    {
        if waiting {
            waiting = false
            restart()
        }
    }
}

