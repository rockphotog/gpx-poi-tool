#!/bin/bash

# Simple Xcode Project Recovery
# Creates a minimal working project that Xcode can open

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="/Users/espen/git/gpx-poi-tool/GPXPOITool-SwiftUI"
cd "$PROJECT_ROOT"

echo -e "${BLUE}[INFO]${NC} Creating simple working Xcode project..."

# Backup existing project
if [ -d "GPXPOITool.xcodeproj" ]; then
    mv GPXPOITool.xcodeproj "GPXPOITool_backup_$(date +%Y%m%d_%H%M%S).xcodeproj"
    echo -e "${GREEN}[SUCCESS]${NC} Existing project backed up"
fi

# Create basic project structure
mkdir -p GPXPOITool.xcodeproj/project.xcworkspace/xcshareddata

# Create workspace contents
cat > GPXPOITool.xcodeproj/project.xcworkspace/contents.xcworkspacedata << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
EOF

# Create a minimal project.pbxproj with only the essential files
# This is based on the original working project structure
cat > GPXPOITool.xcodeproj/project.pbxproj << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		A1000001000000000001 /* GPXPOIToolApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1000002000000000001 /* GPXPOIToolApp.swift */; };
		A1000003000000000001 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1000004000000000001 /* ContentView.swift */; };
		A1000005000000000001 /* POI.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1000006000000000001 /* POI.swift */; };
		A1000007000000000001 /* GPXProcessor.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1000008000000000001 /* GPXProcessor.swift */; };
		A1000009000000000001 /* MapView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1000010000000000001 /* MapView.swift */; };
		A1000011000000000001 /* POIListView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1000012000000000001 /* POIListView.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		A1000002000000000001 /* GPXPOIToolApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GPXPOIToolApp.swift; sourceTree = "<group>"; };
		A1000004000000000001 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		A1000006000000000001 /* POI.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = POI.swift; sourceTree = "<group>"; };
		A1000008000000000001 /* GPXProcessor.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GPXProcessor.swift; sourceTree = "<group>"; };
		A1000010000000000001 /* MapView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MapView.swift; sourceTree = "<group>"; };
		A1000012000000000001 /* POIListView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = POIListView.swift; sourceTree = "<group>"; };
		A1000013000000000001 /* GPX POI Tool.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "GPX POI Tool.app"; sourceTree = BUILT_PRODUCTS_DIR; };
		A1000014000000000001 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		A1000015000000000001 /* GPX_POI_Tool.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = GPX_POI_Tool.entitlements; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		A1000016000000000001 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A1000017000000000001 = {
			isa = PBXGroup;
			children = (
				A1000018000000000001 /* GPX POI Tool */,
				A1000019000000000001 /* Products */,
			);
			sourceTree = "<group>";
		};
		A1000018000000000001 /* GPX POI Tool */ = {
			isa = PBXGroup;
			children = (
				A1000002000000000001 /* GPXPOIToolApp.swift */,
				A1000004000000000001 /* ContentView.swift */,
				A1000020000000000001 /* Models */,
				A1000021000000000001 /* Views */,
				A1000022000000000001 /* Services */,
				A1000015000000000001 /* GPX_POI_Tool.entitlements */,
				A1000014000000000001 /* Info.plist */,
			);
			path = "GPX POI Tool";
			sourceTree = "<group>";
		};
		A1000019000000000001 /* Products */ = {
			isa = PBXGroup;
			children = (
				A1000013000000000001 /* GPX POI Tool.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		A1000020000000000001 /* Models */ = {
			isa = PBXGroup;
			children = (
				A1000006000000000001 /* POI.swift */,
			);
			path = Models;
			sourceTree = "<group>";
		};
		A1000021000000000001 /* Views */ = {
			isa = PBXGroup;
			children = (
				A1000010000000000001 /* MapView.swift */,
				A1000012000000000001 /* POIListView.swift */,
			);
			path = Views;
			sourceTree = "<group>";
		};
		A1000022000000000001 /* Services */ = {
			isa = PBXGroup;
			children = (
				A1000008000000000001 /* GPXProcessor.swift */,
			);
			path = Services;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A1000023000000000001 /* GPX POI Tool */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A1000024000000000001 /* Build configuration list for PBXNativeTarget "GPX POI Tool" */;
			buildPhases = (
				A1000025000000000001 /* Sources */,
				A1000016000000000001 /* Frameworks */,
				A1000026000000000001 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = "GPX POI Tool";
			productName = "GPX POI Tool";
			productReference = A1000013000000000001 /* GPX POI Tool.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		A1000027000000000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 2600;
				TargetAttributes = {
					A1000023000000000001 = {
						CreatedOnToolsVersion = 15.0;
					};
				};
			};
			buildConfigurationList = A1000028000000000001 /* Build configuration list for PBXProject "GPXPOITool" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = A1000017000000000001;
			productRefGroup = A1000019000000000001 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				A1000023000000000001 /* GPX POI Tool */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		A1000026000000000001 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		A1000025000000000001 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1000003000000000001 /* ContentView.swift in Sources */,
				A1000005000000000001 /* POI.swift in Sources */,
				A1000007000000000001 /* GPXProcessor.swift in Sources */,
				A1000009000000000001 /* MapView.swift in Sources */,
				A1000011000000000001 /* POIListView.swift in Sources */,
				A1000001000000000001 /* GPXPOIToolApp.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		A1000029000000000001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEAD_CODE_STRIPPING = YES;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		A1000030000000000001 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEAD_CODE_STRIPPING = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};
		A1000031000000000001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "GPX POI Tool/GPX_POI_Tool.entitlements";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEAD_CODE_STRIPPING = YES;
				DEVELOPMENT_TEAM = "";
				ENABLE_APP_SANDBOX = YES;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
				ENABLE_PREVIEWS = YES;
				ENABLE_USER_SELECTED_FILES = readwrite;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = "GPX POI Tool/Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = "GPX POI Tool";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.yourname.gpx-poi-tool";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		A1000032000000000001 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "GPX POI Tool/GPX_POI Tool.entitlements";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEAD_CODE_STRIPPING = YES;
				DEVELOPMENT_TEAM = "";
				ENABLE_APP_SANDBOX = YES;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
				ENABLE_PREVIEWS = YES;
				ENABLE_USER_SELECTED_FILES = readwrite;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = "GPX POI Tool/Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = "GPX POI Tool";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.yourname.gpx-poi-tool";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A1000024000000000001 /* Build configuration list for PBXNativeTarget "GPX POI Tool" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A1000031000000000001 /* Debug */,
				A1000032000000000001 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		A1000028000000000001 /* Build configuration list for PBXProject "GPXPOITool" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A1000029000000000001 /* Debug */,
				A1000030000000000001 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = A1000027000000000001 /* Project object */;
}
EOF

echo -e "${GREEN}[SUCCESS]${NC} Minimal working Xcode project created"
echo -e "${BLUE}[INFO]${NC} Project includes the core files but NOT ElevationService.swift or KMLExporter.swift"
echo -e "${BLUE}[INFO]${NC} Next steps:"
echo "  1. Open GPXPOITool.xcodeproj in Xcode"
echo "  2. Right-click on Services group -> Add Files to \"GPX POI Tool\""
echo "  3. Add ElevationService.swift and KMLExporter.swift"
echo "  4. Build the project (Cmd+B)"

# Validate the created project
if plutil -lint GPXPOITool.xcodeproj/project.pbxproj > /dev/null 2>&1; then
    echo -e "${GREEN}[SUCCESS]${NC} Project file syntax is valid"
else
    echo -e "${RED}[ERROR]${NC} Project file syntax is invalid"
    exit 1
fi
