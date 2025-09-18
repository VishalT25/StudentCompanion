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
    let temperature: Int // Celsius
    let condition: WeatherCondition
    var locationName: String
    let todayHigh: Int
    let todayLow: Int
    let humidity: Int
    let windSpeed: Double
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

// MARK: - City Selection
struct City: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    
    var displayName: String {
        return "\(name), \(country)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: City, rhs: City) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - OpenWeatherMap API Models
struct OpenWeatherResponse: Codable {
    let main: MainWeather
    let weather: [WeatherDescription]
    let wind: Wind
    let name: String
}

struct MainWeather: Codable {
    let temp: Double
    let tempMin: Double?
    let tempMax: Double?
    let humidity: Int
}

struct WeatherDescription: Codable {
    let main: String
    let description: String
    let icon: String
}

struct Wind: Codable {
    let speed: Double?
}

struct ForecastResponse: Codable {
    let list: [ForecastItem]
}

struct ForecastItem: Codable {
    let dt: TimeInterval
    let main: MainWeather
    let weather: [WeatherDescription]
}

// MARK: - Weather Service
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentWeather: CurrentWeatherInfo?
    @Published var hourlyForecasts: [HourlyForecastInfo] = []
    @Published var dailyForecasts: [DailyForecastInfo] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var selectedCity: City?
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiKey = Secrets.apiKey
    private let locationManager = CLLocationManager()
    
    @Published var availableCities: [City] = [
        // This will be updated dynamically
        City(name: "Current Location", country: "Fetching...", latitude: 0, longitude: 0),
        City(name: "Toronto", country: "Canada", latitude: 43.6532, longitude: -79.3832),
        City(name: "New York", country: "USA", latitude: 40.7128, longitude: -74.0060),
        City(name: "London", country: "UK", latitude: 51.5074, longitude: -0.1278),
        City(name: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522),
        City(name: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503),
        City(name: "Sydney", country: "Australia", latitude: -33.8688, longitude: 151.2093),
    ]

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        if let lastCity = getLastSelectedCity() {
            self.selectedCity = lastCity
        } else {
            self.selectedCity = availableCities.first
        }
        
        DispatchQueue.main.async {
            self.requestLocation()
        }
    }
    
    func selectCity(_ city: City) {
        selectedCity = city
        saveLastSelectedCity(city)
        if city.name == "Current Location" {
            requestLocation()
        } else {
            fetchWeatherData(latitude: city.latitude, longitude: city.longitude)
        }
    }

    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            if let firstCity = availableCities.first(where: { $0.name != "Current Location" }) {
                selectCity(firstCity)
            }
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            
            updateCurrentLocationCityName(for: location)
            
            if selectedCity?.name == "Current Location" {
                fetchWeatherData(latitude: lat, longitude: lon)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Failed to get location. Showing default."
        if let firstCity = availableCities.first(where: { $0.name != "Current Location" }) {
            selectCity(firstCity)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestLocation()
    }
    
    func refreshWeatherData() {
        guard let city = selectedCity else {
            requestLocation()
            return
        }

        if city.name == "Current Location" {
            requestLocation()
        } else {
            fetchWeatherData(latitude: city.latitude, longitude: city.longitude)
        }
    }
    
    private func updateCurrentLocationCityName(for location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let placemark = placemarks?.first, let index = self.availableCities.firstIndex(where: { $0.name == "Current Location" }) {
                let name = placemark.locality ?? "Current Location"
                let country = placemark.country ?? ""
                
                DispatchQueue.main.async {
                    self.availableCities[index] = City(name: name, country: country, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                }
            }
        }
    }
    
    func fetchWeatherData(latitude: Double, longitude: Double) {
        isLoading = true
        errorMessage = nil
        
        fetchCurrentWeather(latitude: latitude, longitude: longitude)
    }
    
    private func fetchCurrentWeather(latitude: Double, longitude: Double) {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            handleAPIError("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.handleAPIError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.handleAPIError("No data received")
                    return
                }
                
                do {
                    let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                    self.processCurrentWeather(weatherResponse, lat: latitude, lon: longitude)
                    self.fetchForecast(latitude: latitude, longitude: longitude)
                } catch {
                    self.handleAPIError("Failed to decode weather data: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func fetchForecast(latitude: Double, longitude: Double) {
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.lastUpdateTime = Date()
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let data = data {
                    do {
                        let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)
                        self.processForecastData(forecastResponse)
                    } catch {
                    }
                }
                
                self.isLoading = false
                self.lastUpdateTime = Date()
            }
        }.resume()
    }
    
    private func processCurrentWeather(_ response: OpenWeatherResponse, lat: Double, lon: Double) {
        let condition = mapOpenWeatherToCondition(response.weather.first?.main ?? "", icon: response.weather.first?.icon ?? "")
        
        let locationName = selectedCity?.name == "Current Location" ? response.name : selectedCity?.displayName ?? response.name

        currentWeather = CurrentWeatherInfo(
            temperature: Int(response.main.temp.rounded()),
            condition: condition,
            locationName: locationName,
            todayHigh: Int((response.main.tempMax ?? response.main.temp).rounded()),
            todayLow: Int((response.main.tempMin ?? response.main.temp).rounded()),
            humidity: response.main.humidity,
            windSpeed: response.wind.speed ?? 0.0
        )
    }

    private func processForecastData(_ response: ForecastResponse) {
        let calendar = Calendar.current

        let interpolatedHourly = interpolateHourlyForecasts(response.list)
        self.hourlyForecasts = Array(interpolatedHourly.prefix(12)) // Show next 12 hours

        var dailyData: [DailyForecastInfo] = []
        var dailyGroups: [Date: [ForecastItem]] = [:]

        for item in response.list {
            let date = Date(timeIntervalSince1970: item.dt)
            let day = calendar.startOfDay(for: date)
            dailyGroups[day, default: []].append(item)
        }

        for (day, items) in dailyGroups.sorted(by: { $0.key < $1.key }).prefix(5) {
            guard let firstItem = items.first else { continue }
            
            let high = items.map { $0.main.tempMax ?? $0.main.temp }.max() ?? firstItem.main.temp
            let low = items.map { $0.main.tempMin ?? $0.main.temp }.min() ?? firstItem.main.temp
            
            let condition = mapOpenWeatherToCondition(firstItem.weather.first?.main ?? "", icon: firstItem.weather.first?.icon ?? "")

            dailyData.append(DailyForecastInfo(
                date: day,
                highTemp: Int(high.rounded()),
                lowTemp: Int(low.rounded()),
                condition: condition
            ))
        }
        self.dailyForecasts = dailyData
    }
    
    private func interpolateHourlyForecasts(_ forecastItems: [ForecastItem]) -> [HourlyForecastInfo] {
        guard forecastItems.count > 1 else {
            return forecastItems.map { item in
                HourlyForecastInfo(
                    date: Date(timeIntervalSince1970: item.dt),
                    temperature: Int(item.main.temp.rounded()),
                    condition: mapOpenWeatherToCondition(item.weather.first?.main ?? "", icon: item.weather.first?.icon ?? "")
                )
            }
        }

        var interpolated: [HourlyForecastInfo] = []
        let now = Date()

        // Filter for forecasts starting from the current time
        let futureItems = forecastItems.filter { Date(timeIntervalSince1970: $0.dt) >= now }
        guard !futureItems.isEmpty else { return [] }

        for i in 0..<(futureItems.count - 1) {
            let startItem = futureItems[i]
            let endItem = futureItems[i+1]

            let startDate = Date(timeIntervalSince1970: startItem.dt)
            let endDate = Date(timeIntervalSince1970: endItem.dt)
            let timeDifference = endDate.timeIntervalSince(startDate)
            
            guard timeDifference > 0 else { continue }

            let startTemp = startItem.main.temp
            let endTemp = endItem.main.temp
            let tempDifference = endTemp - startTemp
            
            let hours = Int(timeDifference / 3600)

            for hour in 0..<hours {
                let interpolatedDate = startDate.addingTimeInterval(TimeInterval(hour * 3600))
                
                // Don't add forecasts for the past
                guard interpolatedDate >= now else { continue }
                
                let ratio = Double(hour) / Double(hours)
                let interpolatedTemp = startTemp + (tempDifference * ratio)
                
                // Use the condition from the start of the period
                let condition = mapOpenWeatherToCondition(startItem.weather.first?.main ?? "", icon: startItem.weather.first?.icon ?? "")

                interpolated.append(
                    HourlyForecastInfo(
                        date: interpolatedDate,
                        temperature: Int(interpolatedTemp.rounded()),
                        condition: condition
                    )
                )
            }
        }
        
        // Add the last forecast item to complete the set
        if let lastItem = futureItems.last {
            interpolated.append(
                HourlyForecastInfo(
                    date: Date(timeIntervalSince1970: lastItem.dt),
                    temperature: Int(lastItem.main.temp.rounded()),
                    condition: mapOpenWeatherToCondition(lastItem.weather.first?.main ?? "", icon: lastItem.weather.first?.icon ?? "")
                )
            )
        }

        return interpolated
    }
    
    private func mapOpenWeatherToCondition(_ main: String, icon: String) -> WeatherCondition {
        let isNight = icon.contains("n")
        
        switch main.lowercased() {
        case "clear":
            return isNight ? .clearNight : .clearDay
        case "clouds":
            if icon.contains("02") || icon.contains("03") {
                return isNight ? .partlyCloudyNight : .partlyCloudyDay
            } else {
                return .cloudy
            }
        case "rain":
            return icon.contains("09") ? .showerRain : .rain
        case "thunderstorm":
            return .thunderstorm
        case "snow":
            return .snow
        case "mist", "fog", "haze":
            return .mist
        default:
            return isNight ? .clearNight : .clearDay
        }
    }
    
    private func handleAPIError(_ message: String) {
        errorMessage = message
        isLoading = false
        generateMockWeatherData()
    }

    private func generateMockWeatherData() {
        let calendar = Calendar.current
        let now = Date()

        let baseTemp = 20
        let mockHigh = baseTemp + 5
        let mockLow = baseTemp - 5
        
        self.currentWeather = CurrentWeatherInfo(
            temperature: baseTemp,
            condition: .partlyCloudyDay,
            locationName: selectedCity?.displayName ?? "Mock Location",
            todayHigh: mockHigh,
            todayLow: mockLow,
            humidity: 55,
            windSpeed: 15
        )

        var hourly: [HourlyForecastInfo] = []
        for i in 0..<8 {
            if let hourDate = calendar.date(byAdding: .hour, value: i + 1, to: now) {
                hourly.append(HourlyForecastInfo(
                    date: hourDate,
                    temperature: baseTemp + Int.random(in: -3...3),
                    condition: [.clearDay, .partlyCloudyDay, .cloudy].randomElement()!
                ))
            }
        }
        self.hourlyForecasts = hourly

        var daily: [DailyForecastInfo] = []
        for i in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: i + 1, to: now) {
                let dayHigh = baseTemp + Int.random(in: 2...7)
                daily.append(DailyForecastInfo(
                    date: dayDate,
                    highTemp: dayHigh,
                    lowTemp: dayHigh - Int.random(in: 5...10),
                    condition: WeatherCondition.allCases.randomElement()!
                ))
            }
        }
        self.dailyForecasts = daily
        
        self.lastUpdateTime = Date()
    }
    
    private func saveLastSelectedCity(_ city: City) {
        if let data = try? JSONEncoder().encode(city) {
            UserDefaults.standard.set(data, forKey: "LastSelectedCity")
        }
    }
    
    private func getLastSelectedCity() -> City? {
        if let data = UserDefaults.standard.data(forKey: "LastSelectedCity") {
            return try? JSONDecoder().decode(City.self, from: data)
        }
        return nil
    }
}