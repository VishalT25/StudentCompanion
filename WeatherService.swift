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
struct City: Identifiable, Codable {
    let id = UUID()
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    
    var displayName: String {
        return "\(name), \(country)"
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
class WeatherService: ObservableObject {
    @Published var currentWeather: CurrentWeatherInfo?
    @Published var hourlyForecasts: [HourlyForecastInfo] = []
    @Published var dailyForecasts: [DailyForecastInfo] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var selectedCity: City
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiKey = "8ef6e2b4d35af6a720b14c97e8cd807a"
    
    let availableCities: [City] = [
        City(name: "Toronto", country: "Canada", latitude: 43.6532, longitude: -79.3832),
        City(name: "New York", country: "USA", latitude: 40.7128, longitude: -74.0060),
        City(name: "London", country: "UK", latitude: 51.5074, longitude: -0.1278),
        City(name: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522),
        City(name: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503),
        City(name: "Sydney", country: "Australia", latitude: -33.8688, longitude: 151.2093),
        City(name: "Vancouver", country: "Canada", latitude: 49.2827, longitude: -123.1207),
        City(name: "Montreal", country: "Canada", latitude: 45.5017, longitude: -73.5673),
        City(name: "Los Angeles", country: "USA", latitude: 34.0522, longitude: -118.2437),
        City(name: "Chicago", country: "USA", latitude: 41.8781, longitude: -87.6298),
        City(name: "Miami", country: "USA", latitude: 25.7617, longitude: -80.1918),
        City(name: "Berlin", country: "Germany", latitude: 52.5200, longitude: 13.4050),
        City(name: "Rome", country: "Italy", latitude: 41.9028, longitude: 12.4964),
        City(name: "Madrid", country: "Spain", latitude: 40.4168, longitude: -3.7038),
        City(name: "Amsterdam", country: "Netherlands", latitude: 52.3676, longitude: 4.9041),
        City(name: "Seoul", country: "South Korea", latitude: 37.5665, longitude: 126.9780),
        City(name: "Singapore", country: "Singapore", latitude: 1.3521, longitude: 103.8198),
        City(name: "Mumbai", country: "India", latitude: 19.0760, longitude: 72.8777),
        City(name: "Dubai", country: "UAE", latitude: 25.2048, longitude: 55.2708),
        City(name: "São Paulo", country: "Brazil", latitude: -23.5505, longitude: -46.6333)
    ]

    init() {
        self.selectedCity = availableCities.first { $0.name == "Toronto" } ?? availableCities[0]
        
        DispatchQueue.main.async {
            self.fetchWeatherData()
        }
    }
    
    func selectCity(_ city: City) {
        selectedCity = city
        fetchWeatherData()
    }

    func fetchWeatherData() {
        guard !selectedCity.name.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        print("Starting weather data fetch for \(selectedCity.displayName)")
        fetchCurrentWeather()
    }
    
    private func fetchCurrentWeather() {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(selectedCity.latitude)&lon=\(selectedCity.longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            handleAPIError("Invalid URL")
            return
        }
        
        print("Fetching weather from URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Network error: \(error)")
                    self.handleAPIError("Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                    
                    switch httpResponse.statusCode {
                    case 200:
                        break
                    case 401:
                        print("API Key invalid or unauthorized")
                        self.handleAPIError("Invalid API key")
                        return
                    case 429:
                        print("API rate limit exceeded")
                        self.handleAPIError("API rate limit exceeded")
                        return
                    case 404:
                        print("Location not found")
                        self.handleAPIError("Location not found")
                        return
                    default:
                        print("HTTP Error: \(httpResponse.statusCode)")
                        self.handleAPIError("HTTP Error: \(httpResponse.statusCode)")
                        return
                    }
                }
                
                guard let data = data else {
                    print("No data received from API")
                    self.handleAPIError("No data received")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw API Response: \(responseString)")
                }
                
                do {
                    let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                    print("✅ Successfully decoded weather response!")
                    print("Temperature: \(weatherResponse.main.temp)°C")
                    print("Condition: \(weatherResponse.weather.first?.main ?? "Unknown")")
                    
                    self.processCurrentWeather(weatherResponse)
                    self.fetchForecast()
                } catch {
                    print("❌ Decode error: \(error)")
                    if let decodingError = error as? DecodingError {
                        print("Detailed decoding error: \(decodingError)")
                    }
                    self.handleAPIError("Failed to decode weather data: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func fetchForecast() {
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?lat=\(selectedCity.latitude)&lon=\(selectedCity.longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.lastUpdateTime = Date()
            return
        }
        
        print("Fetching forecast from URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Forecast fetch error: \(error)")
                } else if let data = data {
                    do {
                        let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)
                        print("✅ Successfully decoded forecast response!")
                        self.processForecastData(forecastResponse)
                    } catch {
                        print("❌ Failed to decode forecast data: \(error)")
                    }
                }
                
                self.isLoading = false
                self.lastUpdateTime = Date()
                
                if self.currentWeather != nil {
                    self.errorMessage = nil
                    print("✅ Weather data fetch completed successfully!")
                }
            }
        }.resume()
    }
    
