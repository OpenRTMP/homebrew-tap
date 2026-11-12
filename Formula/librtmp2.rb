class Librtmp2 < Formula
  desc "Modern RTMP and RTMPS protocol library"
  homepage "https://github.com/OpenRTMP/librtmp2"
  url "https://github.com/OpenRTMP/librtmp2/releases/download/v0.17.1/librtmp2-0.17.1-src.tar.gz"
  sha256 "ff8fff8cc3e90564dcd8d514f8b88bd375e6bd6519b37a1485b5e875c5729c62"
  license "MIT"

  bottle do
    root_url "https://packages.openrtmp.org/homebrew/librtmp2/0.17.1"
    sha256 cellar: :any, arm64_golden_gate: "dd07cab9e536bf43b1caf4da4a3cb5d1e29e932ed098bcfeab07aa805d271040"
    sha256 cellar: :any, arm64_tahoe:       "49fcf93e1d515787df0454e6b750103e00742e14c87a6e180d16f836035bc658"
    sha256 cellar: :any, arm64_sequoia:     "322ce1c6298780d28f0cdefaf933eb86bd444093dddc5bb3a7876fe23f377d20"
    sha256 cellar: :any, tahoe:             "c1f01abf4edb4af72bd9ed258f425fb3f14fd5d6045c121b45041e26c63068a8"
    sha256 cellar: :any, sequoia:           "3322cadfa4077087af93b2b60457e25a17cd98f63a82bb3c0dc701a93335e6f7"
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

    # OpenSSL's Linux libcrypto.pc carries `ex_libs: -ldl -pthread`.
    # A static consumer needs those too; macOS gets them from
    # libSystem, and linking `-ldl` there would be pointless.
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

    # pkg-config must resolve with only this keg's .pc on the search
    # path: a `Requires.private: openssl` cannot be resolved by users
    # because openssl@3 is keg-only.
    ENV["PKG_CONFIG_LIBDIR"] = (lib/"pkgconfig").to_s
    ENV.delete("PKG_CONFIG_PATH")
    assert_match "-I#{include}", shell_output("pkg-config --cflags librtmp2")
    assert_match "-lssl", shell_output("pkg-config --static --libs librtmp2")

    # `pkg-config --static` only adds the private flags; `-lrtmp2`
    # would still resolve to the shared library installed next to the
    # archive, so link the archive by path and exercise the OpenSSL
    # flags for real.
    (testpath/"consumer.c").write <<~EOS
      #include <librtmp2/librtmp2.h>

      int main(void) {
        if (lrtmp2_version_string() == NULL) {
          return 1;
        }
        // Proves the TLS build is linked, i.e. the OpenSSL flags are
        // required.
        return lrtmp2_tls_supported() == 1 ? 0 : 2;
      }
    EOS
    cflags = shell_output("pkg-config --cflags librtmp2").split

    # 1) The exported `Libs` line must link on its own: a missing
    #    `-lrtmp2` or a wrong `-L` directory fails here. The binary
    #    is not executed because the shared library is not on the
    #    runtime search path.
    system ENV.cc, "consumer.c", "-o", "consumer-shared", *cflags,
           *shell_output("pkg-config --libs librtmp2").split

    # 2) `pkg-config --static` only adds the private flags; `-lrtmp2`
    #    would still resolve to the shared library installed next to
    #    the archive, so link the archive by path and exercise the
    #    OpenSSL flags for real.
    static_libs = shell_output("pkg-config --static --libs librtmp2").split
    static_libs -= ["-lrtmp2"]
    system ENV.cc, "consumer.c", "-o", "consumer", *cflags,
           (lib/"librtmp2.a").to_s, *static_libs
    system "./consumer"
  end
end
