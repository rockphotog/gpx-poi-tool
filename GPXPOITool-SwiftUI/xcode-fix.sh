#!/bin/bash

# Xcode Project Recovery Tool
# Fixes the damaged project by creating a clean, working version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_ROOT="/Users/espen/git/gpx-poi-tool/GPXPOITool-SwiftUI"
cd "$PROJECT_ROOT"

show_usage() {
    echo "Xcode Project Recovery Tool"
    echo "=========================="
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  fix-uuids    Fix UUID conflicts in project.pbxproj (recommended)"
    echo "  clean-reset  Reset project to clean state"
    echo "  backup       Create backup of current project"
    echo "  validate     Check project file health"
    echo "  new-project  Create entirely new Xcode project structure"
    echo "  help         Show this help"
    echo ""
    echo "Recommended workflow:"
    echo "  1. $0 backup"
    echo "  2. $0 fix-uuids"
    echo "  3. Open in Xcode and manually add missing files"
}

# Function to generate unique UUID for Xcode
generate_xcode_uuid() {
    # Generate a unique 24-character hex string in Xcode format
    printf "A%023d" $((RANDOM * RANDOM + $(date +%s)))
}

backup_project() {
    print_status "Creating project backup..."
    backup_name="GPXPOITool_backup_$(date +%Y%m%d_%H%M%S).xcodeproj"
    cp -r GPXPOITool.xcodeproj "$backup_name"
    print_success "Backup created: $backup_name"
}

validate_project() {
    print_status "Validating project file..."

    # Check basic syntax
    if plutil -lint GPXPOITool.xcodeproj/project.pbxproj > /dev/null 2>&1; then
        print_success "Project file syntax is valid"
    else
        print_error "Project file syntax is invalid"
        return 1
    fi

    # Check for UUID duplicates
    print_status "Checking for UUID conflicts..."
    duplicates=$(grep -o 'A[0-9]\{23\}' GPXPOITool.xcodeproj/project.pbxproj | sort | uniq -d)

    if [ -z "$duplicates" ]; then
        print_success "No UUID conflicts found"
        return 0
    else
        print_error "UUID conflicts detected:"
        echo "$duplicates"
        return 1
    fi
}

clean_reset() {
    print_status "Resetting project to clean state..."

    # Remove user data that might be cached
    rm -rf GPXPOITool.xcodeproj/xcuserdata
    rm -rf GPXPOITool.xcodeproj/project.xcworkspace/xcuserdata

    # Restore original project file
    git checkout -- GPXPOITool.xcodeproj/project.pbxproj

    print_success "Project reset to clean state"
}

fix_uuids() {
    print_status "Fixing UUID conflicts in project.pbxproj..."

    # First, validate current state
    if ! validate_project; then
        print_warning "Project has issues, attempting to fix..."
    fi

    # Read the current project file
    local project_file="GPXPOITool.xcodeproj/project.pbxproj"
    local temp_file=$(mktemp)

    # Generate new unique UUIDs for the new files
    local elevation_build_uuid=$(generate_xcode_uuid)
    local elevation_file_uuid=$(generate_xcode_uuid)
    local kml_build_uuid=$(generate_xcode_uuid)
    local kml_file_uuid=$(generate_xcode_uuid)

    print_status "Generated new UUIDs:"
    echo "  ElevationService build: $elevation_build_uuid"
    echo "  ElevationService file:  $elevation_file_uuid"
    echo "  KMLExporter build:      $kml_build_uuid"
    echo "  KMLExporter file:       $kml_file_uuid"

    # Add the new files to the project with safe UUIDs
    cp "$project_file" "$temp_file"

    # Add PBXBuildFile entries
    sed "/A1000011000000000001.*POIListView.swift in Sources/a\\
		$elevation_build_uuid /* ElevationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = $elevation_file_uuid /* ElevationService.swift */; };\\
		$kml_build_uuid /* KMLExporter.swift in Sources */ = {isa = PBXBuildFile; fileRef = $kml_file_uuid /* KMLExporter.swift */; };" "$temp_file" > "${temp_file}.1"

    # Add PBXFileReference entries
    sed "/A1000015000000000001.*GPX_POI_Tool.entitlements/a\\
		$elevation_file_uuid /* ElevationService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ElevationService.swift; sourceTree = \"<group>\"; };\\
		$kml_file_uuid /* KMLExporter.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KMLExporter.swift; sourceTree = \"<group>\"; };" "${temp_file}.1" > "${temp_file}.2"

    # Add to Services group
    sed "/A1000008000000000001.*GPXProcessor.swift/a\\
				$elevation_file_uuid /* ElevationService.swift */,\\
				$kml_file_uuid /* KMLExporter.swift */," "${temp_file}.2" > "${temp_file}.3"

    # Add to Sources build phase
    sed "/A1000001000000000001.*GPXPOIToolApp.swift in Sources/a\\
				$elevation_build_uuid /* ElevationService.swift in Sources */,\\
				$kml_build_uuid /* KMLExporter.swift in Sources */," "${temp_file}.3" > "${temp_file}.final"

    # Validate the result
    if plutil -lint "${temp_file}.final" > /dev/null 2>&1; then
        cp "${temp_file}.final" "$project_file"
        print_success "Project file updated with new files"

        # Final validation
        if validate_project; then
            print_success "Project is now healthy and ready for Xcode"
            print_status "Next steps:"
            echo "  1. Open GPXPOITool.xcodeproj in Xcode"
            echo "  2. Verify ElevationService.swift and KMLExporter.swift appear in Services group"
            echo "  3. Build the project (Cmd+B)"
        else
            print_error "Project still has issues after fix attempt"
        fi
    else
        print_error "Generated project file is invalid, restoring original"
        git checkout -- GPXPOITool.xcodeproj/project.pbxproj
    fi

    # Clean up temp files
    rm -f "${temp_file}"*
}

