with import <nixpkgs> {};

let
  python = python2.withPackages (pp: [ pp.pygtk ]);
in stdenv.mkDerivation rec {
  pname = "gimp";
  version = "2.99.8";

  outputs = [ "out" "dev" ];

  src = fetchurl {
    url = "http://download.gimp.org/pub/gimp/v${lib.versions.majorMinor version}/${pname}-${version}.tar.bz2";
    sha256 = "3ZFr00dO8u/GUqBRAoCXerjqlePZXZGDlLBmImHDKq4=";
  };

  patches = [
    # to remove compiler from the runtime closure, reference was retained via
    # gimp --version --verbose output
    (substituteAll {
      src = ./remove-cc-reference.patch;
      cc_version = stdenv.cc.cc.name;
    })

    ## D-Bus configuration is not available in the build sandbox
    ## so we need to pick up the one from the package.
    #(substituteAll {
      #src = ./tests-dbus-conf.patch;
      #session_conf = "${dbus.daemon}/share/dbus-1/session.conf";
    #})


    # Use absolute paths instead of relying on PATH
    # to make sure plug-ins are loaded by the correct interpreter.
    ./hardcode-plugin-interpreters.patch
  ];

  nativeBuildInputs = [
    autoreconfHook # hardcode-plugin-interpreters.patch changes Makefile.am
    pkg-config
    intltool
    gettext
    makeWrapper
    gtk-doc
  ];

  buildInputs = [
    babl
    gegl
    #gtk2
    glib
    gdk-pixbuf
    pango
    cairo
    gexiv2
    harfbuzz
    isocodes
    freetype
    fontconfig
    lcms
    libpng
    libjpeg
    poppler
    poppler_data
    libtiff
    openexr
    libmng
    librsvg
    libwmf
    zlib
    libzip
    ghostscript
    aalib
    shared-mime-info
    libwebp
    libheif
    python
    libexif
    xorg.libXpm
    glib-networking
    libmypaint
    mypaint-brushes1

    gtk3
    gobject-introspection
    vala
    libarchive
    appstream-glib
    ncurses

  ] ++ lib.optionals stdenv.isDarwin [
    AppKit
    Cocoa
    gtk-mac-integration-gtk2
  ] ++ lib.optionals stdenv.isLinux [
    libgudev
  ];

  # needed by gimp-2.0.pc
  propagatedBuildInputs = [
    gegl
  ];

  configureFlags = [
    "--without-webkit" # old version is required
    "--disable-check-update"
    "--with-bug-report-url=https://github.com/NixOS/nixpkgs/issues/new"
    "--with-icc-directory=/run/current-system/sw/share/color/icc"
    # fix libdir in pc files (${exec_prefix} needs to be passed verbatim)
    "--libdir=\${exec_prefix}/lib"
  ];

  enableParallelBuilding = true;

  # on Darwin,
  # test-eevl.c:64:36: error: initializer element is not a compile-time constant
  #doCheck = !stdenv.isDarwin;
  doCheck = false;

  # Check if librsvg was built with --disable-pixbuf-loader.
  PKG_CONFIG_GDK_PIXBUF_2_0_GDK_PIXBUF_MODULEDIR = "${librsvg}/${gdk-pixbuf.moduleDir}";

  preConfigure = ''
    # The check runs before glib-networking is registered
    export GIO_EXTRA_MODULES="${glib-networking}/lib/gio/modules:$GIO_EXTRA_MODULES"
  '';

  postFixup = ''
    wrapProgram $out/bin/gimp-${lib.versions.majorMinor version} \
      --set GDK_PIXBUF_MODULE_FILE "$GDK_PIXBUF_MODULE_FILE"
  '';

  passthru = rec {
    # The declarations for `gimp-with-plugins` wrapper,
    # used for determining plug-in installation paths
    majorVersion = "${lib.versions.major version}.0";
    targetLibDir = "lib/gimp/${majorVersion}";
    targetDataDir = "share/gimp/${majorVersion}";
    targetPluginDir = "${targetLibDir}/plug-ins";
    targetScriptDir = "${targetDataDir}/scripts";

    # probably its a good idea to use the same gtk in plugins ?
    gtk = gtk3;
  };

  meta = with lib; {
    description = "The GNU Image Manipulation Program";
    homepage = "https://www.gimp.org/";
    maintainers = with maintainers; [ jtojnar ];
    license = licenses.gpl3Plus;
    platforms = platforms.unix;
  };
}
