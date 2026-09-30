#!/usr/bin/env python3
"""Generate the native app targets using only Python's standard library.

Lilim is the direct-distribution target; Lilim-AppStore is the sandbox feasibility
target. Regenerate after adding Swift source files. No account or signing data is
stored in this project.
"""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Lilim.xcodeproj"
objects = {}


def identifier(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def add(object_name, isa, **fields):
    key = identifier(object_name)
    objects[key] = {"isa": isa, **fields}
    return key


def serialize(value, indent=0):
    padding = "\t" * indent
    if isinstance(value, dict):
        body = "\n".join(f"{padding}\t{json.dumps(k)} = {serialize(v, indent + 1)};" for k, v in value.items())
        return "{\n" + body + "\n" + padding + "}"
    if isinstance(value, list):
        return "(\n" + "\n".join(f"{padding}\t{serialize(v, indent + 1)}," for v in value) + "\n" + padding + ")"
    return str(value) if isinstance(value, int) else json.dumps(value)


def configuration_list(name, settings):
    configs = []
    for mode in ("Debug", "Release"):
        current = dict(settings)
        current.update({
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
            "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym",
            "ONLY_ACTIVE_ARCH": "YES" if mode == "Debug" else "NO",
        })
        conditions = current.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "$(inherited)")
        current["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = conditions + (" DEBUG" if mode == "Debug" else "")
        configs.append(add(f"config:{name}:{mode}", "XCBuildConfiguration", name=mode, buildSettings=current))
    return add(f"configs:{name}", "XCConfigurationList", buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Sources/Lilim").glob("*.swift"))
sources.append("Sources/PTYBridge/PTYBridge.c")
resources = [".build/icons/AppIcon.icns", ".build/icons/LilimIcon.png", "App/PrivacyInfo.xcprivacy"]
references = {}
for path in sources + resources + ["App/Distribution-Info.plist", "App/AppStore.entitlements"]:
    extension = Path(path).suffix
    file_type = {".swift": "sourcecode.swift", ".c": "sourcecode.c.c", ".icns": "image.icns",
                 ".png": "image.png", ".plist": "text.plist.xml", ".entitlements": "text.plist.entitlements",
                 ".xcprivacy": "text.xml"}[extension]
    references[path] = add(f"file:{path}", "PBXFileReference", lastKnownFileType=file_type,
                           path=path, sourceTree="SOURCE_ROOT")

source_group = add("group:sources", "PBXGroup", name="Sources", sourceTree="<group>", children=[references[p] for p in sources])
app_group = add("group:app", "PBXGroup", name="App", sourceTree="<group>", children=[references[p] for p in references if p not in sources])
products = []
targets = []
project_configs = configuration_list("project", {
    "MACOSX_DEPLOYMENT_TARGET": "14.0", "SDKROOT": "macosx", "SWIFT_VERSION": "6.0",
    "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "SWIFT_STRICT_CONCURRENCY": "complete", "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "ARCHS": "$(ARCHS_STANDARD)",
})

for target_name, product_name, store in (("Lilim", "Lilim", False), ("Lilim-AppStore", "LilimStore", True)):
    build_sources = [add(f"build:{target_name}:{p}", "PBXBuildFile", fileRef=references[p]) for p in sources]
    build_resources = [add(f"build:{target_name}:{p}", "PBXBuildFile", fileRef=references[p]) for p in resources]
    source_phase = add(f"sources:{target_name}", "PBXSourcesBuildPhase", buildActionMask=2147483647,
                       files=build_sources, runOnlyForDeploymentPostprocessing=0)
    resource_phase = add(f"resources:{target_name}", "PBXResourcesBuildPhase", buildActionMask=2147483647,
                         files=build_resources, runOnlyForDeploymentPostprocessing=0)
    icon_phase = add(f"icons:{target_name}", "PBXShellScriptBuildPhase", buildActionMask=2147483647, files=[],
                     inputPaths=["$(SRCROOT)/App/Assets/AppIcon.png", "$(SRCROOT)/scripts/build-icon.sh"],
                     outputPaths=["$(SRCROOT)/.build/icons/AppIcon.icns", "$(SRCROOT)/.build/icons/LilimIcon.png"],
                     runOnlyForDeploymentPostprocessing=0, shellPath="/bin/bash",
                     shellScript='bash "$SRCROOT/scripts/build-icon.sh"\n')
    product = add(f"product:{target_name}", "PBXFileReference", explicitFileType="wrapper.application",
                  includeInIndex=0, path=product_name + ".app", sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    settings = {
        "PRODUCT_NAME": product_name,
        "PRODUCT_BUNDLE_IDENTIFIER": "dev.lilim.workspace.appstore" if store else "dev.lilim.workspace",
        "INFOPLIST_FILE": "App/Distribution-Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
        "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "0.1.0",
        "CODE_SIGN_STYLE": "Automatic", "ENABLE_HARDENED_RUNTIME": "YES",
        "HEADER_SEARCH_PATHS": "$(SRCROOT)/Sources/PTYBridge/include",
        "SWIFT_INCLUDE_PATHS": "$(SRCROOT)/Sources/PTYBridge/include",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
        "COMBINE_HIDPI_IMAGES": "YES", "SUPPORTED_PLATFORMS": "macosx",
    }
    if store:
        settings.update({"CODE_SIGN_ENTITLEMENTS": "App/AppStore.entitlements",
                         "ENABLE_APP_SANDBOX": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) LILIM_APP_STORE"})
    target = add(f"target:{target_name}", "PBXNativeTarget", name=target_name, productName=product_name,
                 productReference=product, productType="com.apple.product-type.application",
                 buildConfigurationList=configuration_list(target_name, settings),
                 buildPhases=[icon_phase, source_phase, resource_phase], buildRules=[], dependencies=[])
    targets.append(target)
    scheme = ET.Element("Scheme", LastUpgradeVersion="2620", version="1.3")
    build_action = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entry = ET.SubElement(ET.SubElement(build_action, "BuildActionEntries"), "BuildActionEntry",
                          buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES",
                          buildForArchiving="YES", buildForAnalyzing="YES")
    reference_attrs = {"BuildableIdentifier": "primary", "BlueprintIdentifier": target,
                       "BuildableName": product_name + ".app", "BlueprintName": target_name,
                       "ReferencedContainer": "container:Lilim.xcodeproj"}
    ET.SubElement(entry, "BuildableReference", **reference_attrs)
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug",
                           selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                           selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0",
                           useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO",
                           debugDocumentVersioning="YES", debugServiceExtension="internal", allowLocationSimulation="YES")
    runnable = ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0")
    ET.SubElement(runnable, "BuildableReference", **reference_attrs)
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    scheme_dir = PROJECT / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    ET.indent(scheme)
    ET.ElementTree(scheme).write(scheme_dir / (target_name + ".xcscheme"), encoding="UTF-8", xml_declaration=True)

products_group = add("group:products", "PBXGroup", name="Products", sourceTree="<group>", children=products)
main_group = add("group:main", "PBXGroup", sourceTree="<group>", children=[source_group, app_group, products_group])
project = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2620", "LastSwiftUpdateCheck": "2620"},
              buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0", developmentRegion="ko",
              hasScannedForEncodings=0, knownRegions=["ko", "en", "Base"], mainGroup=main_group,
              productRefGroup=products_group, projectDirPath="", projectRoot="", targets=targets)
document = {"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project}
PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + serialize(document) + "\n")
print(PROJECT)
