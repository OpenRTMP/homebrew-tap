class Librtmp2 < Formula
  desc "Modern RTMP and RTMPS protocol library"
  homepage "https://github.com/OpenRTMP/librtmp2"
  url "https://github.com/OpenRTMP/librtmp2/releases/download/v0.16.1/librtmp2-0.16.1-src.tar.gz"
  sha256 "567cabfa77af25b136c06c9dac86a48da44cb446b429105ec0e3f3a50f6c6a5e"
  license "MIT"

  bottle do
    root_url "https://packages.openrtmp.org/homebrew/librtmp2/0.16.1"
    sha256 cellar: :any, arm64_golden_gate: "190339b967653e709ed61b7e3068179805a83179ad6c52dc74ce7329779ff589"
    sha256 cellar: :any, arm64_tahoe:       "f34be0a8c34cb9c3873b4052e5d95296bed8816f3fcee84fabc94c9b81325a70"
    sha256 cellar: :any, arm64_sequoia:     "5f29906a4e30acc660d59cad9a3ca3bbcce9433b1eb8f6effa8f1582fa0accc2"
    sha256 cellar: :any, tahoe:             "ab86213e8a9b233fde80ec79314bd70c503f1e9b0606f062ba92988fdf17f60a"
    sha256 cellar: :any, sequoia:           "c9968e22c2c8beed3595f7acc8b5b7d0904ad022fd5151e9cb95f66cec52d0be"
  end

  depends_on "cbindgen" => :build
  depends_on "pkgconf" => [:build, :test]
  depends_on "rust" => :build
  depends_on "openssl@3"

  def install
    ENV["OPENSSL_DIR"] = Formula["openssl@3"].opt_prefix

    # Releases that ship a Cargo.lock are built with exactly those dependency
    # versions; older source tarballs without one still resolve them.
    locked = File.exist?("Cargo.lock") ? ["--locked"] : []
    system "cargo", "build", "--release", *locked

    unless File.exist?("include/librtmp2/librtmp2.h")
      mkdir_p "include/librtmp2"
      system "cbindgen", "--lang", "c", "--cpp-compat", "--crate", "librtmp2",
             "--output", "include/librtmp2/librtmp2.h"
    end

    include.install "include/librtmp2"
    lib.install "target/release/liblibrtmp2.a"
    lib.install_symlink "liblibrtmp2.a" => "librtmp2.a"

    if OS.mac?
      lib.install "target/release/liblibrtmp2.dylib"
      lib.install_symlink "liblibrtmp2.dylib" => "librtmp2.dylib"
    else
      lib.install "target/release/liblibrtmp2.so"
      lib.install_symlink "liblibrtmp2.so" => "librtmp2.so"
    end

    # OpenSSL's Linux libcrypto.pc carries `ex_libs: -ldl -pthread`. A static
    # consumer needs those too; macOS gets them from libSystem, and linking
    # `-ldl` there would be pointless.
    openssl_private = "-L#{Formula["openssl@3"].opt_lib} -lssl -lcrypto"
    openssl_private += " -ldl -pthread" if OS.linux?

    (lib/"pkgconfig").mkpath
    (lib/"pkgconfig/librtmp2.pc").write <<~EOS
      prefix=#{prefix}
      exec_prefix=${prefix}
      libdir=#{lib}
      includedir=#{include}

      Name: librtmp2
      Description: RTMP and RTMPS protocol library
      Version: #{version}
      Libs: -L${libdir} -lrtmp2
      Libs.private: #{openssl_private}
      Cflags: -I${includedir}
    EOS
  end

  test do
    assert_predicate include/"librtmp2/librtmp2.h", :exist?
    assert_predicate lib/"librtmp2.a", :exist?

    # pkg-config must resolve with only this keg's .pc on the search path: a
    # `Requires.private: openssl` cannot be resolved by users because
    # openssl@3 is keg-only, and that failed every --cflags/--libs query.
    ENV["PKG_CONFIG_LIBDIR"] = (lib/"pkgconfig").to_s
    ENV.delete("PKG_CONFIG_PATH")
    assert_match "-I#{include}", shell_output("pkg-config --cflags librtmp2")
    assert_match "-lssl", shell_output("pkg-config --static --libs librtmp2")

    # `pkg-config --static` only adds the private flags; `-lrtmp2` would still
    # resolve to the shared library installed next to the archive, so link the
    # archive by path and exercise the OpenSSL flags for real.
    (testpath/"consumer.c").write <<~EOS
      #include <librtmp2/librtmp2.h>

      int main(void) {
        if (lrtmp2_version_string() == NULL) {
          return 1;
        }
        // Proves the TLS build is linked, i.e. the OpenSSL flags are required.
        return lrtmp2_tls_supported() == 1 ? 0 : 2;
      }
    EOS
    cflags = shell_output("pkg-config --cflags librtmp2").split

    # 1) The exported `Libs` line must link on its own: a missing `-lrtmp2` or
    #    a wrong `-L` directory fails here. The binary is not executed because
    #    the shared library is not on the runtime search path.
    system ENV.cc, "consumer.c", "-o", "consumer-shared", *cflags,
           *shell_output("pkg-config --libs librtmp2").split

    # 2) `pkg-config --static` only adds the private flags; `-lrtmp2` would
    #    still resolve to the shared library installed next to the archive, so
    #    link the archive by path and exercise the OpenSSL flags for real.
    static_libs = shell_output("pkg-config --static --libs librtmp2").split
    static_libs -= ["-lrtmp2"]
    system ENV.cc, "consumer.c", "-o", "consumer", *cflags,
           (lib/"librtmp2.a").to_s, *static_libs
    system "./consumer"
  end
end