    private func processCurrentWeather(_ response: OpenWeatherResponse) {
        let condition = mapOpenWeatherToCondition(response.weather.first?.main ?? "", icon: response.weather.first?.icon ?? "")
        
        print("Processing weather data:")
        print("- Temperature: \(response.main.temp)°C")
        print("- High: \(response.main.tempMax ?? response.main.temp)°C, Low: \(response.main.tempMin ?? response.main.temp)°C")
        print("- Humidity: \(response.main.humidity)%")
        print("- Wind Speed: \(response.wind.speed ?? 0.0) m/s")
        print("- Condition: \(condition.description)")
        
        currentWeather = CurrentWeatherInfo(
            temperature: Int(response.main.temp.rounded()),
            condition: condition,
            locationName: selectedCity.displayName,
            todayHigh: Int((response.main.tempMax ?? response.main.temp).rounded()),
            todayLow: Int((response.main.tempMin ?? response.main.temp).rounded()),
            humidity: response.main.humidity,
            windSpeed: response.wind.speed ?? 0.0
        )
        
        print("✅ Current weather processed and published!")
    }

    private func processForecastData(_ response: ForecastResponse) {
        let calendar = Calendar.current
        print("Processing forecast data with \(response.list.count) items.")

        var hourlyData: [HourlyForecastInfo] = []
        for item in response.list.prefix(8) {
            let date = Date(timeIntervalSince1970: item.dt)
            let condition = mapOpenWeatherToCondition(item.weather.first?.main ?? "", icon: item.weather.first?.icon ?? "")
            
            hourlyData.append(HourlyForecastInfo(
                date: date,
                temperature: Int(item.main.temp.rounded()),
                condition: condition
            ))
        }
        self.hourlyForecasts = hourlyData
        print("Processed \(hourlyData.count) hourly forecasts.")

        var dailyData: [DailyForecastInfo] = []
        var dailyGroups: [String: [ForecastItem]] = [:]
        
        if response.list.isEmpty {
            print("Forecast list is empty. No daily data to process.")
            self.dailyForecasts = []
            return
        }

        for item in response.list {
            let date = Date(timeIntervalSince1970: item.dt)
            let dayKeyComponents = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = dayKeyComponents.year, let month = dayKeyComponents.month, let day = dayKeyComponents.day else {
                print("Could not get year/month/day from date \(date) for forecast item.")
                continue
            }
            let dayString = "\(year)-\(month)-\(day)"
            
            if dailyGroups[dayString] == nil {
                dailyGroups[dayString] = []
            }
            dailyGroups[dayString]?.append(item)
        }
        
        print("Found \(dailyGroups.count) unique days for daily forecast.")

        for (dayKey, items) in dailyGroups.sorted(by: { $0.key < $1.key }).prefix(5) {
            guard let firstItem = items.first else { continue }
            
            print("Processing daily forecast for day: \(dayKey)")

            let date = Date(timeIntervalSince1970: firstItem.dt)
            let high = items.map { $0.main.tempMax ?? $0.main.temp }.compactMap { $0 }.max() ?? firstItem.main.temp
            let low = items.map { $0.main.tempMin ?? $0.main.temp }.compactMap { $0 }.min() ?? firstItem.main.temp
            let condition = mapOpenWeatherToCondition(firstItem.weather.first?.main ?? "", icon: firstItem.weather.first?.icon ?? "")
            
            print(" - Date: \(date), High: \(high), Low: \(low), Condition: \(condition.rawValue)")

            dailyData.append(DailyForecastInfo(
                date: date,
                highTemp: Int(high.rounded()),
                lowTemp: Int(low.rounded()),
                condition: condition
            ))
        }
        self.dailyForecasts = dailyData
        self.dailyForecasts = dailyData
        print("Processed \(dailyData.count) daily forecasts.")
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
        print("🔴 API Error: \(message)")
        errorMessage = message
        isLoading = false
        
        print("⚠️ Falling back to mock weather data due to API error")
        generateMockWeatherData()
    }