create_new_project() {
    print_status "Creating new Xcode project structure..."

    backup_name="GPXPOITool_old_$(date +%Y%m%d_%H%M%S).xcodeproj"
    mv GPXPOITool.xcodeproj "$backup_name"
    print_status "Old project backed up as: $backup_name"

    # Create basic project structure
    mkdir -p GPXPOITool.xcodeproj/project.xcworkspace/xcshareddata

    # Generate fresh UUIDs for all components
    local main_group_uuid=$(generate_xcode_uuid)
    local app_group_uuid=$(generate_xcode_uuid)
    local products_group_uuid=$(generate_xcode_uuid)
    local models_group_uuid=$(generate_xcode_uuid)
    local views_group_uuid=$(generate_xcode_uuid)
    local services_group_uuid=$(generate_xcode_uuid)

    # Generate file UUIDs
    local app_file_uuid=$(generate_xcode_uuid)
    local content_file_uuid=$(generate_xcode_uuid)
    local poi_file_uuid=$(generate_xcode_uuid)
    local gpx_file_uuid=$(generate_xcode_uuid)
    local elevation_file_uuid=$(generate_xcode_uuid)
    local kml_file_uuid=$(generate_xcode_uuid)
    local map_file_uuid=$(generate_xcode_uuid)
    local list_file_uuid=$(generate_xcode_uuid)

    # Generate build file UUIDs
    local app_build_uuid=$(generate_xcode_uuid)
    local content_build_uuid=$(generate_xcode_uuid)
    local poi_build_uuid=$(generate_xcode_uuid)
    local gpx_build_uuid=$(generate_xcode_uuid)
    local elevation_build_uuid=$(generate_xcode_uuid)
    local kml_build_uuid=$(generate_xcode_uuid)
    local map_build_uuid=$(generate_xcode_uuid)
    local list_build_uuid=$(generate_xcode_uuid)

    # Other UUIDs
    local app_product_uuid=$(generate_xcode_uuid)
    local info_plist_uuid=$(generate_xcode_uuid)
    local entitlements_uuid=$(generate_xcode_uuid)
    local frameworks_uuid=$(generate_xcode_uuid)
    local target_uuid=$(generate_xcode_uuid)
    local sources_uuid=$(generate_xcode_uuid)
    local resources_uuid=$(generate_xcode_uuid)
    local project_uuid=$(generate_xcode_uuid)
    local target_config_uuid=$(generate_xcode_uuid)
    local project_config_uuid=$(generate_xcode_uuid)
    local debug_config_uuid=$(generate_xcode_uuid)
    local release_config_uuid=$(generate_xcode_uuid)
    local debug_target_uuid=$(generate_xcode_uuid)
    local release_target_uuid=$(generate_xcode_uuid)

    # Create the new project.pbxproj with all files included
    cat > GPXPOITool.xcodeproj/project.pbxproj << EOF
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		$app_build_uuid /* GPXPOIToolApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = $app_file_uuid /* GPXPOIToolApp.swift */; };
		$content_build_uuid /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $content_file_uuid /* ContentView.swift */; };
		$poi_build_uuid /* POI.swift in Sources */ = {isa = PBXBuildFile; fileRef = $poi_file_uuid /* POI.swift */; };
		$gpx_build_uuid /* GPXProcessor.swift in Sources */ = {isa = PBXBuildFile; fileRef = $gpx_file_uuid /* GPXProcessor.swift */; };
		$elevation_build_uuid /* ElevationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = $elevation_file_uuid /* ElevationService.swift */; };
		$kml_build_uuid /* KMLExporter.swift in Sources */ = {isa = PBXBuildFile; fileRef = $kml_file_uuid /* KMLExporter.swift */; };
		$map_build_uuid /* MapView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $map_file_uuid /* MapView.swift */; };
		$list_build_uuid /* POIListView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $list_file_uuid /* POIListView.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		$app_file_uuid /* GPXPOIToolApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GPXPOIToolApp.swift; sourceTree = "<group>"; };
		$content_file_uuid /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		$poi_file_uuid /* POI.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = POI.swift; sourceTree = "<group>"; };
		$gpx_file_uuid /* GPXProcessor.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GPXProcessor.swift; sourceTree = "<group>"; };
		$elevation_file_uuid /* ElevationService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ElevationService.swift; sourceTree = "<group>"; };
		$kml_file_uuid /* KMLExporter.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KMLExporter.swift; sourceTree = "<group>"; };
		$map_file_uuid /* MapView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MapView.swift; sourceTree = "<group>"; };
		$list_file_uuid /* POIListView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = POIListView.swift; sourceTree = "<group>"; };
		$app_product_uuid /* GPX POI Tool.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "GPX POI Tool.app"; sourceTree = BUILT_PRODUCTS_DIR; };
		$info_plist_uuid /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		$entitlements_uuid /* GPX_POI_Tool.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = GPX_POI_Tool.entitlements; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		$frameworks_uuid /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		$main_group_uuid = {
			isa = PBXGroup;
			children = (
				$app_group_uuid /* GPX POI Tool */,
				$products_group_uuid /* Products */,
			);
			sourceTree = "<group>";
		};
		$app_group_uuid /* GPX POI Tool */ = {
			isa = PBXGroup;
			children = (
				$app_file_uuid /* GPXPOIToolApp.swift */,
				$content_file_uuid /* ContentView.swift */,
				$models_group_uuid /* Models */,
				$views_group_uuid /* Views */,
				$services_group_uuid /* Services */,
				$entitlements_uuid /* GPX_POI_Tool.entitlements */,
				$info_plist_uuid /* Info.plist */,
			);
			path = "GPX POI Tool";
			sourceTree = "<group>";
		};
		$products_group_uuid /* Products */ = {
			isa = PBXGroup;
			children = (
				$app_product_uuid /* GPX POI Tool.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		$models_group_uuid /* Models */ = {
			isa = PBXGroup;
			children = (
				$poi_file_uuid /* POI.swift */,
			);
			path = Models;
			sourceTree = "<group>";
		};
		$views_group_uuid /* Views */ = {
			isa = PBXGroup;
			children = (
				$map_file_uuid /* MapView.swift */,
				$list_file_uuid /* POIListView.swift */,
			);
			path = Views;
			sourceTree = "<group>";
		};
		$services_group_uuid /* Services */ = {
			isa = PBXGroup;
			children = (
				$gpx_file_uuid /* GPXProcessor.swift */,
				$elevation_file_uuid /* ElevationService.swift */,
				$kml_file_uuid /* KMLExporter.swift */,
			);
			path = Services;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		$target_uuid /* GPX POI Tool */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = $target_config_uuid /* Build configuration list for PBXNativeTarget "GPX POI Tool" */;
			buildPhases = (
				$sources_uuid /* Sources */,
				$frameworks_uuid /* Frameworks */,
				$resources_uuid /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = "GPX POI Tool";
			productName = "GPX POI Tool";
			productReference = $app_product_uuid /* GPX POI Tool.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		$project_uuid /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 2600;
				TargetAttributes = {
					$target_uuid = {
						CreatedOnToolsVersion = 15.0;
					};
				};
			};
			buildConfigurationList = $project_config_uuid /* Build configuration list for PBXProject "GPXPOITool" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = $main_group_uuid;
			productRefGroup = $products_group_uuid /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				$target_uuid /* GPX POI Tool */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		$resources_uuid /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		$sources_uuid /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				$content_build_uuid /* ContentView.swift in Sources */,
				$poi_build_uuid /* POI.swift in Sources */,
				$gpx_build_uuid /* GPXProcessor.swift in Sources */,
				$elevation_build_uuid /* ElevationService.swift in Sources */,
				$kml_build_uuid /* KMLExporter.swift in Sources */,
				$map_build_uuid /* MapView.swift in Sources */,
				$list_build_uuid /* POIListView.swift in Sources */,
				$app_build_uuid /* GPXPOIToolApp.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		$debug_config_uuid /* Debug */ = {
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
					"$$(inherited)",
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
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $$(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		$release_config_uuid /* Release */ = {
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
		$debug_target_uuid /* Debug */ = {
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
					"$$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.yourname.gpx-poi-tool";
				PRODUCT_NAME = "$$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		$release_target_uuid /* Release */ = {
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
					"$$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.yourname.gpx-poi-tool";
				PRODUCT_NAME = "$$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		$target_config_uuid /* Build configuration list for PBXNativeTarget "GPX POI Tool" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$debug_target_uuid /* Debug */,
				$release_target_uuid /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		$project_config_uuid /* Build configuration list for PBXProject "GPXPOITool" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$debug_config_uuid /* Debug */,
				$release_config_uuid /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = $project_uuid /* Project object */;
}
EOF

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

    print_success "New Xcode project created with all files included"
    print_status "All Swift files are now properly referenced in the project"
    print_status "You can now open GPXPOITool.xcodeproj in Xcode"
}

# Main script logic
case "${1:-help}" in
    "backup")
        backup_project
        ;;
    "validate")
        validate_project
        ;;
    "clean-reset")
        clean_reset
        ;;
    "fix-uuids")
        fix_uuids
        ;;
    "new-project")
        create_new_project
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
