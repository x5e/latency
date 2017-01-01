import UIKit
import CoreLocation

class ViewController: UIViewController, Watcher, CLLocationManagerDelegate {

    @IBOutlet weak var dist: UILabel!
    var loaded = false
    var connector: Connector?
    var locationManager = CLLocationManager()
    var location: CLLocation?
    var waiting = false
    
    @IBAction func restart() {
        if let prior = connector {
            prior.stop()
        }
        dist.text = "started"
        connector = Connector()
        connector!.watchers.append(self)
        connector!.start(location)
        self.onUpdate(sender: connector!)
    }
    
    func onUpdate(sender: Connector) {
        guard loaded else { return }
        var val = ""
        if sender.observations.count == 0 {
            val = sender.state
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
                val += "                done"
            }
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

