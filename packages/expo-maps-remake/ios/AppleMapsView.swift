// Copyright 2025-present 650 Industries. All rights reserved.

import SwiftUI
import ExpoModulesCore
import MapKit

@available(iOS 17.0, *)
@Observable
class MapPosition {
  var region: MapCameraPosition

  init(position: CameraPosition) {
    self.region = convertToMapCamera(position: position)
  }
}

class AppleMapsViewProps: ExpoSwiftUI.ViewProps {
  @Field var markers: [MapMarker] = []
  @Field var annotations: [MapAnnotation] = []
  @Field var cameraPosition: CameraPosition
  @Field var uiSettings: MapUISettings = MapUISettings()
  @Field var properties: MapProperties = MapProperties()
  let onMapClick = EventDispatcher()
  let onCameraMove = EventDispatcher()
}

struct AppleMapsViewWrapper: ExpoSwiftUI.View {
  @EnvironmentObject var props: AppleMapsViewProps

  var body: some View {
    if #available(iOS 18.0, *) {
      AppleMapsView()
        .environmentObject(props)
    } else {
      EmptyView()
    }
  }
}

@available(iOS 18.0, *)
struct AppleMapsView: View {
  @EnvironmentObject var props: AppleMapsViewProps
  @State private var mapCameraPosition: MapCameraPosition = .automatic
  @State var selection: MapSelection<MKMapItem>?

  @Namespace var mapScope

  var body: some View {
    let properties = props.properties
    let uiSettings = props.uiSettings

    // swiftlint:disable:next closure_body_length
    MapReader { reader in
      Map(position: $mapCameraPosition, selection: $selection) {
        ForEach(props.markers) { marker in
          Marker(
            coordinate: marker.clLocationCoordinate2D,
            label: { Text(marker.title) }
          )
          .tag(MapSelection(marker.mapItem))
        }

        ForEach(props.annotations) { annotation in
          let coordinates = annotation.coordinates
          Annotation(
            annotation.title,
            coordinate: CLLocationCoordinate2D(
              latitude: coordinates.latitude,
              longitude: coordinates.longitude
            )
          ) {
            ZStack {
              RoundedRectangle(cornerRadius: 5)
                .fill(annotation.backgroundColor)
              Text(annotation.text)
                .foregroundStyle(annotation.textColor)
                .padding(5)
            }
          }
        }
      }
      .onTapGesture(coordinateSpace: .local) { position in
        if let coordinate = reader.convert(position, from: .local) {
          props.onMapClick([
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
          ])
        }
      }
      .mapControls {
        if uiSettings.compassEnabled {
          MapCompass()
        }
        if uiSettings.scaleBarEnabled {
          MapScaleView()
        }
        if uiSettings.togglePitchEnabled {
          MapPitchToggle()
        }
        if uiSettings.myLocationButtonEnabled {
          MapUserLocationButton()
        }
      }
      .onMapCameraChange(frequency: .onEnd) { change in
        let cameraPosition = change.region.center
        let zoomLevel = change.region.span.longitudeDelta

        props.onCameraMove([
          "coordinates": [
            "latitude": cameraPosition.latitude,
            "longitude": cameraPosition.longitude
          ],
          "zoom": zoomLevel,
          "tilt": change.camera.pitch
        ])
      }
      .mapFeatureSelectionAccessory(props.properties.selectionEnabled ? .automatic : nil)
      .mapStyle(properties.mapType.toMapStyle(
        showsTraffic: properties.isTrafficEnabled
      ))
      .onAppear {
        mapCameraPosition = convertToMapCamera(position: props.cameraPosition)
      }
    }
  }
}
