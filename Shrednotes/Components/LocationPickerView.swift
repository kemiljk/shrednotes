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
            let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let address = MKAddress(fullAddress: location.name, shortAddress: location.name)
            let item = MKMapItem(location: clLocation, address: address)
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
                    .cornerRadius(32)
                    .onTapGesture { location in
                        guard !locationSearchIsFocused else {
                            locationSearchIsFocused = false
                            return
                        }
                        if let coordinate = proxy.convert(location, from: .local) {
                            Task {
                                await reverseGeocode(coordinate: coordinate)
                            }
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                            .onEnded { value in
                                switch value {
                                case .second(true, let drag):
                                    if let location = drag?.location,
                                       let coordinate = proxy.convert(location, from: .local) {
                                        locationSearchIsFocused = false
                                        Task {
                                            await reverseGeocode(coordinate: coordinate)
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                    )
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
                    .glassEffect(
                        .regular,
                        in: ConcentricRectangle(
                            corners: .concentric,
                            isUniform: true
                        )
                    )
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
                                        .clipShape(
                                            ConcentricRectangle(
                                                corners: .concentric,
                                                isUniform: true
                                            )
                                        )
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
            .containerShape(.rect(cornerRadius: 32))
            
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
                    Label("Use Current Location", systemImage: "location.fill")
                        .foregroundStyle(.white)
                }
                .buttonSizing(.flexible)
                .controlSize(.large)
                .buttonStyle(.glassProminent)
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
        
        if let name = item.name {
            components.append(name)
        }
        
        if let address = item.address, !address.fullAddress.isEmpty {
            components.append(address.fullAddress)
        }
        
        return components.joined(separator: ", ")
    }

    private func selectLocation(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        
        let newLocation = IdentifiableLocation(
            coordinate: coordinate,
            name: item.name ?? "Unknown location"
        )
        selectedLocation = newLocation
        
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
        
        searchText = ""
        searchResults = []
    }

    @MainActor
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            selectedLocation = IdentifiableLocation(coordinate: coordinate, name: "Selected Location")
            return
        }
        
        do {
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else {
                selectedLocation = IdentifiableLocation(coordinate: coordinate, name: "Selected Location")
                return
            }
            
            let name = formatMapItemName(mapItem)
            selectedLocation = IdentifiableLocation(coordinate: coordinate, name: name)
            
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
        } catch {
            selectedLocation = IdentifiableLocation(coordinate: coordinate, name: "Selected Location")
        }
    }
    
    private func formatMapItemName(_ mapItem: MKMapItem) -> String {
        if let name = mapItem.name {
            return name
        } else if let address = mapItem.address {
            return address.fullAddress
        }
        return "Selected Location"
    }
}
