class Virglrenderer < Formula
  desc "Virtual 3D GPU for QEMU guests"
  homepage "https://gitlab.freedesktop.org/virgl/virglrenderer"
  license "MIT"

  version "1.0.33"
  url "https://github.com/startergo/homebrew-virglrenderer/archive/refs/tags/v1.0.33.tar.gz"
  sha256 "1d74bd6961abb5535413ddb572592d40d7586b73c2bb5a5d73a69018f82abdc6"
  head "https://gitlab.freedesktop.org/virgl/virglrenderer.git", branch: "main"

  bottle do
    root_url "https://github.com/startergo/homebrew-virglrenderer/releases/download/v1.0.33"
    sha256 arm64_sequoia: "26ad3e927d300587024cd92276d38bf813f6228d130a1800c97f1c18688b34ba"
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
      "venus-metal-unified.patch",
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

    system "meson", "setup", "build",
           *std_meson_args,
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
    (testpath/"test.c").write <<~EOS
      #include <virglrenderer.h>
      int main() {
        virgl_renderer_init(0, NULL, NULL);
        virgl_renderer_cleanup();
        return 0;
      }
    EOS

    system ENV.cc, "test.c",
           "-I#{include}/virgl",
           "-L#{lib}",
           "-lvirglrenderer",
           "-o", "test"
    system "./test"
  end
end
