class CephClient < Formula
  desc "Ceph client tools and libraries"
  homepage "https://ceph.com"
  url "https://github.com/ceph/ceph.git", :using => :git, :revision => "e870f7a4288ead4355fb7c036fc99718bc062b77"
  version "mimic-13.2.2"

  bottle do
    root_url "https://github.com/zeichenanonym/homebrew-ceph-client/releases/download/mimic-13.2.2/"
    rebuild 4
    sha256 "4d6353237078f0e10443ef3491ad99328ef13bf9b16108d8781c99ea228d2eb6" => :high_sierra
    sha256 "156ccf908126ab48fdabc8887e0cd2f6555dd6b8d78a3bc117a4275ca6d2161a" => :mojave
  end

  # depends_on "osxfuse"
  depends_on "boost" => :build
  depends_on "openssl" => :build
  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "cython" => :build
  depends_on "leveldb" => :build
  depends_on "nss"
  depends_on "pkg-config" => :build
  depends_on "python3"
  depends_on "sphinx-doc" => :build
  depends_on "yasm"

  resource "prettytable" do
    url "https://files.pythonhosted.org/packages/d4/c6/d388b3d4992acf413d1b67101107b7f4651cc2835abd0bbd6661678eb2c1/prettytable-2.1.0.tar.gz"
    sha256 "5882ed9092b391bb8f6e91f59bcdbd748924ff556bb7c634089d5519be87baa0"
  end

  patch :DATA

  def install
    pyver = Language::Python.major_minor_version "python3"
    ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["nss"].opt_lib}/pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["openssl"].opt_lib}/pkgconfig"
    ENV.prepend_path "PYTHONPATH", "#{Formula["cython"].opt_libexec}/lib/python#{pyver}/site-packages"
    args = %W[
      -DDIAGNOSTICS_COLOR=always
      -DOPENSSL_ROOT_DIR=#{Formula["openssl"].opt_prefix}
      -DWITH_BABELTRACE=OFF
      -DWITH_BLUESTORE=OFF
      -DWITH_CCACHE=OFF
      -DWITH_CEPHFS=OFF
      -DWITH_KRBD=OFF
      -DWITH_LIBCEPHFS=OFF
      -DWITH_LTTNG=OFF
      -DWITH_LZ4=OFF
      -DWITH_MANPAGE=ON
      -DWITH_MGR=OFF
      -DWITH_MGR_DASHBOARD_FRONTEND=OFF
      -DWITH_RADOSGW=OFF
      -DWITH_RDMA=OFF
      -DWITH_SPDK=OFF
      -DWITH_SYSTEM_BOOST=ON
      -DWITH_SYSTEMD=OFF
      -DWITH_TESTS=OFF
      -DWITH_XFS=OFF
    ]
    targets = %w[
      rados
      rbd
      ceph-conf
      ceph-fuse
      manpages
      cython_rados
      cython_rbd
    ]
    mkdir "build" do
      system "cmake", "-G", "Ninja", "..", *args, *std_cmake_args
      system "ninja", *targets
      executables = %w[
        bin/rados
        bin/rbd
        bin/ceph-fuse
      ]
      executables.each do |file|
        MachO.open(file).linked_dylibs.each do |dylib|
          unless dylib.start_with?("/tmp/")
            next
          end
          MachO::Tools.change_install_name(file, dylib, "#{lib}/#{dylib.split('/')[-1]}")
        end
      end
      %w[
        ceph
        ceph-conf
        ceph-fuse
        rados
        rbd
      ].each do |file|
        bin.install "bin/#{file}"
      end
      %w[
        ceph-common.0
        ceph-common
        rados.2.0.0
        rados.2
        rados
        radosstriper.1.0.0
        radosstriper.1
        radosstriper
        rbd.1.12.0
        rbd.1
        rbd
      ].each do |name|
        lib.install "lib/lib#{name}.dylib"
      end
      %w[
        ceph-conf
        ceph-fuse
        ceph
        librados-config
        rados
        rbd
      ].each do |name|
        man8.install "doc/man/#{name}.8"
      end
      system "ninja", "src/pybind/install"
    end

    resources.each do |r|
      r.stage do
        system "python", *Language::Python.setup_install_args(libexec/"vendor")
      end
    end
    ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python#{pyver}/site-packages"
    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])
  end

  def caveats; <<~EOS
    The fuse version shipped with osxfuse is too old to access the
    supplementary group IDs in cephfs.
    Thus you need to add this to your ceph.conf to avoid errors:

    [client]
    fuse_set_user_groups = false

    EOS
  end

  test do
    system "#{bin}/ceph", "--version"
    system "#{bin}/ceph-fuse", "--version"
    system "#{bin}/rbd", "--version"
    system "#{bin}/rados", "--version"
    system "python", "-c", "import rados"
    system "python", "-c", "import rbd"
  end
end

__END__
diff --git a/src/auth/KeyRing.cc b/src/auth/KeyRing.cc
index 832cae0a34..cd3af3470b 100644
--- a/src/auth/KeyRing.cc
+++ b/src/auth/KeyRing.cc
@@ -204,12 +204,12 @@ void KeyRing::decode(bufferlist::iterator& bl) {
   __u8 struct_v;
   bufferlist::iterator start_pos = bl;
   try {
+    decode_plaintext(start_pos);
+  } catch (...) {
+    keys.clear();
     using ceph::decode;
     decode(struct_v, bl);
     decode(keys, bl);
-  } catch (buffer::error& err) {
-    keys.clear();
-    decode_plaintext(start_pos);
   }
 }
 
diff --git a/src/include/any.h b/src/include/any.h
index 73e729b..241e0e6 100644
--- a/src/include/any.h
+++ b/src/include/any.h
@@ -15,17 +15,10 @@
 #ifndef INCLUDE_STATIC_ANY
 #define INCLUDE_STATIC_ANY
 
-#if __has_include(<any>)
-#include <any>
-namespace ceph {
-  using std::bad_any_cast;
-}
-#else
 #include <boost/any.hpp>
 namespace ceph {
   using boost::bad_any_cast;
 }
-#endif
 
 #include <cstddef>
 #include <initializer_list>
