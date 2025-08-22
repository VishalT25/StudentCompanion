import SwiftUI

struct WeatherSettingsView: View {
    @EnvironmentObject var weatherService: WeatherService
    
    var body: some View {
        Form {
            Section(header: Text("Location")) {
                Picker("Select City", selection: $weatherService.selectedCity) {
                    ForEach(weatherService.availableCities) { city in
                        Text(city.displayName)
                            .tag(city)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button("Refresh Weather Data") {
                    weatherService.fetchWeatherData()
                }
            }
            
            Section(header: Text("Current Status")) {
                if weatherService.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading weather data...")
                            .foregroundColor(.secondary)
                    }
                } else if let weather = weatherService.currentWeather {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Currently: \(weather.temperature)°C")
                            .font(.headline)
                        Text("\(weather.condition.description)")
                            .foregroundColor(.secondary)
                        if let lastUpdate = weatherService.lastUpdateTime {
                            Text("Last updated: \(lastUpdate, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let error = weatherService.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Weather Settings")
    }
}