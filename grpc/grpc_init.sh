#!/bin/bash

# Constants
readonly VERSION="1.69.0"
readonly SOURCE_REPO_DIR="$(pwd)/grpc_${VERSION}"
readonly BUILD_DIR="${SOURCE_REPO_DIR}/cmake/build"
readonly DEFAULT_CONCURRENCY=8

# Configuration
CMAKE_OPTIONS="-DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
-DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
-DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
-DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
-DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF"

# Error handling
error_handler() {
    local message="$1"
    local exit_code="${2:-1}"
    echo "ERROR: ${message}" >&2
    exit "${exit_code}"
}

# Argument parsing
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --csharp|--python|--node|--php|--ruby)
                local plugin="${1:2}"
                CMAKE_OPTIONS="${CMAKE_OPTIONS//-DgRPC_BUILD_GRPC_${plugin^^}_PLUGIN=OFF/-DgRPC_BUILD_GRPC_${plugin^^}_PLUGIN=ON}"
                shift
                ;;
            *)
                error_handler "Unknown option: $1"
                ;;
        esac
    done
}

# Repository management
clone_repo() {
    local src_dir="$1"
    local target_branch="$2"
    
    if [ ! -d "$src_dir/.git" ]; then
        if ! git clone --depth 1 --branch "$target_branch" --recurse-submodules --shallow-submodules https://github.com/grpc/grpc "$src_dir"; then
            error_handler "Failed to clone repository"
        fi
    else
        if ! (cd "$src_dir" && git submodule update --init --recursive); then
            error_handler "Failed to update repository"
        fi
    fi
}

# Dependency installation
install_dependencies() {
    if ! sudo apt-get update; then
        error_handler "Failed to update package lists"
    fi
    
    local packages="build-essential cmake pkg-config python3 python3-pip"
    if ! sudo apt-get install -y $packages; then
        error_handler "Failed to install dependencies"
    fi
}

# CMake configuration
configure_cmake() {
    local src_dir="$1"
    local build_dir="$2"
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    local cmake_cmd=(
        cmake
        ../..
        -DgRPC_INSTALL=ON
        -DCMAKE_BUILD_TYPE=Release
        ${CMAKE_OPTIONS}
    )
    
    if ! "${cmake_cmd[@]}"; then
        error_handler "Failed to configure CMake"
    fi
}

# Build and installation
build_and_install() {
    local build_dir="$1"
    local concurrency="${2:-$DEFAULT_CONCURRENCY}"
    local build_success=true
    local install_success=true
    
    cd "$build_dir"
    
    if ! make -j "$concurrency"; then
        build_success=false
        error_handler "Failed to build gRPC"
    fi
    
    if [ "$build_success" = true ] && ! make install; then
        install_success=false
        error_handler "Failed to install gRPC"
    fi
    
    if [ "$build_success" = true ] && [ "$install_success" = true ]; then
        if [ -n "$SOURCE_REPO_DIR" ] && [ -d "$SOURCE_REPO_DIR" ]; then
            if ! rm -rf "$SOURCE_REPO_DIR"; then
                error_handler "Failed to remove source directory"
            fi
        fi
    fi
}

# Main execution
main() {
    echo "Starting gRPC installation process..."
    echo "Version: $VERSION"
    echo "Source directory: $SOURCE_REPO_DIR"
    echo "Build directory: $BUILD_DIR"
    
    parse_args "$@"
    
    clone_repo "$SOURCE_REPO_DIR" "v$VERSION"
    install_dependencies
    configure_cmake "$SOURCE_REPO_DIR" "$BUILD_DIR"
    build_and_install "$BUILD_DIR"
    
    echo "gRPC installation completed successfully!"
}

# Trap errors and run main
trap 'error_handler "Script failed unexpectedly"' ERR
main "$@"
trap - ERR
