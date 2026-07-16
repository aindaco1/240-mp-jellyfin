#!/bin/zsh
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "usage: $0 <App.app> <source-root> <qmlimportscanner> <Qt-QML-import-path>" >&2
    exit 2
fi

app="$1"
source_root="$2"
qmlimportscanner="$3"
qt_qml_path="$4"
qml_root="$app/Contents/Resources/qml"
quick_plugins="$app/Contents/PlugIns/quick"

if [[ ! -d "$app/Contents" || ! -d "$source_root" ]]; then
    echo "App bundle or source root not found" >&2
    exit 1
fi
if [[ ! -x "$qmlimportscanner" || ! -d "$qt_qml_path" ]]; then
    echo "Qt QML scanner or import path not found" >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to read qmlimportscanner output" >&2
    exit 1
fi

typeset -A imported_plugins
while IFS= read -r plugin; do
    [[ -n "$plugin" ]] && imported_plugins[$plugin]=1
done < <("$qmlimportscanner" -rootPath "$source_root" -importPath "$qt_qml_path" \
    | jq -r '.[] | select(.plugin != null and .plugin != "") | .plugin')

removed_modules=0
if [[ -d "$qml_root" ]]; then
    module_dirs=()
    while IFS= read -r qmldir; do
        plugins=("${(@f)$(awk '
            $1 == "plugin" { print $2 }
            $1 == "optional" && $2 == "plugin" { print $3 }
        ' "$qmldir")}")
        (( ${#plugins[@]} == 0 )) && continue

        keep=false
        for plugin in "${plugins[@]}"; do
            if [[ -n "${imported_plugins[$plugin]:-}" ]]; then
                keep=true
                break
            fi
        done
        if [[ "$keep" == false ]]; then
            module_dirs+=("${qmldir:h}")
        fi
    done < <(find "$qml_root" -name qmldir -type f -print)

    for module_dir in "${module_dirs[@]}"; do
        [[ -d "$module_dir" ]] || continue
        rm -rf "$module_dir"
        (( ++removed_modules ))
    done
fi

typeset -A referenced_quick_plugins
if [[ -d "$qml_root" ]]; then
    while IFS= read -r link; do
        target=$(readlink "$link")
        [[ -n "$target" ]] && referenced_quick_plugins[${target:t}]=1
    done < <(find "$qml_root" -type l -name '*.dylib' -print)
fi

removed_plugins=0
if [[ -d "$quick_plugins" ]]; then
    for plugin in "$quick_plugins"/*.dylib(N); do
        plugin_name="${plugin:t}"
        if [[ -z "${referenced_quick_plugins[$plugin_name]:-}" ]]; then
            rm -f "$plugin"
            (( ++removed_plugins ))
        fi
    done
fi

updated_rpaths=0
while IFS= read -r binary; do
    file -b "$binary" | grep -q 'Mach-O' || continue
    rpaths=("${(@f)$(otool -l "$binary" | awk '
        $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
        in_rpath && $1 == "path" { print $2; in_rpath = 0 }
    ')}")
    for rpath in "${rpaths[@]}"; do
        [[ "$rpath" == /* && "$rpath" != /System/* && "$rpath" != /usr/lib/* ]] || continue
        install_name_tool -delete_rpath "$rpath" "$binary"
        (( ++updated_rpaths ))
    done
done < <(find "$app" -type f -print)

echo "Pruned $removed_modules unused QML modules and $removed_plugins quick plugins; removed $updated_rpaths external rpaths"
