//  Copyright © 2018 slant. All rights reserved.

import Foundation
import MapKit
import MONode
import PromiseKit


protocol ViewManagerDelegate: class {
    func displayView(for: Place, from: NSView?)
}


class MapViewController: NSViewController, MKMapViewDelegate, ViewManagerDelegate, GestureResponder {

    private struct Constants {
        static let tileURL = "http://tile.openstreetmap.org/{z}/{x}/{y}.png"
    }

    @IBOutlet weak var mapView: MKMapView!
    private var mapNetwork: MapNetwork?
    private var gestureManager: GestureManager!
    private var initialPanningCenter: CLLocationCoordinate2D?


    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        gestureManager = GestureManager(responder: self)
        setupMap()
        setupGestures()
    }

    override func viewWillAppear() {
        view.window?.toggleFullScreen(nil)
        mapNetwork?.resetMap()
    }


    // MARK: Setup

    func setupMap() {
        mapView.register(PlaceView.self, forAnnotationViewWithReuseIdentifier: PlaceView.identifier)
        mapView.register(ClusterView.self, forAnnotationViewWithReuseIdentifier: ClusterView.identifier)
        createMapPlaces()
        mapView.delegate = self
//        let overlay = MKTileOverlay(urlTemplate: Constants.tileURL)
//        overlay.canReplaceMapContent = true
//        mapView.add(overlay)
    }

    func setupGestures() {
        let panGesture = PanGestureRecognizer()
        gestureManager.add(panGesture, for: mapView)
        panGesture.gestureUpdated = mapViewDidPan(_:)

        let pinchGesture = PinchGestureRecognizer()
        gestureManager.add(pinchGesture, for: mapView)
        pinchGesture.gestureUpdated = mapViewDidZoom(_:)
    }


    // MARK: Gesture handling

    private func mapViewDidPan(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer else {
            return
        }

        switch gesture.state {
        case .began:
            mapNetwork?.beginSendingPosition()
        case .recognized:
            var mapRect = mapView.visibleMapRect
            let translationX = Double(pan.delta.dx) * mapRect.size.width / Double(mapView.frame.width)
            let translationY = Double(pan.delta.dy) * mapRect.size.height / Double(mapView.frame.height)
            mapRect.origin -= MKMapPoint(x: translationX, y: translationY)
            mapView.setVisibleMapRect(mapRect, animated: false)
        case .possible, .failed:
            mapNetwork?.stopSendingPosition()
        default:
            return
        }
    }

    private func mapViewDidZoom(_ gesture: GestureRecognizer) {
        guard let pinch = gesture as? PinchGestureRecognizer else {
            return
        }

        var mapRect = mapView.visibleMapRect
        let scaledWidth = Double(pinch.scale) * mapRect.size.width / Double(mapView.frame.width)
        let scaledHeight = Double(pinch.scale) * mapRect.size.height / Double(mapView.frame.height)
        let translationX = (mapRect.size.width - scaledWidth) * Double(pinch.location.x / mapView.frame.width)
        let translationY = (mapRect.size.height - scaledHeight) * Double(pinch.location.y / mapView.frame.height)
        mapRect.origin += MKMapPoint(x: translationX, y: translationY)
        mapRect.size = MKMapSize(width: scaledWidth, height: scaledHeight)
        mapView.setVisibleMapRect(mapRect, animated: false)
    }


    // MARK: MKMapViewDelegate

    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        mapNetwork = MapNetwork(map: mapView)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let place = annotation as? Place {
            if let placeView = mapView.dequeueReusableAnnotationView(withIdentifier: PlaceView.identifier) as? PlaceView {
                placeView.didTapCallout = didSelectAnnotationCallout(for:)
                return placeView
            } else {
                let placeView = PlaceView(annotation: place, reuseIdentifier: PlaceView.identifier)
                placeView.didTapCallout = didSelectAnnotationCallout(for:)
                return placeView
            }
        } else if let cluster = annotation as? MKClusterAnnotation {
            if let clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: ClusterView.identifier) as? ClusterView {
                clusterView.didTapCallout = didSelectAnnotationCallout(for:)
                return clusterView
            } else {
                let clusterView = ClusterView(annotation: cluster, reuseIdentifier: ClusterView.identifier)
                clusterView.didTapCallout = didSelectAnnotationCallout(for:)
                return clusterView
            }
        }

        return nil
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let tileOverlay = overlay as? MKTileOverlay else {
            return MKOverlayRenderer(overlay: overlay)
        }

        return MKTileOverlayRenderer(tileOverlay: tileOverlay)
    }


    // MARK: ViewManagerDelegate

    /// Displays a child view controller on the screen with an origin offset from the providing view or nil if from an annotation.
    func displayView(for place: Place, from focus: NSView?) {
        let storyboard = NSStoryboard(name: PlaceViewController.storyboard, bundle: nil)
        let placeVC = storyboard.instantiateInitialController() as! PlaceViewController
        addChildViewController(placeVC)
        view.addSubview(placeVC.view)
        var origin: CGPoint

        if let focusedView = focus {
            // Displayed from subview
            origin = focusedView.frame.origin
            origin += CGVector(dx: focusedView.bounds.width + 20.0, dy: 0)
        } else {
            // Displayed from a map annotation
            origin = mapView.convert(place.coordinate, toPointTo: view)
            origin -= CGVector(dx: placeVC.view.bounds.width / 2, dy: placeVC.view.bounds.height + 10.0)
        }

        placeVC.view.frame.origin = origin
        placeVC.place = place
        placeVC.viewDelegate = self
    }


    // MARK: Helpers

    private func createMapPlaces() {
        do {
            if let file = Bundle.main.url(forResource: "MapPoints", withExtension: "json") {
                let data = try Data(contentsOf: file)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let jsonBlob = json as? [String: Any], let json = jsonBlob["locations"] as? [[String: Any]] {
                    addPlacesToMap(placesJSON: json)
                } else {
                    print("JSON is invalid")
                }
            } else {
                print("No file")
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    private func addPlacesToMap(placesJSON: [[String: Any]]) {
        let places = placesJSON.flatMap { Place(fromJSON: $0) }
        mapView.addAnnotations(places)
    }

    /// Zoom into the annotations contained in the cluster
    private func didSelectAnnotationCallout(for cluster: MKClusterAnnotation) {
        let selectedAnnotations = cluster.memberAnnotations
        mapView.showAnnotations(selectedAnnotations, animated: true)
    }

    /// Display a place view controller on top of the selected callout annotation for the associated place.
    private func didSelectAnnotationCallout(for place: Place) {
        mapView.deselectAnnotation(place, animated: false)
        displayView(for: place, from: nil)
    }
}
