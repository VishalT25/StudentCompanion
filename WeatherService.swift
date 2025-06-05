import SwiftUI
import Combine
import CoreLocation

// MARK: - Weather Condition Enum & Icons
enum WeatherCondition: String, CaseIterable, Codable {
    case clearDay = "Clear (Day)"
    case clearNight = "Clear (Night)"
    case partlyCloudyDay = "Partly Cloudy (Day)"
    case partlyCloudyNight = "Partly Cloudy (Night)"
    case cloudy = "Cloudy"
    case rain = "Rain"
    case showerRain = "Shower Rain"
    case thunderstorm = "Thunderstorm"
    case snow = "Snow"
    case mist = "Mist"

    var SFSymbolName: String {
        switch self {
        case .clearDay: return "sun.max.fill"
        case .clearNight: return "moon.stars.fill"
        case .partlyCloudyDay: return "cloud.sun.fill"
        case .partlyCloudyNight: return "cloud.moon.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .showerRain: return "cloud.drizzle.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow: return "snowflake"
        case .mist: return "cloud.fog.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .clearDay, .partlyCloudyDay: return .yellow
        case .clearNight, .partlyCloudyNight: return .blue.opacity(0.7)
        case .rain, .showerRain, .thunderstorm: return .blue
        case .cloudy, .mist: return .gray
        case .snow: return .cyan
        }
    }

    var description: String {
        return self.rawValue
    }
}

// MARK: - Weather Data Models
struct CurrentWeatherInfo: Identifiable, Codable {
    var id = UUID()
    let temperature: Int // Celsius for simplicity
    let condition: WeatherCondition
    var locationName: String
    let todayHigh: Int
    let todayLow: Int
}

struct HourlyForecastInfo: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let temperature: Int
    let condition: WeatherCondition
}

struct DailyForecastInfo: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let highTemp: Int
    let lowTemp: Int
    let condition: WeatherCondition
}

// MARK: - Mock Weather Service
class WeatherService: ObservableObject {
    @Published var currentWeather: CurrentWeatherInfo?
    @Published var hourlyForecasts: [HourlyForecastInfo] = []
    @Published var dailyForecasts: [DailyForecastInfo] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date?

    @ObservedObject private var locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.currentWeather = CurrentWeatherInfo(
            temperature: 0,
            condition: .mist,
            locationName: locationManager.locationName,
            todayHigh: 0,
            todayLow: 0
        )
        
        DispatchQueue.main.async {
            self.locationManager.$locationName
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newLocationName in
                    guard let self = self else { return }
                    self.fetchWeatherData(forCity: newLocationName)
                }
                .store(in: &self.cancellables)
            
            // TEMP: Comment out the permission request to see if the app launches
            // self.locationManager.requestLocationPermission()
            
            // If the above is commented out, locationName might remain "Loading..." or "Location Disabled"
            // unless permission was previously granted. We might need an initial fetch if the sink doesn't fire.
            // For now, let's see if the app loads. If it does, we know the requestLocationPermission() call
            // at this stage is the issue (likely due to Info.plist or timing).
            // If it still doesn't load, the problem is deeper.
            
            // Fallback fetch if requestLocationPermission is commented out,
            // as the sink might not fire without location updates.
            // This ensures some data is attempted to be loaded.
            if self.locationManager.authorizationStatus != .authorizedWhenInUse && self.locationManager.authorizationStatus != .authorizedAlways {
                 self.fetchWeatherData(forCity: self.locationManager.locationName) // Will likely use "Loading..." or "Location Disabled"
            }
        }
    }

    func setLocationManually(cityName: String) {
        locationManager.setManualLocation(cityName: cityName)
    }

    func useCurrentLocation() {
        locationManager.clearManualLocationAndUseGPS()
    }

    func fetchWeatherData(forCity city: String? = nil) {
        let targetCity = city ?? locationManager.locationName

        isLoading = true
        if var current = self.currentWeather {
            current.locationName = targetCity
            self.currentWeather = current
        } else {
            self.currentWeather = CurrentWeatherInfo(temperature: 0, condition: .mist, locationName: targetCity, todayHigh: 0, todayLow: 0)
        }

        if targetCity.isEmpty || targetCity == "Location Disabled" || targetCity == "Location Error" {
            self.isLoading = false
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { 
            self.generateMockWeatherData(locationName: targetCity)
            self.isLoading = false
            self.lastUpdateTime = Date()
        }
    }

    private func generateMockWeatherData(locationName: String) {
        let calendar = Calendar.current
        let now = Date()

        let mockHigh = 20 + Int.random(in: -3...3)
        let mockLow = mockHigh - Int.random(in: 4...7)
        
        self.currentWeather = CurrentWeatherInfo(
            temperature: 18 + Int.random(in: -2...2),
            condition: WeatherCondition.allCases.randomElement() ?? .partlyCloudyDay,
            locationName: locationName,
            todayHigh: mockHigh,
            todayLow: mockLow
        )

        var hourly: [HourlyForecastInfo] = []
        for i in 0..<8 {
            if let hourDate = calendar.date(byAdding: .hour, value: i + 1, to: now) {
                hourly.append(HourlyForecastInfo(date: hourDate, temperature: (self.currentWeather?.temperature ?? 18) - i/2 + Int.random(in: -1...1), condition: WeatherCondition.allCases.randomElement()!))
            }
        }
        self.hourlyForecasts = hourly

        var daily: [DailyForecastInfo] = []
        for i in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: i + 1, to: now) {
                let high = mockHigh + Int.random(in: -2...2) - i/2
                daily.append(DailyForecastInfo(date: dayDate, highTemp: high, lowTemp: high - Int.random(in: 4...7), condition: WeatherCondition.allCases.randomElement()!))
            }
        }
        self.dailyForecasts = daily
    }
}
