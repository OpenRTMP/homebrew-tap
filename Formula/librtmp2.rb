class Librtmp2 < Formula
  desc "Modern RTMP and RTMPS protocol library"
  homepage "https://github.com/OpenRTMP/librtmp2"
  url "https://github.com/OpenRTMP/librtmp2/releases/download/v0.15.0/librtmp2-0.15.0-src.tar.gz"
  sha256 "ffa7a016b3ab2715f85e97849db0e88d8e71173384469b1f8f9859c857ef10d5"
  license "MIT"

  bottle do
    root_url "https://packages.openrtmp.org/homebrew/librtmp2/0.15.0"
    sha256 cellar: :any, arm64_golden_gate: "0edbe8ab32b797ee116a9e296ce9909ff11aa013c175c4f78feb1f7a9847adfd"
    sha256 cellar: :any, arm64_tahoe:       "dd472ffb78822788c24feebd24ae002465c50dc8dcc1ec6b1f4d379e0916d774"
    sha256 cellar: :any, arm64_sequoia:     "a61fda866ea0b2a56776cbb5b098f257c49fc3876c6c44afd951c0e0a18b011c"
    sha256 cellar: :any, tahoe:             "74787c9045eff47948e67fbf5a0c5749f4fc9efb007eb732ff7091aed716cb87"
    sha256 cellar: :any, sequoia:           "5f9cca5ab68ddfa6855142bbfead6dad55a6f3a288f0041c3009749d13e514d8"
  end

  depends_on "cbindgen" => :build
  depends_on "pkgconf" => :build
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

    (lib/"pkgconfig").mkpath
    (lib/"pkgconfig/librtmp2.pc").write <<~EOS
      prefix=#{prefix}
      exec_prefix=${prefix}
      libdir=#{lib}
      includedir=#{include}

      Name: librtmp2
      Description: RTMP and RTMPS protocol library
      Version: #{version}
      Requires.private: openssl
      Libs: -L${libdir} -lrtmp2
      Cflags: -I${includedir}/librtmp2
    EOS
  end

  test do
    assert_predicate include/"librtmp2/librtmp2.h", :exist?
    assert_predicate lib/"librtmp2.a", :exist?
  end
end
