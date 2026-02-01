class Virglrenderer < Formula
  desc "Virtual 3D GPU for QEMU guests"
  homepage "https://gitlab.freedesktop.org/virgl/virglrenderer"
  license "MIT"

  version "1.0.37"
  url "https://github.com/startergo/homebrew-virglrenderer/archive/refs/tags/v1.0.37.tar.gz"
  sha256 "27bfd2aa4e1e41c0731bb688e70d6e5e21b76bb740d179d88b948c1502079f66"
  head "https://gitlab.freedesktop.org/virgl/virglrenderer.git", branch: "main"

  bottle do
    root_url "https://github.com/startergo/homebrew-virglrenderer/releases/download/v1.0.37"
    sha256 arm64_sequoia: "f75e111aa10da2b833e8ec460924e8e81d20ee0a8d9c6031fc9558da2ec46822"
  end

  depends_on "startergo/angle/angle"
  depends_on "startergo/libepoxy/libepoxy"
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3" => :build

  def install
    # Install pyyaml for gallium subproject (required by meson)
    # Use --break-system-packages as build runs in isolated environment
    system "python3", "-m", "pip", "install", "--break-system-packages", "pyyaml"

    # Download upstream virglrenderer source from GitLab main
    upstream_url = "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/main/virglrenderer-main.tar.gz"
    ohai "Downloading upstream virglrenderer from #{upstream_url}"
    system "curl", "-L", upstream_url, "-o", "virglrenderer.tar.gz"
    system "tar", "-xzf", "virglrenderer.tar.gz", "--strip-components=1"

    # Apply macOS patches
    patches = [
      "virglrenderer-debug-init-logging.patch",
      "virglrenderer-default-debug-log.patch",
      "virglrenderer-macos-unified.patch",
      "virglrenderer-msaa-assertion-fix.patch",
      "virglrenderer-ignore-surface0-clear.patch",
      "virglrenderer-venus-errno-debug.patch",
      "virglrenderer-egl-core-profile.patch",
      "virglrenderer-core-profile-init.patch",
      "virglrenderer-bgra-desktop-gl.patch",
      "virglrenderer-core-profile-bgra.patch",
      "virglrenderer-core-profile-format-override.patch",
      "virglrenderer-core-profile-frag-datalocation.patch",
      "virglrenderer-bgra-unified.patch"
    ]

    patches.each do |patch|
      patch_file = "#{__dir__}/../patches/#{patch}"
      ohai "Applying #{patch}..."
      system "patch", "-p1", "--batch", "--verbose", "-i", patch_file
    end

    # Get ANGLE and libepoxy paths
    angle = Formula["startergo/angle/angle"]
    libepoxy = Formula["startergo/libepoxy/libepoxy"]
    angle_include = "#{angle.include}"
    angle_pc_path = "#{angle.lib}/pkgconfig"
    epoxy_pc_path = "#{libepoxy.lib}/pkgconfig"
    combined_pc_path = "#{angle_pc_path}:#{epoxy_pc_path}"

    # Override std_meson_args buildtype with debug
    debug_meson_args = std_meson_args.reject { |arg| arg.include?("--buildtype=") } + ["--buildtype=debug"]

    system "meson", "setup", "build",
           *debug_meson_args,
           "-Dc_args=-I#{angle_include}",
           "-Dcpp_args=-I#{angle_include}",
           "--pkg-config-path=#{combined_pc_path}",
           "-Ddrm-renderers=[]",
           "-Dvenus=true",
           "-Dtests=false",
           "-Dvideo=false",
           "-Dtracing=none"
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"

    # Add rpath so dlopen via libepoxy finds ANGLE libraries at runtime
    # ANGLE uses @rpath/libEGL.dylib, so we need rpath to HOMEBREW_PREFIX/lib
    dylib = "#{lib}/libvirglrenderer.1.dylib"
    rpath = "#{HOMEBREW_PREFIX}/lib"
    # install_name_tool -l outputs "path /opt/homebrew/lib" format
    unless Utils.popen_read("install_name_tool", "-l", dylib).include?("path #{rpath}")
      system "install_name_tool", "-add_rpath", rpath, dylib
    end
  end

  # No post_install needed - rpath is set during install

  test do
  end
end
