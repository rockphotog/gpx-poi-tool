# GPX POI Tool - Native macOS App

A native SwiftUI macOS application for managing Points of Interest (POI) in GPX files. This app provides a beautiful, intuitive interface for importing, viewing, and managing your GPS waypoint collections.

![macOS Native App](../graphics/kart-1.png)
*Native macOS interface with map integration and seamless file handling*

## ✨ Features

### 🍎 **Native macOS Experience**
- **SwiftUI Interface**: Modern, responsive design with native macOS controls
- **MapKit Integration**: High-performance native maps with custom annotations
- **Drag & Drop Support**: Simply drag GPX files into the app window
- **File Association**: Double-click GPX files to open directly in the app
- **Keyboard Shortcuts**: Full keyboard navigation support

### 📍 **POI Management**
- **Import GPX Files**: Multi-file import with progress indication
- **Smart Deduplication**: Automatic duplicate detection and merging
- **Real-time Search**: Instant filtering of POI collections
- **Elevation Lookup**: Integration with existing Python tool for elevation data
- **Export Options**: KML export for Google Earth compatibility

### 🗺️ **Map Features**
- **Interactive Map**: Pan, zoom, and explore your POI collections
- **Smart Annotations**: Color-coded POI markers with intelligent symbolization
- **POI Selection**: Click markers to view detailed information
- **Fit All**: Automatically frame all POIs in the map view
- **Apple Maps Integration**: Open POIs directly in Apple Maps

## 🚀 Getting Started

### Requirements
- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** for building from source
- **Python 3.6+** with the existing POI tool (for advanced features)

### Installation Options

#### Option 1: Build from Source (Recommended)
1. **Open in Xcode**:
   ```bash
   cd GPXPOITool-SwiftUI
   open GPXPOITool.xcodeproj
   ```

2. **Build and Run**:
   - Select your Mac as the target
   - Press `Cmd+R` to build and run
   - The app will launch automatically

#### Option 2: Pre-built App (Coming Soon)
- Download the signed `.app` bundle from releases
- Drag to Applications folder
- Launch like any other Mac app

### First Launch
1. **Import GPX Files**: Click "Import GPX" or drag files into the window
2. **Explore Your POIs**: Use the map and list to browse your collection
3. **Add Elevation Data**: Click "Add Elevation" to enhance POIs with elevation information
4. **Export for Google Earth**: Use "Export KML" to create Google Earth files

## 🛠 Architecture

### SwiftUI + Python Integration
The app combines the best of both worlds:

```
┌─────────────────────────────────────┐
│        SwiftUI Native UI            │
│  ├─ MapView (MapKit)               │
│  ├─ POIListView                    │
│  └─ ContentView                    │
└─────────────────────────────────────┘
                  │
┌─────────────────────────────────────┐
│       GPXProcessor Service          │
│  ├─ Swift GPX parsing              │
│  ├─ Python tool integration        │
│  └─ File management                │
└─────────────────────────────────────┘
                  │
┌─────────────────────────────────────┐
│      Existing Python Tool          │
│  ├─ poi-tool.py                    │
│  ├─ Elevation lookup               │
│  └─ Advanced processing            │
└─────────────────────────────────────┘
```

### Key Components

#### Models
- **`POI.swift`**: Core POI data structure with MapKit integration
- **`POICollection`**: Collection management with deduplication logic

#### Views
- **`ContentView.swift`**: Main app interface with split view layout
- **`MapView.swift`**: Native MapKit integration with custom annotations
- **`POIListView.swift`**: Searchable, sortable POI list with statistics

#### Services
- **`GPXProcessor.swift`**: File I/O, Python tool integration, and data management

## 🔧 Development

### Project Structure
```
GPXPOITool-SwiftUI/
├── GPX POI Tool/
│   ├── GPXPOIToolApp.swift         # App entry point
│   ├── ContentView.swift           # Main interface
│   ├── Models/
│   │   └── POI.swift              # Data models
│   ├── Views/
│   │   ├── MapView.swift          # Map interface
│   │   └── POIListView.swift      # POI list
│   ├── Services/
│   │   └── GPXProcessor.swift     # Core processing
│   ├── Info.plist                # App configuration
│   └── GPX_POI_Tool.entitlements # Sandbox permissions
└── GPXPOITool.xcodeproj/          # Xcode project
```

### Building and Debugging

#### Debug Build
```bash
# Build in Xcode or via command line
xcodebuild -project GPXPOITool.xcodeproj -scheme "GPX POI Tool" -configuration Debug
```

#### Release Build
```bash
# Create release build
xcodebuild -project GPXPOITool.xcodeproj -scheme "GPX POI Tool" -configuration Release
```

#### Python Tool Integration
The app automatically finds your Python tool in these locations:
1. **App Bundle**: `GPX POI Tool.app/Contents/Resources/poi-tool.py`
2. **Development**: `../poi-tool.py` (relative to project)
3. **Current Directory**: `./poi-tool.py`

## 🎯 Usage Examples

### Import Multiple Files
```swift
// Programmatically (for automation)
let urls = [URL(fileURLWithPath: "/path/to/file1.gpx"),
           URL(fileURLWithPath: "/path/to/file2.gpx")]
let result = try await gpxProcessor.importGPXFiles(urls)
print("Added \(result.added) POIs, merged \(result.merged)")
```

### Export to KML
```swift
// Export current collection to Google Earth
let kmlURL = URL(fileURLWithPath: "/path/to/output.kml")
try await gpxProcessor.exportKML(to: kmlURL)
```

## 🚀 Advantages over Python GUI

### Performance
- **⚡ Native Speed**: Swift compiled code vs interpreted Python
- **🖼️ GPU Acceleration**: Native MapKit rendering vs web-based maps
- **💾 Memory Efficiency**: Lower memory footprint and better resource management

### User Experience
- **🍎 Native Feel**: Follows macOS Human Interface Guidelines
- **⌨️ Keyboard Navigation**: Full keyboard shortcuts and accessibility
- **📱 Responsive Design**: Smooth animations and real-time updates
- **🔗 System Integration**: File associations, drag-drop, and system services

### Distribution
- **📦 Single App Bundle**: No Python dependencies to install
- **🔒 Code Signing**: Trusted app distribution through App Store or direct download
- **🔄 Auto Updates**: Native update mechanisms

## 🔮 Future Enhancements

### Planned Features
- **📊 Advanced Statistics**: Elevation profiles, distance calculations
- **🇳🇴 Kartverket Integration**: Native Norwegian elevation data API
- **📱 iOS Companion**: Shared POI collections across devices via CloudKit
- **🎨 Custom Symbols**: User-defined POI categories and icons
- **📈 Batch Processing**: Background processing of large collections

### Technical Improvements
- **⚡ Core Data**: Persistent storage for large collections
- **☁️ CloudKit Sync**: Cross-device synchronization
- **🔍 Spotlight Integration**: System-wide POI search
- **🗂️ Quick Look**: Preview GPX files in Finder

## 📝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**: Follow Swift/SwiftUI best practices
4. **Test thoroughly**: Ensure compatibility with existing Python tool
5. **Submit a pull request**: Describe your changes clearly

## 📄 License

This native macOS app is part of the GPX POI Tool project and follows the same license as the main project.

---

**Ready to build?** Open `GPXPOITool.xcodeproj` in Xcode and press `Cmd+R`! 🚀
