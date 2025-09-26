#!/usr/bin/env python3
"""
GPX POI Tool - Smart Launcher
Automatically chooses the best available interface for viewing GPX files.
"""

import subprocess
import sys
from pathlib import Path


def check_tkinter_available():
    """Check if tkinter is available"""
    try:
        import tkinter  # noqa: F401
        return True
    except ImportError:
        return False


def run_native_gui():
    """Run the native customtkinter GUI"""
    try:
        from main import main
        print("🖥️  Starting Native Desktop GUI...")
        main()
        return True
    except ImportError as e:
        print(f"❌ Native GUI not available: {e}")
        return False
    except Exception as e:
        print(f"❌ Error running native GUI: {e}")
        return False


def run_web_viewer():
    """Run the web-based viewer"""
    try:
        from web_viewer import start_server
        print("🌐 Starting Web-based Viewer...")
        print("   (Will open automatically in your browser)")
        start_server()
        return True
    except ImportError as e:
        print(f"❌ Web viewer not available: {e}")
        return False
    except Exception as e:
        print(f"❌ Error running web viewer: {e}")
        return False


def install_requirements():
    """Install requirements if needed"""
    try:
        # Check if we're in a virtual environment or can install packages
        requirements_file = Path(__file__).parent / "requirements.txt"

        if requirements_file.exists():
            print("📦 Installing requirements...")
            cmd = [sys.executable, "-m", "pip", "install", "-r",
                   str(requirements_file)]
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                print("✅ Requirements installed successfully")
                return True
            else:
                print(f"❌ Failed to install requirements: {result.stderr}")
                return False
        else:
            print("⚠️  No requirements.txt found")
            return True

    except Exception as e:
        print(f"❌ Error installing requirements: {e}")
        return False


def main():
    """Main launcher logic"""
    print("🚀 GPX POI Tool Launcher")
    print("=" * 40)

    # Check Python version
    if sys.version_info < (3, 7):
        print("❌ Python 3.7 or higher required")
        sys.exit(1)

    # Try native GUI first if tkinter is available
    if check_tkinter_available():
        print("✅ tkinter available - trying native GUI...")

        # Try to install requirements first
        install_requirements()

        # Try native GUI
        if run_native_gui():
            return

        print("\n⚠️  Native GUI failed, falling back to web viewer...")
    else:
        print("⚠️  tkinter not available - using web viewer...")
        print("💡 To use native GUI, install Python with tkinter support:")
        print("   brew install python-tk")

    # Fall back to web viewer
    print("\n" + "=" * 40)
    if run_web_viewer():
        return

    # If everything failed
    print("\n❌ All interfaces failed!")
    print("\n🛠️  Troubleshooting:")
    print("   1. Make sure you're in the gui-macos directory")
    print("   2. Install tkinter: brew install python-tk")
    print("   3. Try running manually: python3 web_viewer.py")
    print("   4. Check the README.md for detailed instructions")
    sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        print("🛠️  Try running manually: python3 web_viewer.py")
        sys.exit(1)
