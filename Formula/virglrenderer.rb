class Virglrenderer < Formula
  desc "Virtual 3D GPU for QEMU guests"
  homepage "https://gitlab.freedesktop.org/virgl/virglrenderer"
  license "MIT"

  version "1.0.0"
  version "1.0.1"
  url "https://github.com/startergo/homebrew-virglrenderer/archive/432e35dc50b616fe156f2fa12d11681a94180b52.tar.gz"
  sha256 "d009c31e2eb07782c89921a65d1b8bbd5033f9cbb63b8d59899856e0e7d8af6c"
  head "https://gitlab.freedesktop.org/virgl/virglrenderer.git", branch: "main"

  bottle do
    root_url "https://github.com/startergo/homebrew-virglrenderer/releases/download/v1.0.1"
    sha256 arm64_sequoia: "e18007b1cb54462f601d18d7bc518b4f225fc15982bb13590f46a714a03d390b"
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

    # Download and extract LunarG Vulkan SDK
    vulkan_sdk_version = "1.4.335.1"
    vulkan_sdk_url = "https://sdk.lunarg.com/sdk/download/#{vulkan_sdk_version}/mac/vulkansdk-macos-#{vulkan_sdk_version}.zip"
    ohai "Downloading LunarG Vulkan SDK #{vulkan_sdk_version}..."
    system "curl", "-L", vulkan_sdk_url, "-o", "vulkan-sdk.zip"
    system "unzip", "-q", "vulkan-sdk.zip"
    vulkan_sdk_dir = "vulkansdk-macos-#{vulkan_sdk_version}"
    ENV["VULKAN_SDK"] = File.expand_path(vulkan_sdk_dir)

    # Apply macOS support patch
    patch_file = "#{__dir__}/../patches/virglrenderer-main-macos.patch"
    ohai "Applying Venus/macOS support patch..."
    system "patch", "-p1", "--batch", "--verbose", "-i", patch_file

    # Get ANGLE, libepoxy, and Vulkan SDK paths
    angle = Formula["startergo/angle/angle"]
    libepoxy = Formula["startergo/libepoxy/libepoxy"]
    angle_include = "#{angle.include}"
    angle_pc_path = "#{angle.lib}/pkgconfig"
    epoxy_pc_path = "#{libepoxy.lib}/pkgconfig"
    vulkan_pc_path = "#{vulkan_sdk_dir}/macOS/lib/pkgconfig"
    vulkan_include = "#{vulkan_sdk_dir}/macOS/include"
    combined_pc_path = "#{angle_pc_path}:#{epoxy_pc_path}:#{vulkan_pc_path}"

    system "meson", "setup", "build",
           *std_meson_args,
           "-Dc_args=-I#{angle_include} -I#{vulkan_include}",
           "-Dcpp_args=-I#{angle_include} -I#{vulkan_include}",
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
