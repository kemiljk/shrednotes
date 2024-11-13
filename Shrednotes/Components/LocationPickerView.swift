import SwiftUI
import SwiftData
import MapKit

struct LocationPickerView: View {
    @Binding var selectedLocation: IdentifiableLocation?
    @Query private var skateSessions: [SkateSession]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @FocusState.Binding var locationSearchIsFocused: Bool
    
    private var recentSessions: [SkateSession] {
        Array(skateSessions.prefix(2))
    }
    
    private func locationMatchesSearch(_ location: IdentifiableLocation) -> Bool {
        if searchText.isEmpty {
            return true
        }
        let searchWords = searchText.lowercased().split(separator: " ")
        let locationName = location.name.lowercased()
        return searchWords.allSatisfy { locationName.contains($0) }
    }
    
    @MainActor
    private func getRecentLocations() {
        let recentLocations = recentSessions.compactMap { $0.location }
            .filter { locationMatchesSearch($0) }
        let uniqueRecentLocations = Array(Set(recentLocations)).sorted { $0.name < $1.name }
        searchResults = uniqueRecentLocations.map { location in
            let placemark = MKPlacemark(coordinate: location.coordinate)
            let item = MKMapItem(placemark: placemark)
            item.name = location.name
            return item
        }
    }

    var body: some View {
        VStack {
            Group {
                HStack {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.title3)
                        .foregroundStyle(locationSearchIsFocused ? .indigo : .secondary)
                    TextField("Search for a location", text: $searchText)
                }
                .padding()
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(locationSearchIsFocused ? LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: locationSearchIsFocused ? 2 : 1)
            )
            .focused($locationSearchIsFocused)
            .onChange(of: searchText) {
                searchLocations()
            }
            
            if !searchResults.isEmpty {
                List(searchResults, id: \.self) { item in
                    Button(action: {
                        selectLocation(item)
                    }) {
                        Text(item.name ?? "Unknown location")
                            .fontWidth(.expanded)
                    }
                }
            } else {
                Spacer()
            }
            
            if let selectedLocation = selectedLocation {
                Map(initialPosition: .camera(MapCamera(
                    centerCoordinate: selectedLocation.coordinate,
                    distance: 1000, // Distance in meters
                    heading: 0,
                    pitch: 0
                ))) {
                    UserAnnotation()
                    Annotation(selectedLocation.name, coordinate: selectedLocation.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.indigo))
                            .clipShape(Circle())
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .cornerRadius(16)
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            self.selectedLocation = IdentifiableLocation(coordinate: region.center, name: selectedLocation.name)
                        }
                )
            }
        }
        .onAppear {
            getRecentLocations()
        }
    }

    private func searchLocations() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response = response else { return }
            searchResults = response.mapItems
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        let newLocation = IdentifiableLocation(coordinate: item.placemark.coordinate, name: item.name ?? "Unknown location")
        selectedLocation = newLocation
        region.center = item.placemark.coordinate
        searchText = ""
        searchResults = []
    }
}
