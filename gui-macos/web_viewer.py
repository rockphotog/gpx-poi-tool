#!/usr/bin/env python3
"""
GPX POI Tool - Web Viewer (Alternative to GUI)
A simple web-based interface for viewing GPX files when tkinter is not available.
"""

import http.server
import socketserver
import webbrowser
import json
import os
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse
import threading
import time

# Add the parent directory to path to import our poi modules
sys.path.append(str(Path(__file__).parent.parent))

try:
    from poi_formats import GPXFileHandler
except ImportError as e:
    print(f"Import Error: {e}")
    print("Could not import poi modules. "
          "Make sure you're running from the correct directory.")
    sys.exit(1)


class GPXHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler for GPX file operations"""
    
    def __init__(self, *args, **kwargs):
        self.gpx_handler = GPXFileHandler()
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_url = urlparse(self.path)
        
        if parsed_url.path == '/':
            self.serve_main_page()
        elif parsed_url.path == '/api/load_gpx':
            self.handle_load_gpx(parsed_url.query)
        elif parsed_url.path == '/api/list_files':
            self.handle_list_files()
        else:
            super().do_GET()
    
    def serve_main_page(self):
        """Serve the main HTML page"""
        html_content = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GPX POI Viewer</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f7;
            color: #1d1d1f;
            line-height: 1.5;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        h1 {
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5rem;
            font-weight: 600;
        }
        
        .file-section {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        
        .file-input {
            display: flex;
            align-items: center;
            gap: 20px;
            margin-bottom: 20px;
        }
        
        input[type="file"] {
            flex: 1;
            padding: 12px;
            border: 2px dashed #007aff;
            border-radius: 8px;
            background: #f0f8ff;
        }
        
        button {
            background: #007aff;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            transition: background 0.2s;
        }
        
        button:hover {
            background: #0056b3;
        }
        
        .stats {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .stats h3 {
            color: #007aff;
            margin-bottom: 10px;
        }
        
        .poi-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .poi-table th {
            background: #007aff;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        
        .poi-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
        }
        
        .poi-table tr:hover {
            background: #f8f9fa;
        }
        
        .no-data {
            text-align: center;
            color: #666;
            font-style: italic;
            padding: 40px;
        }
        
        .error {
            background: #ffe6e6;
            color: #d63031;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📍 GPX POI Viewer</h1>
        
        <div class="file-section">
            <div class="file-input">
                <input type="file" id="gpxFile" accept=".gpx" />
                <button onclick="loadGPXFile()">Load GPX File</button>
            </div>
            
            <div id="fileInfo" class="stats" style="display: none;">
                <h3>File Information</h3>
                <div id="fileStats"></div>
            </div>
        </div>
        
        <div id="errorContainer"></div>
        
        <div id="loadingContainer" style="display: none;">
            <div class="loading">Loading GPX file...</div>
        </div>
        
        <div id="poiContainer">
            <table class="poi-table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Latitude</th>
                        <th>Longitude</th>
                        <th>Elevation</th>
                        <th>Description</th>
                    </tr>
                </thead>
                <tbody id="poiTableBody">
                    <tr>
                        <td colspan="5" class="no-data">
                            Select a GPX file to view its POIs
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <script>
        function loadGPXFile() {
            const fileInput = document.getElementById('gpxFile');
            const file = fileInput.files[0];
            
            if (!file) {
                showError('Please select a GPX file');
                return;
            }
            
            showLoading(true);
            clearError();
            
            const reader = new FileReader();
            reader.onload = function(e) {
                const gpxContent = e.target.result;
                parseGPXContent(gpxContent, file.name);
            };
            reader.readAsText(file);
        }
        
        function parseGPXContent(content, filename) {
            try {
                const parser = new DOMParser();
                const xmlDoc = parser.parseFromString(content, 'text/xml');
                
                // Check for parsing errors
                const parseError = xmlDoc.getElementsByTagName('parsererror');
                if (parseError.length > 0) {
                    throw new Error('Invalid GPX file format');
                }
                
                // Extract waypoints (POIs)
                const waypoints = xmlDoc.getElementsByTagName('wpt');
                const pois = [];
                
                for (let i = 0; i < waypoints.length; i++) {
                    const wpt = waypoints[i];
                    const lat = wpt.getAttribute('lat');
                    const lon = wpt.getAttribute('lon');
                    
                    const name = getTextContent(wpt, 'name') || `POI ${i + 1}`;
                    const desc = getTextContent(wpt, 'desc') || '';
                    const ele = getTextContent(wpt, 'ele');
                    
                    pois.push({
                        name: name,
                        lat: parseFloat(lat),
                        lon: parseFloat(lon),
                        elevation: ele ? parseFloat(ele) : null,
                        description: desc
                    });
                }
                
                displayPOIs(pois, filename);
                showLoading(false);
                
            } catch (error) {
                showError(`Error parsing GPX file: ${error.message}`);
                showLoading(false);
            }
        }
        
        function getTextContent(parent, tagName) {
            const elements = parent.getElementsByTagName(tagName);
            return elements.length > 0 ? elements[0].textContent.trim() : null;
        }
        
        function displayPOIs(pois, filename) {
            // Update file info
            const fileInfo = document.getElementById('fileInfo');
            const fileStats = document.getElementById('fileStats');
            
            let statsHTML = `<strong>File:</strong> ${filename}<br>`;
            statsHTML += `<strong>POIs:</strong> ${pois.length}<br>`;
            
            if (pois.length > 0) {
                const elevations = pois.filter(poi => poi.elevation !== null).map(poi => poi.elevation);
                if (elevations.length > 0) {
                    const avgElevation = elevations.reduce((a, b) => a + b, 0) / elevations.length;
                    const minElevation = Math.min(...elevations);
                    const maxElevation = Math.max(...elevations);
                    
                    statsHTML += `<strong>Elevation range:</strong> ${minElevation.toFixed(0)}m - ${maxElevation.toFixed(0)}m<br>`;
                    statsHTML += `<strong>Average elevation:</strong> ${avgElevation.toFixed(0)}m`;
                }
            }
            
            fileStats.innerHTML = statsHTML;
            fileInfo.style.display = 'block';
            
            // Update POI table
            const tableBody = document.getElementById('poiTableBody');
            
            if (pois.length === 0) {
                tableBody.innerHTML = '<tr><td colspan="5" class="no-data">No POIs found in this GPX file</td></tr>';
                return;
            }
            
            tableBody.innerHTML = '';
            pois.forEach(poi => {
                const row = document.createElement('tr');
                
                const elevationText = poi.elevation !== null ? `${poi.elevation.toFixed(0)}m` : 'N/A';
                const description = poi.description.length > 50 ? 
                    poi.description.substring(0, 47) + '...' : poi.description;
                
                row.innerHTML = `
                    <td><strong>${escapeHtml(poi.name)}</strong></td>
                    <td>${poi.lat.toFixed(6)}</td>
                    <td>${poi.lon.toFixed(6)}</td>
                    <td>${elevationText}</td>
                    <td>${escapeHtml(description)}</td>
                `;
                
                tableBody.appendChild(row);
            });
        }
        
        function showError(message) {
            const errorContainer = document.getElementById('errorContainer');
            errorContainer.innerHTML = `<div class="error">${escapeHtml(message)}</div>`;
        }
        
        function clearError() {
            const errorContainer = document.getElementById('errorContainer');
            errorContainer.innerHTML = '';
        }
        
        function showLoading(show) {
            const loadingContainer = document.getElementById('loadingContainer');
            loadingContainer.style.display = show ? 'block' : 'none';
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
    </script>
</body>
</html>
        """
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html_content.encode())
    
    def handle_load_gpx(self, query_string):
        """Handle GPX file loading"""
        # This is a placeholder - the actual file loading is done client-side
        # in the JavaScript for security reasons
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {'status': 'success', 'message': 'File loaded client-side'}
        self.wfile.write(json.dumps(response).encode())
    
    def handle_list_files(self):
        """List available GPX files"""
        try:
            gpx_dir = Path(__file__).parent.parent / 'gpx'
            if gpx_dir.exists():
                gpx_files = list(gpx_dir.glob('*.gpx'))
                files = [{'name': f.name, 'path': str(f)} for f in gpx_files]
            else:
                files = []
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(files).encode())
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'application/json') 
            self.end_headers()
            error_response = {'error': str(e)}
            self.wfile.write(json.dumps(error_response).encode())


def start_server(port=8000):
    """Start the web server"""
    handler = GPXHandler
    
    with socketserver.TCPServer(("", port), handler) as httpd:
        print(f"🌐 GPX POI Web Viewer")
        print(f"📡 Server running at http://localhost:{port}")
        print(f"🚀 Opening in browser...")
        
        # Open browser in a separate thread
        def open_browser():
            time.sleep(1)  # Give server time to start
            webbrowser.open(f'http://localhost:{port}')
        
        threading.Thread(target=open_browser, daemon=True).start()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Server stopped")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='GPX POI Web Viewer')
    parser.add_argument('--port', type=int, default=8000, 
                       help='Port to run the web server on (default: 8000)')
    
    args = parser.parse_args()
    
    try:
        start_server(args.port)
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"❌ Port {args.port} is already in use")
            print(f"💡 Try a different port: python web_viewer.py --port 8001")
        else:
            print(f"❌ Error starting server: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")