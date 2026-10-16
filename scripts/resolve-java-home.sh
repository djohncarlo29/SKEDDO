# Shared JDK discovery for the APK build and Shorebird patch scripts.
#
# Source this file, then call resolve_java_home.

_is_usable_jdk() {
  local jdk_home="${1:-}"
  [[ -n "$jdk_home" && -x "$jdk_home/bin/java" && -x "$jdk_home/bin/javac" ]] ||
    return 1

  local version major
  version="$("$jdk_home/bin/java" -version 2>&1 |
    sed -nE 's/.*version "([^"]+)".*/\1/p' |
    head -n 1)"
  [[ -n "$version" ]] || return 1

  major="${version%%.*}"
  if [[ "$major" == "1" ]]; then
    version="${version#1.}"
    major="${version%%.*}"
  fi
  [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 17 ))
}

resolve_java_home() {
  local candidate="${JAVA_HOME:-}"
  if [[ -n "$candidate" ]] && _is_usable_jdk "$candidate"; then
    :
  else
    if [[ -n "$candidate" ]]; then
      echo "⚠️ JAVA_HOME does not point to a usable Java 17+ JDK; searching for one." >&2
    fi
    candidate=""

    local java_bin
    java_bin="$(command -v java || true)"
    if [[ -n "$java_bin" ]]; then
      java_bin="$(readlink -f "$java_bin" 2>/dev/null || printf '%s' "$java_bin")"
      local path_home
      path_home="$(dirname "$(dirname "$java_bin")")"
      if _is_usable_jdk "$path_home"; then
        candidate="$path_home"
      fi
    fi
  fi

  if [[ -z "$candidate" ]]; then
    local jdk_candidate
    for jdk_candidate in \
      /nix/store/*-openjdk-17*/lib/openjdk \
      /nix/store/*-openjdk-21*/lib/openjdk \
      /nix/store/*-openjdk-*/lib/openjdk; do
      if _is_usable_jdk "$jdk_candidate"; then
        candidate="$jdk_candidate"
        break
      fi
    done
  fi

  if [[ -z "$candidate" ]]; then
    echo "ERROR: No usable Java 17+ JDK found. Set JAVA_HOME or install a JDK." >&2
    return 1
  fi

  export JAVA_HOME="$candidate"
  export PATH="$JAVA_HOME/bin:$PATH"
  printf '→ Using Java: '
  "$JAVA_HOME/bin/java" -version 2>&1 | head -n 1
}
