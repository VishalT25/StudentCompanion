import SwiftUI

enum ForecastTypeSelection: String, CaseIterable, Identifiable {
    case hourly = "Hourly"
    case daily = "Daily"
    var id: String { self.rawValue }
}

struct WeatherWidgetView: View {
    @ObservedObject var weatherService: WeatherService
    @EnvironmentObject var themeManager: ThemeManager
    
    @Binding var isPresented: Bool

    @State private var selectedForecastType: ForecastTypeSelection = .hourly
    @State private var showingCitySelection = false
    
    private var dynamicBackgroundColor: LinearGradient {
        guard let condition = weatherService.currentWeather?.condition else {
            return LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.85), Color.gray.opacity(0.65)]), startPoint: .top, endPoint: .bottom)
        }
        
        switch condition {
        case .clearDay:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.65), Color.orange.opacity(0.55)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .clearNight:
            return LinearGradient(gradient: Gradient(colors: [Color(red: 20/255, green: 30/255, blue: 60/255).opacity(0.90), Color(red: 40/255, green: 60/255, blue: 100/255).opacity(0.85)]), startPoint: .top, endPoint: .bottom)
        case .partlyCloudyDay, .cloudy:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.55), Color.gray.opacity(0.65)]), startPoint: .top, endPoint: .bottom)
        case .partlyCloudyNight:
            return LinearGradient(gradient: Gradient(colors: [Color(red: 30/255, green: 50/255, blue: 80/255).opacity(0.75), Color.gray.opacity(0.75)]), startPoint: .top, endPoint: .bottom)
        case .rain, .showerRain:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.75), Color.gray.opacity(0.85)]), startPoint: .top, endPoint: .bottom)
        case .thunderstorm:
            return LinearGradient(gradient: Gradient(colors: [Color.indigo.opacity(0.85), Color.gray.opacity(0.75)]), startPoint: .top, endPoint: .bottom)
        case .snow:
            return LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.45), Color.purple.opacity(0.55)]), startPoint: .top, endPoint: .bottom)
        case .mist:
            return LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.65), Color.white.opacity(0.35)]), startPoint: .top, endPoint: .bottom)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView.padding(.bottom, 5)

            if weatherService.isLoading && weatherService.currentWeather == nil {
                Spacer()
                ProgressView("Loading Weather...")
                    .foregroundColor(.white)
                Spacer()
            } else if let currentWeather = weatherService.currentWeather {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        CurrentWeatherHeaderView(
                            currentWeather: currentWeather,
                            selectedForecastType: $selectedForecastType,
                            showingCitySelection: $showingCitySelection
                        )
                        
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
                        
                        if let errorMessage = weatherService.errorMessage {
                            Text("Error: \(errorMessage)")
                                .font(.caption2)
                                .foregroundColor(.yellow.opacity(0.8))
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("Could not load weather data.")
                    .foregroundColor(.white.opacity(0.8))
                Button {
                    weatherService.requestLocation()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .padding()
                }
                Spacer()
            }
        }
        .padding()
        .background(dynamicBackgroundColor)
        .foregroundColor(.white)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
        .adaptiveWidgetDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 24)
        .frame(maxWidth: .infinity, maxHeight: 500)
        .sheet(isPresented: $showingCitySelection) {
            CitySelectionView(weatherService: weatherService)
        }
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresented = false
                }
            } label: {
                Text("Done")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .font(.forma(.headline, weight: .medium))
                    .foregroundColor(.white)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
        }
    }
}

struct CurrentWeatherHeaderView: View {
    let currentWeather: CurrentWeatherInfo
    @Binding var selectedForecastType: ForecastTypeSelection
    @Binding var showingCitySelection: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    showingCitySelection = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                        Text(currentWeather.locationName)
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .font(.forma(.headline, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Image(systemName: currentWeather.condition.SFSymbolName)
                    .renderingMode(.original)
                    .font(.title2)
                
                HDToggleView(selectedType: $selectedForecastType)
            }
            
            Text("\(currentWeather.temperature)°")
                .font(.system(size: 70, weight: .thin))
            
            Text(currentWeather.condition.description)
                .font(.forma(.title3, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Text("H:\(currentWeather.todayHigh)° L:\(currentWeather.todayLow)°")
                .font(.forma(.headline, weight: .medium))
            
            HStack(spacing: 30) {
                VStack {
                    Text("Humidity")
                    Text("\(currentWeather.humidity)%")
                }
                VStack {
                    Text("Wind")
                    Text("\(Int(currentWeather.windSpeed)) km/h")
                }
            }
            .font(.forma(.subheadline, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
        }
        .foregroundColor(.white)
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
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}

struct HDToggleButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.forma(.subheadline, weight: isSelected ? .bold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.clear)
            )
            .foregroundColor(.white)
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
            HStack(spacing: 25) {
                ForEach(hourlyForecasts) { forecast in
                    VStack(spacing: 12) {
                        Text(formatHour(forecast.date))
                            .font(.forma(.subheadline, weight: .medium))
                        
                        Image(systemName: forecast.condition.SFSymbolName)
                            .renderingMode(.original)
                            .font(.title2)
                        
                        Text("\(forecast.temperature)°")
                            .font(.forma(.title3, weight: .medium))
                    }
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
        VStack(spacing: 12) {
            ForEach(dailyForecasts) { forecast in
                HStack {
                    Text(formatDay(forecast.date))
                        .font(.forma(.headline, weight: .medium))
                        .frame(width: 80, alignment: .leading)

                    Image(systemName: forecast.condition.SFSymbolName)
                        .renderingMode(.original)
                        .font(.title3)
                        .frame(width: 40)
                    
                    Text("\(forecast.lowTemp)°")
                        .font(.forma(.headline))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Simple progress bar for temperature range
                    GeometryReader { geo in
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 5)
                            .frame(width: geo.size.width)
                    }
                    .frame(height: 5)

                    Text("\(forecast.highTemp)°")
                        .font(.forma(.headline, weight: .medium))
                }
                .foregroundColor(.white)
            }
        }
    }
}


struct CitySelectionView: View {
    @ObservedObject var weatherService: WeatherService
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredCities: [City] {
        let cities = weatherService.availableCities
        if searchText.isEmpty {
            return cities
        } else {
            return cities.filter { city in
                let displayName = city.name == "Current Location" ? "Current Location" : city.displayName
                return displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search cities...", text: $searchText)
                        .font(.forma(.body))
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()

                // City List
                List(filteredCities) { city in
                    Button {
                        weatherService.selectCity(city)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(city.name == "Current Location" ? city.country == "Fetching..." ? "Current Location" : city.name : city.name)
                                    .font(.forma(.body, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if city.country != "Fetching..." {
                                    Text(city.country)
                                        .font(.forma(.subheadline))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if weatherService.selectedCity == city {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .font(.forma(.body, weight: .bold))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.forma(.body))
                }
            }
        }
    }
}

#Preview {
    let previewWeatherService = WeatherService()
    WeatherWidgetView(weatherService: previewWeatherService, isPresented: .constant(true))
        .environmentObject(ThemeManager())
        .background(Color.blue.opacity(0.3))
}