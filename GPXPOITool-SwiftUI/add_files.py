#!/usr/bin/env python3
import re
import sys


def add_files_to_pbxproj(pbxproj_path):
    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Find the highest ID
    ids = re.findall(r'A1000(\d+)000000000001', content)
    max_id = max(int(id) for id in ids)

    elevation_build_id = f"A1{max_id+1:06d}000000000001"
    elevation_file_id = f"A1{max_id+2:06d}000000000001"
    kml_build_id = f"A1{max_id+3:06d}000000000001"
    kml_file_id = f"A1{max_id+4:06d}000000000001"

    # Add to PBXBuildFile section
    build_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?)(/\* End PBXBuildFile section \*/)', content, re.DOTALL)
    if build_section:
        new_build_entries = f"""		{elevation_build_id} /* ElevationService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {elevation_file_id} /* ElevationService.swift */; }};
		{kml_build_id} /* KMLExporter.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {kml_file_id} /* KMLExporter.swift */; }};
/* End PBXBuildFile section */"""
        content = content.replace(build_section.group(2), new_build_entries)

    # Add to PBXFileReference section
    file_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?)(/\* End PBXFileReference section \*/)', content, re.DOTALL)
    if file_section:
        new_file_entries = f"""		{elevation_file_id} /* ElevationService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ElevationService.swift; sourceTree = "<group>"; }};
		{kml_file_id} /* KMLExporter.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KMLExporter.swift; sourceTree = "<group>"; }};
/* End PBXFileReference section */"""
        content = content.replace(file_section.group(2), new_file_entries)

    # Add to Services group
    services_section = re.search(r'(A1000022000000000001 /\* Services \*/ = \{[^}]*children = \([^)]*)(A1000008000000000001 /\* GPXProcessor\.swift \*/,)([^)]*\);)', content, re.DOTALL)
    if services_section:
        new_services = f"""{services_section.group(1)}{services_section.group(2)}
				{elevation_file_id} /* ElevationService.swift */,
				{kml_file_id} /* KMLExporter.swift */,{services_section.group(3)}"""
        content = re.sub(r'A1000022000000000001 /\* Services \*/ = \{[^}]*children = \([^}]*\};', new_services, content, flags=re.DOTALL)

    # Add to Sources build phase
    sources_section = re.search(r'(A1000025000000000001 /\* Sources \*/ = \{[^}]*files = \([^}]*)(A1000001000000000001 /\* GPXPOIToolApp\.swift in Sources \*/,)([^}]*\);)', content, re.DOTALL)
    if sources_section:
        new_sources = f"""{sources_section.group(1)}{sources_section.group(2)}
				{elevation_build_id} /* ElevationService.swift in Sources */,
				{kml_build_id} /* KMLExporter.swift in Sources */,{sources_section.group(3)}"""
        content = re.sub(r'A1000025000000000001 /\* Sources \*/ = \{[^}]*files = \([^}]*\};', new_sources, content, flags=re.DOTALL)

    with open(pbxproj_path, 'w') as f:
        f.write(content)

    print(f"Added files with IDs: {elevation_file_id}, {kml_file_id}")

if __name__ == "__main__":
    add_files_to_pbxproj("GPXPOITool.xcodeproj/project.pbxproj")
