#!/usr/bin/env python3
"""
GPX POI Tool - macOS GUI
A simple graphical interface for viewing and managing GPX files with POIs.
"""

import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

import customtkinter as ctk

# Add the parent directory to path to import our poi modules
sys.path.append(str(Path(__file__).parent.parent))

try:
    from poi_formats import GPXFileHandler
except ImportError as e:
    print(f"Import Error: {e}")
    print("Could not import poi modules. "
          "Make sure you're running from the correct directory.")
    sys.exit(1)


class GPXViewerApp:
    def __init__(self):
        # Configure customtkinter theme
        ctk.set_appearance_mode("system")  # Follow system dark/light mode
        ctk.set_default_color_theme("blue")  # Use blue theme

        # Create main window
        self.root = ctk.CTk()
        self.root.title("GPX POI Viewer")
        self.root.geometry("1000x700")

        # Store current GPX data
        self.current_file_path = None
        self.current_pois = []

        # Initialize GPX handler
        self.gpx_handler = GPXFileHandler()

        self.setup_ui()

    def setup_ui(self):
        """Create the user interface"""

        # Main container with padding
        main_frame = ctk.CTkFrame(self.root)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # Title
        title_label = ctk.CTkLabel(
            main_frame,
            text="GPX POI Viewer",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        title_label.pack(pady=(0, 20))

        # File selection frame
        file_frame = ctk.CTkFrame(main_frame)
        file_frame.pack(fill="x", pady=(0, 20))

        # File selection button
        self.open_button = ctk.CTkButton(
            file_frame,
            text="📁 Open GPX File",
            command=self.open_gpx_file,
            font=ctk.CTkFont(size=16),
            height=40
        )
        self.open_button.pack(side="left", padx=20, pady=20)

        # Current file label
        self.file_label = ctk.CTkLabel(
            file_frame,
            text="No file selected",
            font=ctk.CTkFont(size=14)
        )
        self.file_label.pack(side="left", padx=20, pady=20)

        # Info frame for file statistics
        self.info_frame = ctk.CTkFrame(main_frame)
        self.info_frame.pack(fill="x", pady=(0, 20))

        # Statistics labels
        self.stats_label = ctk.CTkLabel(
            self.info_frame,
            text="File Statistics: No file loaded",
            font=ctk.CTkFont(size=14, weight="bold")
        )
        self.stats_label.pack(pady=10)

        # POI Table frame
        table_frame = ctk.CTkFrame(main_frame)
        table_frame.pack(fill="both", expand=True)

        # Table title
        table_title = ctk.CTkLabel(
            table_frame,
            text="Points of Interest",
            font=ctk.CTkFont(size=18, weight="bold")
        )
        table_title.pack(pady=(10, 0))

        # Create treeview for POI display
        self.setup_poi_table(table_frame)

    def setup_poi_table(self, parent):
        """Create the POI table using tkinter Treeview"""

        # Create frame for treeview and scrollbars
        tree_frame = tk.Frame(parent, bg=parent.cget("fg_color")[1])
        tree_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # Define columns
        columns = ("name", "lat", "lon", "elevation", "description")

        # Create treeview
        self.poi_tree = ttk.Treeview(tree_frame, columns=columns, show="headings", height=15)

        # Configure column headings and widths
        self.poi_tree.heading("name", text="Name")
        self.poi_tree.heading("lat", text="Latitude")
        self.poi_tree.heading("lon", text="Longitude")
        self.poi_tree.heading("elevation", text="Elevation")
        self.poi_tree.heading("description", text="Description")

        self.poi_tree.column("name", width=200, minwidth=150)
        self.poi_tree.column("lat", width=120, minwidth=100)
        self.poi_tree.column("lon", width=120, minwidth=100)
        self.poi_tree.column("elevation", width=80, minwidth=60)
        self.poi_tree.column("description", width=300, minwidth=200)

        # Create scrollbars
        v_scrollbar = ttk.Scrollbar(tree_frame, orient="vertical",
                                    command=self.poi_tree.yview)
        h_scrollbar = ttk.Scrollbar(tree_frame, orient="horizontal",
                                    command=self.poi_tree.xview)

        self.poi_tree.configure(yscrollcommand=v_scrollbar.set,
                                xscrollcommand=h_scrollbar.set)

        # Pack treeview and scrollbars
        self.poi_tree.grid(row=0, column=0, sticky="nsew")
        v_scrollbar.grid(row=0, column=1, sticky="ns")
        h_scrollbar.grid(row=1, column=0, sticky="ew")

        # Configure grid weights
        tree_frame.grid_rowconfigure(0, weight=1)
        tree_frame.grid_columnconfigure(0, weight=1)

    def open_gpx_file(self):
        """Open and load a GPX file"""

        file_path = filedialog.askopenfilename(
            title="Select GPX File",
            filetypes=[
                ("GPX files", "*.gpx"),
                ("All files", "*.*")
            ],
            initialdir=str(Path.home())
        )

        if not file_path:
            return

        try:
            # Load GPX file using our existing module
            self.current_pois = self.gpx_handler.read_gpx_file(Path(file_path))
            self.current_file_path = file_path

            # Update UI
            self.update_file_info(file_path)
            self.update_poi_table()

            print(f"Loaded GPX file: {file_path}")
            print(f"Found {len(self.current_pois)} POIs")

        except Exception as e:
            messagebox.showerror(
                "Error Loading File",
                f"Failed to load GPX file:\n\n{str(e)}"
            )
            print(f"Error loading GPX file: {e}")

    def update_file_info(self, file_path):
        """Update the file information display"""

        file_name = Path(file_path).name
        self.file_label.configure(text=f"📄 {file_name}")

        # Create statistics text
        num_pois = len(self.current_pois)

        # Calculate basic statistics
        if num_pois > 0:
            elevations = [poi.ele for poi in self.current_pois
                          if poi.ele is not None and poi.ele > 0]

            stats_text = f"📊 {num_pois} POIs"

            if elevations:
                avg_elevation = sum(elevations) / len(elevations)
                min_elevation = min(elevations)
                max_elevation = max(elevations)
                stats_text += f" • Elevations: {len(elevations)} valid • "
                range_text = f"{min_elevation:.0f}m - {max_elevation:.0f}m"
                stats_text += f"Range: {range_text} • "
                stats_text += f"Average: {avg_elevation:.0f}m"
            else:
                stats_text += " • No elevation data available"
        else:
            stats_text = "📊 No POIs found in file"

        self.stats_label.configure(text=stats_text)

    def update_poi_table(self):
        """Update the POI table with current data"""

        # Clear existing items
        for item in self.poi_tree.get_children():
            self.poi_tree.delete(item)

        if not self.current_pois:
            return

        # Add POIs to table
        for i, poi in enumerate(self.current_pois):

            # Format data for display
            name = poi.name or f"POI {i+1}"
            lat = f"{poi.lat:.6f}" if poi.lat else "N/A"
            lon = f"{poi.lon:.6f}" if poi.lon else "N/A"

            if poi.ele is not None and poi.ele > 0:
                elevation = f"{poi.ele:.0f}m"
            else:
                elevation = "N/A"

            description = poi.desc or ""
            if len(description) > 50:
                description = description[:47] + "..."

            # Insert row into table
            self.poi_tree.insert(
                "",
                "end",
                values=(name, lat, lon, elevation, description)
            )

    def run(self):
        """Start the GUI application"""
        self.root.mainloop()


def main():
    """Main entry point"""
    try:
        app = GPXViewerApp()
        app.run()
    except KeyboardInterrupt:
        print("\nApplication interrupted by user")
    except Exception as e:
        print(f"Unexpected error: {e}")
        error_msg = f"Unexpected error occurred:\n\n{str(e)}"
        messagebox.showerror("Application Error", error_msg)


if __name__ == "__main__":
    main()
