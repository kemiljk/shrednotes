import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var selectedLocation: IdentifiableLocation?
    @Query(sort: \SkateSession.date, order: .reverse) private var skateSessions: [SkateSession]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @FocusState.Binding var locationSearchIsFocused: Bool
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    private func locationMatchesSearch(_ location: IdentifiableLocation) -> Bool {
        if searchText.isEmpty {
            return true
        }
        let searchWords = searchText.lowercased().split(separator: " ")
        let locationName = location.name.lowercased()
        
        return searchWords.contains { word in
            locationName.contains(word)
        }
    }
    
    @MainActor
    private func getRecentLocations() {
        let allLocations = skateSessions.compactMap { session -> (location: IdentifiableLocation, date: Date)? in
            guard let location = session.location else { return nil }
            guard let date = session.date else { return nil }
            return (location, date)
        }

        let uniqueLocations = Dictionary(grouping: allLocations, by: { $0.location.id })
            .values
            .compactMap { group in
                group.max(by: { $0.date < $1.date })
            }
            .sorted(by: { $0.date > $1.date })
            .map { $0.location }
            .prefix(5)

        let filteredLocations = Array(uniqueLocations).filter { locationMatchesSearch($0) }

        searchResults = filteredLocations.map { location in
            let placemark = MKPlacemark(coordinate: location.coordinate)
            let item = MKMapItem(placemark: placemark)
            item.name = location.name
            return item
        }
    }

    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        if let selectedLocation = selectedLocation {
                            Annotation(selectedLocation.name, coordinate: selectedLocation.coordinate) {
                                Image(systemName: "mappin.circle")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Circle().fill(Color.indigo))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .frame(height: 300)
                    .cornerRadius(16)
                    .onTapGesture { location in
                        guard !locationSearchIsFocused else {
                            locationSearchIsFocused = false
                            return
                        }
                        if let coordinate = proxy.convert(location, from: .local) {
                            // Create a new location at the tapped coordinate
                            Task {
                                await reverseGeocode(coordinate: coordinate)
                            }
                        }
                    }
                }
                .onChange(of: selectedLocation) { _, newLocation in
                    if let loc = newLocation {
                        cameraPosition = .camera(MapCamera(
                            centerCoordinate: loc.coordinate,
                            distance: 1000,
                            heading: 0,
                            pitch: 0
                        ))
                    }
                }
                
                VStack(spacing: 8) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.title3)
                            .foregroundStyle(locationSearchIsFocused ? .indigo : .secondary)
                        TextField("Search for a skatepark", text: $searchText)
                            .focused($locationSearchIsFocused)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onChange(of: searchText) {
                        searchLocations()
                    }
                    .onChange(of: locationSearchIsFocused) {
                        if locationSearchIsFocused {
                            getRecentLocations()
                        } else {
                            searchText = ""
                        }
                    }
                    
                    // Search results
                    if locationSearchIsFocused {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(searchResults, id: \ .self) { item in
                                    Button(action: {
                                        selectLocation(item)
                                        searchText = ""
                                        locationSearchIsFocused = false
                                    }) {
                                        HStack {
                                            Image(systemName: "mappin.and.ellipse")
                                            Text(item.name ?? "Unknown location")
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(.thinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
            }
            
            // Add Go to My Location button
            if let userCoordinate = locationManager.currentLocation {
                Button(action: {
                    let userLoc = IdentifiableLocation(coordinate: userCoordinate, name: "Current Location")
                    selectedLocation = userLoc
                    withAnimation {
                        cameraPosition = .camera(
                            MapCamera(
                                centerCoordinate: userCoordinate,
                                distance: 1000,
                                heading: 0,
                                pitch: 0
                            )
                        )
                    }
                }) {
                    Label("Use Current Location", systemImage: "mappin")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                locationManager.requestLocation()
                if selectedLocation == nil,
                   let coordinate = locationManager.currentLocation {
                    selectedLocation = IdentifiableLocation(coordinate: coordinate, name: "Current Location")
                }
            }
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            if selectedLocation == nil,
               let coordinate = newLocation,
               locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                selectedLocation = IdentifiableLocation(coordinate: coordinate, name: "Current Location")
            }
        }
    }

    private func searchLocations() {
        // Clear recent locations when actively searching
        if !searchText.isEmpty {
            searchResults = []
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText
            request.region = region
            
            let search = MKLocalSearch(request: request)
            search.start { response, _ in
                guard let response = response else { return }
                
                // Format results to include city/region information
                searchResults = response.mapItems.map { item in
                    let formattedName = formatLocationName(item)
                    item.name = formattedName
                    return item
                }
            }
        } else {
            // Show recent locations when search is empty
            getRecentLocations()
        }
    }
    
    private func formatLocationName(_ item: MKMapItem) -> String {
        var components: [String] = []
        
        // Add the primary location name
        if let name = item.name {
            components.append(name)
        }
        
        // Add city and/or state/country for context
        if let locality = item.placemark.locality {
            components.append(locality)
        }
        
        if let adminArea = item.placemark.administrativeArea {
            components.append(adminArea)
        } else if let country = item.placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }

    private func selectLocation(_ item: MKMapItem) {
        let newLocation = IdentifiableLocation(
            coordinate: item.placemark.coordinate,
            name: item.name ?? "Unknown location"
        )
        selectedLocation = newLocation
        
        // Update the map's camera position
        withAnimation {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: item.placemark.coordinate,
                    distance: 1000,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        
        searchText = ""
        searchResults = []
    }

    @MainActor
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = formatPlacemarkName(placemark)
                selectedLocation = IdentifiableLocation(coordinate: coordinate, name: name)
                
                // Update camera position
                withAnimation {
                    cameraPosition = .camera(
                        MapCamera(
                            centerCoordinate: coordinate,
                            distance: 1000,
                            heading: 0,
                            pitch: 0
                        )
                    )
                }
            }
        } catch {
            // If geocoding fails, use a generic name
            selectedLocation = IdentifiableLocation(coordinate: coordinate, name: "Selected Location")
        }
    }
    
    private func formatPlacemarkName(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // Try to get a specific location name
        if let name = placemark.name {
            components.append(name)
        } else if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        }
        
        // Add locality for context
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        return components.isEmpty ? "Selected Location" : components.joined(separator: ", ")
    }
}
