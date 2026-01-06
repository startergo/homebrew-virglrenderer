class Virglrenderer < Formula
  desc "Virtual 3D GPU for QEMU guests"
  homepage "https://gitlab.freedesktop.org/virgl/virglrenderer"
  license "MIT"

  version "1.0.1"
  version "1.0.2"
  url "https://github.com/startergo/homebrew-virglrenderer/archive/d6f8cab0f9cc8813d795f9ca2b03b7a43f008b91.tar.gz"
  sha256 "74315e45d6aef92a4405bffd766789da0c7438c4bf9be4074aaace298f0cc477"
  head "https://gitlab.freedesktop.org/virgl/virglrenderer.git", branch: "main"

  bottle do
    root_url "https://github.com/startergo/homebrew-virglrenderer/releases/download/v1.0.2"
    sha256 arm64_sequoia: "daa93f2c97d09b5fdc749c579a1c91dc45ccfc1ad939295809496e2639b074e3"
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

    # Apply macOS support patch
    patch_file = "#{__dir__}/../patches/virglrenderer-main-macos.patch"
    ohai "Applying Venus/macOS support patch..."
    system "patch", "-p1", "--batch", "--verbose", "-i", patch_file

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
  end

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
