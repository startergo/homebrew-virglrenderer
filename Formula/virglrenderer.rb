class Virglrenderer < Formula
  desc "Virtual 3D GPU for QEMU guests"
  homepage "https://gitlab.freedesktop.org/virgl/virglrenderer"
  license "MIT"

  version "1.0.0"
  url "https://github.com/startergo/homebrew-virglrenderer/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "4e60e22e6e1d5b8a1234567890abcdef1234567890abcdef1234567890abcdef"
  head "https://gitlab.freedesktop.org/virgl/virglrenderer.git",
       using: :git

  bottle do
    root_url "https://github.com/startergo/homebrew-virglrenderer/releases/download/v1.0.0"
    sha256 cellar: :any, arm64_sequoia: "0000000000000000000000000000000000000000000000000000000000000000"
  end

  depends_on "startergo/angle/angle"
  depends_on "startergo/libepoxy/libepoxy"
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build

  def install
    # Download upstream virglrenderer source (HEAD from freedesktop)
    upstream_commit = "HEAD"
    upstream_url = "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/master/virglrenderer-master.tar.gz"
    ohai "Downloading upstream virglrenderer from #{upstream_url}"
    system "curl", "-L", upstream_url, "-o", "virglrenderer.tar.gz"
    system "tar", "-xzf", "virglrenderer.tar.gz", "--strip-components=1"

    # Get ANGLE and libepoxy include paths
    angle = Formula["startergo/angle/angle"]
    libepoxy = Formula["startergo/libepoxy/libepoxy"]
    angle_include = "#{angle.include}"
    epoxy_pc_path = "#{libepoxy.lib}/pkgconfig"

    system "meson", "setup", "build",
           *std_meson_args,
           "-Dc_args=-I#{angle_include}",
           "-Dcpp_args=-I#{angle_include}",
           "--pkg-config-path=#{epoxy_pc_path}",
           "-Dplatforms=egl",
           "-Ddrm=disabled",
           "-Dvenus=disabled",
           "-Dtests=false",
           "-Dvideo=disabled",
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
