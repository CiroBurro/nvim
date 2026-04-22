#!/usr/bin/env python3
"""
Extract imports from a Java file, resolve them to Maven coordinates,
find JARs in Maven local repo, and update .classpath for JDT.LS.

If JARs aren't cached, downloads them using a temporary pom.xml + mvn.
"""

import json
import subprocess
import sys
import tempfile
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from pathlib import Path
from collections import defaultdict

M2_REPO = Path.home() / ".m2" / "repository"

# Well-known package -> Maven coordinate mappings
KNOWN_ARTIFACTS = {
    "org.bukkit": ("org.spigotmc", "spigot-api", "1.20.4-R0.1-SNAPSHOT"),
    "org.spigotmc": ("org.spigotmc", "spigot-api", "1.20.4-R0.1-SNAPSHOT"),
    "com.destroystokyo.paper": ("io.papermc.paper", "paper-api", "1.20.4-R0.1-SNAPSHOT"),
    "io.papermc": ("io.papermc.paper", "paper-api", "1.20.4-R0.1-SNAPSHOT"),
    "net.md_5.bungee": ("net.md-5", "bungeecord-api", "1.20-R0.1-SNAPSHOT"),
    "com.mojang": ("com.mojang", "brigadier", "1.0.18"),
    "net.minecraft": ("io.papermc.paper", "paper-api", "1.20.4-R0.1-SNAPSHOT"),
}

EXTRA_REPOS = {
    "org.spigotmc": {
        "id": "spigot-repo",
        "url": "https://hub.spigotmc.org/nexus/content/repositories/snapshots/",
    },
    "org.bukkit": {
        "id": "spigot-repo",
        "url": "https://hub.spigotmc.org/nexus/content/repositories/snapshots/",
    },
    "io.papermc": {
        "id": "papermc",
        "url": "https://repo.papermc.io/repository/maven-public/",
    },
    "com.destroystokyo.paper": {
        "id": "papermc",
        "url": "https://repo.papermc.io/repository/maven-public/",
    },
    "net.md_5.bungee": {
        "id": "bungeecord-repo",
        "url": "https://oss.sonatype.org/content/repositories/snapshots",
    },
}

JDK_PREFIXES = (
    "java.", "javax.", "jdk.", "sun.", "com.sun.", "org.w3c.", "org.xml.",
    "org.ietf.", "netscape.",
)


def extract_imports(java_file: Path) -> list[str]:
    imports = []
    with open(java_file) as f:
        for line in f:
            line = line.strip()
            if line.startswith("import "):
                fqcn = line.removeprefix("import ").removeprefix("static ").rstrip(";").strip()
                if not fqcn.startswith(tuple(JDK_PREFIXES)):
                    imports.append(fqcn)
            elif line.startswith("class ") or line.startswith("public ") or line.startswith("interface "):
                break
    return imports


def get_package_prefix(fqcn: str, depth: int = 2) -> str:
    parts = fqcn.split(".")
    return ".".join(parts[:min(depth, len(parts))])


def search_maven_central(fqcn: str) -> tuple[str, str, str] | None:
    url = f"https://search.maven.org/solrsearch/select?q=fc:{fqcn}&rows=5&wt=json"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "nvim-java-deps/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            docs = data.get("response", {}).get("docs", [])
            if docs:
                doc = docs[0]
                return (doc["g"], doc["a"], doc["v"])
    except (urllib.error.URLError, json.JSONDecodeError, KeyError, TimeoutError):
        pass
    return None


def resolve_imports(imports: list[str]) -> tuple[dict, dict]:
    prefixes = defaultdict(list)
    for fqcn in imports:
        prefix = get_package_prefix(fqcn)
        prefixes[prefix].append(fqcn)

    artifacts = {}
    repos = {}

    for prefix, classes in prefixes.items():
        matched = False
        for known_prefix, coords in KNOWN_ARTIFACTS.items():
            if prefix.startswith(known_prefix) or known_prefix.startswith(prefix):
                key = f"{coords[0]}:{coords[1]}"
                if key not in artifacts:
                    artifacts[key] = coords
                    for repo_prefix, repo in EXTRA_REPOS.items():
                        if prefix.startswith(repo_prefix) or repo_prefix.startswith(prefix):
                            repos[repo["id"]] = repo["url"]
                matched = True
                break

        if matched:
            continue

        print(f"  Searching Maven Central for {classes[0]}...", file=sys.stderr)
        result = search_maven_central(classes[0])
        if result:
            key = f"{result[0]}:{result[1]}"
            if key not in artifacts:
                artifacts[key] = result
                print(f"  Found: {result[0]}:{result[1]}:{result[2]}", file=sys.stderr)
        else:
            print(f"  Not found on Maven Central: {prefix}.*", file=sys.stderr)

    return artifacts, repos


