class CephClient < Formula
  desc "Ceph client tools and libraries"
  homepage "https://ceph.com"
  url "https://download.ceph.com/tarballs/ceph-17.2.0.tar.gz"
  sha256 "6cf2d838904f0c40a2c735790b543063ea675c727e6b7047ebddfa1e7505e71f"

  bottle do
    root_url "https://github.com/mulbc/homebrew-ceph-client/releases/download/quincy-17.0.0-4483"
    sha256 cellar: :any, big_sur: "8796c05eaa6ac5065221ff6ba1b45201776666e5702f6573b8a3f857ba890d1f"
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
    url "https://files.pythonhosted.org/packages/cb/7d/7e6bc4bd4abc49e9f4f5c4773bb43d1615e4b476d108d1b527318b9c6521/prettytable-3.2.0.tar.gz"
    sha256 "ae7d96c64100543dc61662b40a28f3b03c0f94a503ed121c6fca2782c5816f81"
  end

  resource "PyYAML" do
    url "https://files.pythonhosted.org/packages/36/2b/61d51a2c4f25ef062ae3f74576b01638bebad5e045f747ff12643df63844/PyYAML-6.0.tar.gz"
    sha256 "68fb519c14306fec9720a2a5b45bc9f0c8d1b9c72adf45c37baedfcd949c35a2"
  end

  resource "wcwidth" do
    url "https://files.pythonhosted.org/packages/89/38/459b727c381504f361832b9e5ace19966de1a235d73cdbdea91c771a1155/wcwidth-0.2.5.tar.gz"
    sha256 "c4d647b99872929fdb7bdcaa4fbe7f01413ed3d98077df798530e5b04f116c83"
  end

  patch :DATA

  def install
    ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["nss"].opt_lib}/pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["openssl"].opt_lib}/pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", "/usr/local/lib/pkgconfig"
    xy = Language::Python.major_minor_version "python3"
    ENV.prepend_create_path "PYTHONPATH", "#{Formula["cython"].opt_libexec}/lib/python#{xy}/site-packages"
    ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python#{xy}/site-packages"
    resources.each do |r|
      r.stage do
        system "python3", *Language::Python.setup_install_args(libexec/"vendor")
      end
    end

    args = %W[
      -DDIAGNOSTICS_COLOR=always
      -DOPENSSL_ROOT_DIR=#{Formula["openssl"].opt_prefix}
      -DWITH_BABELTRACE=OFF
      -DWITH_BLUESTORE=OFF
      -DWITH_CCACHE=OFF
      -DWITH_CEPHFS=OFF
      -DWITH_KRBD=OFF
      -DWITH_LIBCEPHFS=ON
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
      cephfs
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
        ceph-common.2
        ceph-common
        rados.2.0.0
        rados.2
        rados
        radosstriper.1.0.0
        radosstriper.1
        radosstriper
        rbd.1.17.0
        rbd.1
        rbd
        cephfs.2.0.0
        cephfs.2
        cephfs
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
      system "ninja", "src/pybind/install", "src/include/install"
    end

    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])
    %w[
      ceph-conf
      ceph-fuse
      rados
      rbd
    ].each do |name|
      system "install_name_tool", "-add_rpath", "/opt/homebrew/lib", "#{libexec}/bin/#{name}"
    end
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
diff --git a/cmake/modules/Distutils.cmake b/cmake/modules/Distutils.cmake
index 8dc69f0af51..0b2acaf160a 100644
--- a/cmake/modules/Distutils.cmake
+++ b/cmake/modules/Distutils.cmake
@@ -79,11 +79,9 @@ function(distutils_add_cython_module target name src)
     OUTPUT ${output_dir}/${name}${ext_suffix}
     COMMAND
     env
-    CC="${PY_CC}"
     CFLAGS="${PY_CFLAGS}"
     CPPFLAGS="${PY_CPPFLAGS}"
     CXX="${PY_CXX}"
-    LDSHARED="${PY_LDSHARED}"
     OPT=\"-DNDEBUG -g -fwrapv -O2 -w\"
     LDFLAGS=-L${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
     CYTHON_BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
@@ -108,8 +106,6 @@ function(distutils_install_cython_module name)
     set(CFLAG_DISABLE_VTA -fno-var-tracking-assignments)
   endif()
   install(CODE "
-    set(ENV{CC} \"${PY_CC}\")
-    set(ENV{LDSHARED} \"${PY_LDSHARED}\")
     set(ENV{CPPFLAGS} \"-iquote${CMAKE_SOURCE_DIR}/src/include
                         -D'void0=dead_function\(void\)' \
                         -D'__Pyx_check_single_interpreter\(ARG\)=ARG \#\# 0' \

