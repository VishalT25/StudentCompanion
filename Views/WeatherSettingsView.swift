import SwiftUI

struct WeatherSettingsView: View {
    @EnvironmentObject var weatherService: WeatherService
    
    var body: some View {
        Form {
            Section(header: Text("Location").font(.forma(.footnote))) {
                Picker("Select City", selection: $weatherService.selectedCity) {
                    ForEach(weatherService.availableCities) { city in
                        Text(city.displayName)
                            .font(.forma(.body))
                            .tag(city)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button("Refresh Weather Data") {
                    weatherService.refreshWeatherData()
                }
                .font(.forma(.body, weight: .semibold))
            }
            
            Section(header: Text("Current Status").font(.forma(.footnote))) {
                if weatherService.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading weather data...")
                            .font(.forma(.body))
                            .foregroundColor(.secondary)
                    }
                } else if let weather = weatherService.currentWeather {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Currently: \(weather.temperature)°C")
                            .font(.forma(.headline))
                        Text("\(weather.condition.description)")
                            .font(.forma(.body))
                            .foregroundColor(.secondary)
                        if let lastUpdate = weatherService.lastUpdateTime {
                            Text("Last updated: \(lastUpdate, style: .time)")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let error = weatherService.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.forma(.caption))
                }
            }
        }
        .navigationTitle("Weather Settings")
        .onAppear {
            // Set the appearance for the navigation bar title
            UINavigationBar.appearance().largeTitleTextAttributes = [.font : UIFont(name: "FormaDJRDeck-Bold", size: 34) ?? .systemFont(ofSize: 34, weight: .bold)]
            UINavigationBar.appearance().titleTextAttributes = [.font : UIFont(name: "FormaDJRDeck-Bold", size: 17) ?? .systemFont(ofSize: 17, weight: .bold)]
        }
    }
}