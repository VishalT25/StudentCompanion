import SwiftUI

enum ForecastTypeSelection: String, CaseIterable, Identifiable {
    case hourly = "Hourly"
    case daily = "Daily"
    var id: String { self.rawValue }
}

struct WeatherWidgetView: View {
    @ObservedObject var weatherService: WeatherService
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedForecastType: ForecastTypeSelection = .hourly
    @State private var showingCityInputAlert = false
    @State private var cityInput: String = ""
    
    private var dynamicBackgroundColor: LinearGradient {
        guard let condition = weatherService.currentWeather?.condition else {
            return LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.6)]), startPoint: .top, endPoint: .bottom)
        }
        
        switch condition {
        case .clearDay:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.orange.opacity(0.5)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .clearNight:
            return LinearGradient(gradient: Gradient(colors: [Color(red: 20/255, green: 30/255, blue: 60/255), Color(red: 40/255, green: 60/255, blue: 100/255)]), startPoint: .top, endPoint: .bottom)
        case .partlyCloudyDay, .cloudy:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.gray.opacity(0.6)]), startPoint: .top, endPoint: .bottom)
        case .partlyCloudyNight:
            return LinearGradient(gradient: Gradient(colors: [Color(red: 30/255, green: 50/255, blue: 80/255), Color.gray.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
        case .rain, .showerRain:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.gray.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
        case .thunderstorm:
            return LinearGradient(gradient: Gradient(colors: [Color.indigo.opacity(0.8), Color.gray.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
        case .snow:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
        case .mist:
            return LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.6), Color.white.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView.padding(.top)

            if weatherService.isLoading && weatherService.currentWeather == nil {
                Spacer()
                ProgressView("Loading Weather...")
                    .foregroundColor(.white)
                Spacer()
            } else if let currentWeather = weatherService.currentWeather {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 15) {
                        CurrentWeatherHeaderView(currentWeather: currentWeather, selectedForecastType: $selectedForecastType, showingCityInputAlert: $showingCityInputAlert)
                        
                        if selectedForecastType == .hourly {
                            HourlyForecastScrollView(hourlyForecasts: weatherService.hourlyForecasts)
                        } else {
                            DailyForecastListView(dailyForecasts: weatherService.dailyForecasts)
                        }
                        
                        if let lastUpdate = weatherService.lastUpdateTime {
                            Text("Last updated: \(lastUpdate, style: .time)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 10)
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("Could not load weather data.")
                    .foregroundColor(.white.opacity(0.8))
                Button {
                    weatherService.fetchWeatherData()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .padding()
                }
                Spacer()
            }
        }
        .background(dynamicBackgroundColor)
        .foregroundColor(.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .frame(maxWidth: .infinity, idealHeight: 400, maxHeight: 500)
        .padding()
        .alert("Enter City Name", isPresented: $showingCityInputAlert) {
            TextField("City Name", text: $cityInput)
            Button("Set") {
                if !cityInput.isEmpty {
                    weatherService.setLocationManually(cityName: cityInput)
                    cityInput = "" // Reset for next time
                }
            }
            Button("Use Current Location") {
                weatherService.useCurrentLocation()
                cityInput = ""
            }
            Button("Cancel", role: .cancel) { cityInput = "" }
        } message: {
            Text("Enter the name of the city for weather updates, or use your current GPS location.")
        }
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .font(.headline)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
}

struct CurrentWeatherHeaderView: View {
    let currentWeather: CurrentWeatherInfo
    @Binding var selectedForecastType: ForecastTypeSelection
    @Binding var showingCityInputAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    showingCityInputAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text(currentWeather.locationName)
                            .font(.headline.weight(.medium))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain) // Keep text color
                
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: currentWeather.condition.SFSymbolName)
                        .renderingMode(.original)
                        .font(.title2)
                        .foregroundColor(currentWeather.condition.iconColor)
                        .frame(width: 30, height: 30)
                    HDToggleView(selectedType: $selectedForecastType)
                }
            }
            .foregroundColor(.white.opacity(0.9))
            
            HStack {
                Spacer()
                Text("\(currentWeather.temperature)°")
                    .font(.system(size: 60, weight: .thin))
                Spacer()
            }
            .padding(.vertical, -10)

            HStack {
                Spacer()
                Text(currentWeather.condition.description)
                    .font(.title3.weight(.regular))
                Spacer()
            }
            .foregroundColor(.white.opacity(0.9))

            HStack {
                Spacer()
                Text("H:\(currentWeather.todayHigh)° L:\(currentWeather.todayLow)°")
                    .font(.headline.weight(.medium))
                Spacer()
            }
            .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct HDToggleView: View {
    @Binding var selectedType: ForecastTypeSelection

    var body: some View {
        HStack(spacing: 0) {
            Button("H") { selectedType = .hourly }
                .buttonStyle(HDToggleButtonStyle(isSelected: selectedType == .hourly))
            Button("D") { selectedType = .daily }
                .buttonStyle(HDToggleButtonStyle(isSelected: selectedType == .daily))
        }
    }
}

struct HDToggleButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(isSelected ? .bold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(minWidth: 30)
            .background(isSelected ? Color.white.opacity(0.25) : Color.clear)
            .foregroundColor(.white)
            .cornerRadius(6)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct HourlyForecastScrollView: View {
    let hourlyForecasts: [HourlyForecastInfo]
    private let calendar = Calendar.current

    func formatHour(_ date: Date) -> String {
        if calendar.isDateInToday(date) && calendar.component(.hour, from: date) == calendar.component(.hour, from: Date()) {
            return "Now"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(hourlyForecasts) { forecast in
                    VStack(spacing: 8) {
                        Text(formatHour(forecast.date))
                            .font(.subheadline.weight(.medium))
                        Image(systemName: forecast.condition.SFSymbolName)
                            .font(.title2)
                            .foregroundColor(forecast.condition.iconColor)
                            .frame(height: 25)
                        Text("\(forecast.temperature)°")
                            .font(.title3.weight(.medium))
                    }
                    .frame(width: 60)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DailyForecastListView: View {
    let dailyForecasts: [DailyForecastInfo]
    private let calendar = Calendar.current

    func formatDay(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(dailyForecasts) { forecast in
                HStack(spacing: 15) {
                    Text(formatDay(forecast.date))
                        .font(.headline.weight(.medium))
                        .frame(width: 70, alignment: .leading)

                    Image(systemName: forecast.condition.SFSymbolName)
                        .font(.title3)
                        .foregroundColor(forecast.condition.iconColor)
                        .frame(width: 30)
                    
                    Spacer()
                    Text("H:\(forecast.highTemp)°")
                        .font(.headline.weight(.medium))
                    Text("L:\(forecast.lowTemp)°")
                        .font(.headline.weight(.regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    let previewWeatherService = WeatherService()
    return WeatherWidgetView(weatherService: previewWeatherService)
        .environmentObject(ThemeManager())
        .background(Color.blue.opacity(0.3))
}
