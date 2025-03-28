{
  mkDerivation,
  lib,
  fetchurl,
  qtbase,
  qtsvg,
  qttools,
  qmake,
}:

let
  inherit (lib) getDev;
in

mkDerivation rec {
  pname = "qt5ct";
  version = "1.9";

  src = fetchurl {
    url = "mirror://sourceforge/qt5ct/qt5ct-${version}.tar.bz2";
    sha256 = "sha256-3BDmk51CO5JZgc5n/rsaAVtvYcAiqcx+bIte/qRYi/8=";
  };

  nativeBuildInputs = [
    qmake
    qttools
  ];

  buildInputs = [
    qtbase
    qtsvg
  ];

  qmakeFlags = [
    "LRELEASE_EXECUTABLE=${getDev qttools}/bin/lrelease"
    "PLUGINDIR=${placeholder "out"}/${qtbase.qtPluginPrefix}"
    "LIBDIR=${placeholder "out"}/lib"
  ];

  meta = with lib; {
    description = "Qt5 Configuration Tool";
    homepage = "https://sourceforge.net/projects/qt5ct/";
    platforms = platforms.linux;
    license = licenses.bsd2;
    maintainers = [ ];
    mainProgram = "qt5ct";
  };
}