def find_jar(g: str, a: str, v: str) -> Path | None:
    """Find a JAR in the Maven local repo."""
    group_path = g.replace(".", "/")
    base = M2_REPO / group_path / a / v
    # Try exact name
    jar = base / f"{a}-{v}.jar"
    if jar.exists():
        return jar
    # For snapshots, look for any JAR
    if base.exists():
        jars = list(base.glob("*.jar"))
        if jars:
            return jars[0]
    return None


def download_deps(artifacts: dict, repos: dict) -> None:
    """Use Maven to download artifacts that aren't in the local cache."""
    missing = []
    for _, (g, a, v) in artifacts.items():
        if find_jar(g, a, v) is None:
            missing.append((g, a, v))

    if not missing:
        return

    print(f"Downloading {len(missing)} missing artifact(s)...", file=sys.stderr)

    deps_xml = ""
    for g, a, v in missing:
        deps_xml += f"<dependency><groupId>{g}</groupId><artifactId>{a}</artifactId><version>{v}</version></dependency>"

    repos_xml = ""
    for rid, url in repos.items():
        repos_xml += f"<repository><id>{rid}</id><url>{url}</url></repository>"

    pom = f"""<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <modelVersion>4.0.0</modelVersion>
    <groupId>tmp</groupId><artifactId>tmp</artifactId><version>0</version>
    {f'<repositories>{repos_xml}</repositories>' if repos_xml else ''}
    <dependencies>{deps_xml}</dependencies>
</project>"""

    with tempfile.TemporaryDirectory() as tmpdir:
        pom_path = Path(tmpdir) / "pom.xml"
        pom_path.write_text(pom)
        subprocess.run(
            ["mvn", "-f", str(pom_path), "dependency:resolve", "-q"],
            capture_output=True,
        )


def update_classpath(artifacts: dict, repos: dict, output_dir: Path) -> bool:
    """Update .classpath with library entries for resolved JARs."""
    # Download any missing JARs first
    download_deps(artifacts, repos)

    classpath_path = output_dir / ".classpath"
    if not classpath_path.exists():
        return False

    tree = ET.parse(classpath_path)
    root = tree.getroot()

    # Remove existing lib entries (we regenerate them)
    for entry in root.findall("classpathentry[@kind='lib']"):
        root.remove(entry)

    # Add JAR entries
    added = 0
    for _, (g, a, v) in artifacts.items():
        jar = find_jar(g, a, v)
        if jar:
            ET.SubElement(root, "classpathentry", kind="lib", path=str(jar))
            added += 1
            print(f"  Added {jar.name}", file=sys.stderr)
        else:
            print(f"  JAR not found: {g}:{a}:{v}", file=sys.stderr)

    if added > 0:
        ET.indent(tree, space="    ")
        tree.write(classpath_path, encoding="unicode", xml_declaration=True)
        print(f"Updated .classpath with {added} library entries", file=sys.stderr)
        return True

    return False


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file.java> [project_dir]", file=sys.stderr)
        sys.exit(1)

    java_file = Path(sys.argv[1])
    project_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else java_file.parent

    if not java_file.exists():
        print(f"File not found: {java_file}", file=sys.stderr)
        sys.exit(1)

    print(f"Extracting imports from {java_file.name}...", file=sys.stderr)
    imports = extract_imports(java_file)
    if not imports:
        print("No non-JDK imports found.", file=sys.stderr)
        sys.exit(0)

    print(f"Found {len(imports)} non-JDK imports, resolving...", file=sys.stderr)
    artifacts, repos = resolve_imports(imports)

    if not artifacts:
        print("Could not resolve any dependencies.", file=sys.stderr)
        sys.exit(1)

    print(f"\nResolved {len(artifacts)} artifact(s):", file=sys.stderr)
    for _, (g, a, v) in artifacts.items():
        print(f"  {g}:{a}:{v}", file=sys.stderr)

    update_classpath(artifacts, repos, project_dir)
    print(str(project_dir / ".classpath"))


if __name__ == "__main__":
    main()
