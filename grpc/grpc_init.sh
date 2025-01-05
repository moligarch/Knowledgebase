#!/bin/bash

# Function to clone repo
clone_repo() {
    local src_dir="$1"
    local target_branch="$2"

    if [ ! -d "$src_dir/.git" ]; then
        echo "Git repo doesn't exist, starting cloning it at $src_dir"
        git clone --depth 1 --branch "$target_branch" --recurse-submodules --shallow-submodules https://github.com/grpc/grpc "$src_dir"
    else
        cd "$src_dir"
        git pull
        cd ..
    fi
}


# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    
    sudo apt-get update
    sudo apt-get install -y \
        build-essential     \
        cmake               \
        pkg-config          \
        python3             \
        python3-pip
}


# Function to configure CMake
configure_cmake() {
    local src_dir="$1"
    local build_dir="$2"
    local install_dir="$3"
    
    echo "Initiating folder structure ..."
    mkdir -p $build_dir
    cd $build_dir
    
    #Cleaner way is to use below cmake args
    #Source Dir: -S "$src_dir"
    #Build Dir: -B "$build_dir"
    #Install Dir: -DCMAKE_INSTALL_PREFIX="$install_dir"
    
    cmake ../..
        -DgRPC_INSTALL=ON                      \
        -DCMAKE_BUILD_TYPE=Release             \
        -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF    \
        -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF      \
        -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF       \
        -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF    \
        -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF
}

# Function to build and install
build_and_install() {
    local build_dir="$1"

    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd $build_dir
    echo "Cleaning build directory..."
    make clean
    echo "Building gRPC..."
    make -j 4

    echo "Installing gRPC..."
    make install
}



version="1.69.0"
source_repo_dir="./grpc_$version"
build_dir="$source_repo_dir/cmake/build"

echo "Version:           $version"
echo "Source Repo Dir:   $source_repo_dir"
echo "Build Dir:         $build_dir"


# Clone repo
clone_repo "$source_repo_dir" "v$version"

# Install dependencies
install_dependencies

# Configure CMake
configure_cmake "$source_repo_dir" "$build_dir" "$install_dir"

# Build and install
build_and_install "$build_dir"

echo "Build process completed successfully!"