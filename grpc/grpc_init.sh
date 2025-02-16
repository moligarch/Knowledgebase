#!/bin/bash

DEBUG=false
CMAKE_OPTIONS="-DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
               -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
               -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
               -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
               -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF"

# Function to print in debug mode
debug_echo() {
    if [ "$DEBUG" = true ]; then
        echo "Debug: $@"
    fi
}

handle_error() {
    echo "Error in $(basename "$0") at line $LINENO: $1"
    exit 1
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--debug)
                DEBUG=true
                shift
                ;;
            --csharp)
                CMAKE_OPTIONS="${CMAKE_OPTIONS//-DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF/-DgRPC_BUILD_GRPC_CSHARP_PLUGIN=ON}"
                shift
                ;;
            --python)
                CMAKE_OPTIONS="${CMAKE_OPTIONS//-DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF/-DgRPC_BUILD_GRPC_PYTHON_PLUGIN=ON}"
                shift
                ;;
            --node)
                CMAKE_OPTIONS="${CMAKE_OPTIONS//-DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF/-DgRPC_BUILD_GRPC_NODE_PLUGIN=ON}"
                shift
                ;;
            --php)
                CMAKE_OPTIONS="${CMAKE_OPTIONS//-DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF/-DgRPC_BUILD_GRPC_PHP_PLUGIN=ON}"
                shift
                ;;
            --ruby)
                CMAKE_OPTIONS="${CMAKE_OPTIONS//-DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF/-DgRPC_BUILD_GRPC_RUBY_PLUGIN=ON}"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Parse arguments
parse_args "$@"

clone_repo() {
    local src_dir="$1"
    local target_branch="$2"

    if [ ! -d "$src_dir/.git" ]; then
        echo "Git repo doesn't exist, starting cloning it at $src_dir"
        git clone --depth 1 --branch "$target_branch" --recurse-submodules --shallow-submodules https://github.com/grpc/grpc "$src_dir"
        return 0 #Success
    else
        cd "$src_dir"
        git pull
        cd ..
        return 0 #Success
    fi
}

install_dependencies() {
    echo .
    echo "Installing dependencies (sudo privilege needed) ..."
    echo .
    
    if [ "$DEBUG" = true ]; then
        set -x
    fi
        
    sudo apt-get update
    sudo apt-get install -y \
        build-essential     \
        cmake               \
        pkg-config          \
        python3             \
        python3-pip
        
    if [ "$DEBUG" = true ]; then
        set +x
    fi  
        
    # Check if installation was successful
    if [ $? -ne 0 ]; then
        handle_error "Failed to install dependencies"
    fi
    return 0 #Success
}

configure_cmake() {
    local src_dir="$1"
    local build_dir="$2"
    local install_dir="$3"
    
    echo .
    debug_echo "============================="
    debug_echo "Source directory (configure cmake func) -> $src_dir"
    debug_echo "Build directory (configure cmake func) -> $build_dir"
    debug_echo "Install directory (configure cmake func) -> $install_dir"
    debug_echo "============================="
    echo .
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    echo .
    debug_echo "Current Directory (configure cmake func) -> $(pwd)"
    echo .
    
    if [ "$DEBUG" = true ]; then
        set -x
    fi
    
    cmake ../..                                \
        -DgRPC_INSTALL=ON                      \
        -DCMAKE_BUILD_TYPE=Release             \
        $CMAKE_OPTIONS
        
    if [ "$DEBUG" = true ]; then
        set +x 
    fi
        
    # Check if CMake configuration was successful
    if [ $? -ne 0 ]; then
        handle_error "Failed to configure CMake"
    fi
    return 0  # Success
}

build_and_install() {
    local build_dir="$1"
    
    echo .
    debug_echo "============================="
    debug_echo "Build directory (build install func) -> $build_dir"
    debug_echo "============================="
    echo .
    
    mkdir -p "$build_dir"
    cd "$build_dir"

    echo "Building gRPC..."
    
    if [ "$DEBUG" = true ]; then
        set -x
    fi
        
    make -j 4

    echo "Installing gRPC..."
    make install
    
    if [ "$DEBUG" = true ]; then
        set +x
    fi
    
    # Check if building and installing were successful
    if [ $? -ne 0 ]; then
        handle_error "Failed to build and install gRPC"
    fi
    return 0  # Success
}

main() {
    version="1.69.0"
    source_repo_dir="$(pwd)/grpc_$version"
    build_dir="$source_repo_dir/cmake/build"

    echo "Version:           $version"
    echo "Source Repo Dir:   $source_repo_dir"
    echo "Build Dir:         $build_dir"

    # Clone repo
    clone_repo "$source_repo_dir" "v$version" || handle_error "Failed to clone repository"

    # Install dependencies
    install_dependencies || handle_error "Failed to install dependencies"

    # Configure CMake
    configure_cmake "$source_repo_dir" "$build_dir" "$install_dir" || handle_error "Failed to configure CMake"

    # Build and install
    build_and_install "$build_dir" || handle_error "Failed to build and install gRPC"

    echo "Build process completed successfully!"
}

main