    private func generateMockWeatherData() {
        print("🎲 Generating mock weather data for \(selectedCity.displayName)")
        let calendar = Calendar.current
        let now = Date()

        let (baseTemp, commonCondition) = getMockDataForLocation(selectedCity)
        let mockHigh = baseTemp + Int.random(in: 2...5)
        let mockLow = baseTemp - Int.random(in: 2...5)
        
        self.currentWeather = CurrentWeatherInfo(
            temperature: baseTemp + Int.random(in: -3...3),
            condition: commonCondition,
            locationName: selectedCity.displayName,
            todayHigh: mockHigh,
            todayLow: mockLow,
            humidity: 60 + Int.random(in: -25...25),
            windSpeed: Double.random(in: 5...20)
        )

        var hourly: [HourlyForecastInfo] = []
        for i in 0..<8 {
            if let hourDate = calendar.date(byAdding: .hour, value: i + 1, to: now) {
                hourly.append(HourlyForecastInfo(
                    date: hourDate,
                    temperature: baseTemp + Int.random(in: -5...5),
                    condition: getRandomConditionForLocation(selectedCity)
                ))
            }
        }
        self.hourlyForecasts = hourly

        var daily: [DailyForecastInfo] = []
        for i in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: i + 1, to: now) {
                let dayHigh = baseTemp + Int.random(in: 0...8)
                daily.append(DailyForecastInfo(
                    date: dayDate,
                    highTemp: dayHigh,
                    lowTemp: dayHigh - Int.random(in: 5...10),
                    condition: getRandomConditionForLocation(selectedCity)
                ))
            }
        }
        self.dailyForecasts = daily
        
        self.lastUpdateTime = Date()
        
        print("✅ Mock weather data generated successfully")
    }
    
    private func getMockDataForLocation(_ city: City) -> (Int, WeatherCondition) {
        switch city.name {
        case "Toronto", "Montreal", "Vancouver":
            return (18, .partlyCloudyDay)
        case "New York", "Chicago":
            return (22, .clearDay)
        case "London":
            return (15, .cloudy)
        case "Paris", "Berlin", "Amsterdam":
            return (20, .partlyCloudyDay)
        case "Tokyo", "Seoul":
            return (25, .clearDay)
        case "Sydney":
            return (23, .clearDay)
        case "Los Angeles", "Miami":
            return (28, .clearDay)
        case "Rome", "Madrid":
            return (26, .clearDay)
        case "Singapore":
            return (31, .partlyCloudyDay)
        case "Mumbai":
            return (32, .partlyCloudyDay)
        case "Dubai":
            return (35, .clearDay)
        case "São Paulo":
            return (24, .partlyCloudyDay)
        default:
            return (20, .partlyCloudyDay)
        }
    }
    
    private func getRandomConditionForLocation(_ city: City) -> WeatherCondition {
        let tropicalCities = ["Singapore", "Mumbai", "Miami"]
        let temperateCities = ["London", "Paris", "Toronto", "New York"]
        let desertCities = ["Dubai"]
        
        if tropicalCities.contains(city.name) {
            return [.clearDay, .partlyCloudyDay, .rain, .thunderstorm].randomElement() ?? .partlyCloudyDay
        } else if temperateCities.contains(city.name) {
            return [.clearDay, .partlyCloudyDay, .cloudy, .rain].randomElement() ?? .partlyCloudyDay
        } else if desertCities.contains(city.name) {
            return [.clearDay, .clearDay, .clearDay, .partlyCloudyDay].randomElement() ?? .clearDay
        } else {
            return WeatherCondition.allCases.randomElement() ?? .partlyCloudyDay
        }
    }
}
