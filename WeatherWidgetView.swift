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
                            Text("Using mock data: \(errorMessage)")
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
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
        .frame(maxWidth: .infinity, idealHeight: 400, maxHeight: 500)
        .padding(16)
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
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.white)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
}

struct CurrentWeatherHeaderView: View {
    let currentWeather: CurrentWeatherInfo
    @Binding var selectedForecastType: ForecastTypeSelection
    @Binding var showingCitySelection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    showingCitySelection = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text(currentWeather.locationName)
                            .font(.headline.weight(.medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.7)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
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
                    .foregroundColor(.white)
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
            
            HStack {
                Spacer()
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("Humidity")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(currentWeather.humidity)%")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 2) {
                        Text("Wind")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(Int(currentWeather.windSpeed)) km/h")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
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
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.clear)
            )
            .foregroundColor(.white)
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
                            .foregroundColor(.white.opacity(0.8))
                        Image(systemName: forecast.condition.SFSymbolName)
                            .font(.title2)
                            .foregroundColor(forecast.condition.iconColor)
                            .frame(height: 25)
                        Text("\(forecast.temperature)°")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.white)
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
                        .foregroundColor(.white)

                    Image(systemName: forecast.condition.SFSymbolName)
                        .font(.title3)
                        .foregroundColor(forecast.condition.iconColor)
                        .frame(width: 30)
                    
                    Spacer()
                    Text("H:\(forecast.highTemp)°")
                        .font(.headline.weight(.medium))
                        .foregroundColor(.white)
                    Text("L:\(forecast.lowTemp)°")
                        .font(.headline.weight(.regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct CitySelectionView: View {
    @ObservedObject var weatherService: WeatherService
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredCities: [City] {
        if searchText.isEmpty {
            return weatherService.availableCities
        } else {
            return weatherService.availableCities.filter { city in
                city.name.localizedCaseInsensitiveContains(searchText) ||
                city.country.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Choose Location")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .opacity(0) 
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Search cities or countries...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .autocorrectionDisabled()
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.8),
                            Color.purple.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredCities) { city in
                            CityCard(
                                city: city,
                                isSelected: city.id == weatherService.selectedCity.id
                            ) {
                                weatherService.selectCity(city)
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationBarHidden(true)
    }
}

struct CityCard: View {
    let city: City
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.3),
                                    Color.purple.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 4) {
                    Text(city.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    
                    Text(city.country)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("Selected")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.green.opacity(0.5) : Color.gray.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let previewWeatherService = WeatherService()
    return WeatherWidgetView(weatherService: previewWeatherService, isPresented: .constant(true))
        .environmentObject(ThemeManager())
        .background(Color.blue.opacity(0.3))
}
