class Librtmp2 < Formula
  desc "Modern RTMP and RTMPS protocol library"
  homepage "https://github.com/OpenRTMP/librtmp2"
  url "https://github.com/OpenRTMP/librtmp2/releases/download/v0.16.0/librtmp2-0.16.0-src.tar.gz"
  sha256 "92ee4f952b5db76944d88d20a194c85d67f8c75e6cc141f2ec3ba095b56d792b"
  license "MIT"

  bottle do
    root_url "https://packages.openrtmp.org/homebrew/librtmp2/0.16.0"
    sha256 cellar: :any, arm64_golden_gate: "f1100df1e07316deab1541e759abe283ab0d75f8d7e7dabb598e6e53b2336a3d"
    sha256 cellar: :any, arm64_tahoe:       "fb910a4f949b7fefab3e4e6989884416e5137deb2b9789b28f4d26e63123adc9"
    sha256 cellar: :any, arm64_sequoia:     "660026a9d7d751c7d4f107f139a0befddfbccef0eb1498f9c6846fbb4c5cf816"
    sha256 cellar: :any, tahoe:             "82345eccef711e1c43e46138aca2ca3c73d70ac9a8e994803fb2a346ba1aec19"
    sha256 cellar: :any, sequoia:           "16cd73926ebf82974b93cf802bf7c47048b075b406b16e25707da53bbf3f28d9"
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
