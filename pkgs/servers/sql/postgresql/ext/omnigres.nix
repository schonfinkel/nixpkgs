{
  bison,
  boost,
  brotli,
  bzip2,
  clang_18,
  cmake,
  doxygen,
  fetchFromGitHub,
  flex,
  git,
  lib,
  libcap,
  libtool,
  libuv,
  libxml2,
  lld,
  netcat,
  openssl,
  perl,
  pkg-config,
  postgresql,
  postgresqlBuildExtension,
  postgresqlTestExtension,
  python3,
  python3Packages,
  sqlite,
  readline,
  zlib,
}:

let
  pgWithExtensions = postgresql.withPackages (ps: [ ps.plpython3 ]);
in
postgresqlBuildExtension (finalAttrs: {
  pname = "omnigres";
  version = "0-unstable-2025-05-16";

  src = fetchFromGitHub {
    owner = "omnigres";
    repo = "omnigres";
    rev = "84f14792d80fb6fd60b680b7825245a8e7c5583e";
    hash = "sha256-jOlHXl7ANhMwOPizd5KH+wYZmBNNkkIa9jbXZR8Xu28=";
  };

  nativeBuildInputs = [
    clang_18
    cmake
    flex
    libtool
    pkg-config
    perl
    python3
    python3Packages.build
  ];

  buildInputs = postgresql.buildInputs ++ [
    bison
    boost
    brotli
    bzip2
    clang_18
    doxygen
    flex
    git
    libcap
    libuv
    libxml2
    lld
    netcat
    openssl
    perl
    pgWithExtensions
    python3
    python3Packages.build
    readline
    sqlite
    zlib
  ];

  cmakeFlags = [
    "-DNETCAT=${netcat}/bin/nc"
    "-DOPENSSL_CONFIGURED=1"
    "-DCMAKE_C_COMPILER=${clang_18}/bin/clang"
    "-DCMAKE_CXX_COMPILER=${clang_18}/bin/clang++"
    "-DPG_CONFIG=${pgWithExtensions.pg_config}/bin/pg_config"
    "-DPostgreSQL_EXTENSION_DIR=${lib.getDev pgWithExtensions}/share/postgresql/extension/"
    "-DPostgreSQL_PACKAGE_LIBRARY_DIR=${lib.getDev pgWithExtensions}/lib/"
    "-DPostgreSQL_TARGET_PACKAGE_LIBRARY_DIR=${builtins.placeholder "out"}/lib/"
    "-DPostgreSQL_TARGET_EXTENSION_DIR=${builtins.placeholder "out"}/share/postgresql/extension/"
    "-DPython3_EXECUTABLE=${python3}/bin/python3"
    "-DPython_EXECUTABLE=${python3}/bin/python3"
    "-DDOXYGEN_EXECUTABLE=${doxygen}/bin/doxygen"
  ];

  enableParallelBuilding = true;
  doCheck = false;

  preInstall = ''
    patchShebangs script_omni*
    mkdir -p $out/lib/
    mkdir -p $out/share/postgresql/extension/
  '';

  # https://github.com/omnigres/omnigres?tab=readme-ov-file#building--using-extensions
  installTargets = [ "install_extensions" ];

  passthru.tests.extension = postgresqlTestExtension {
    inherit (finalAttrs) finalPackage;
    withPackages = [
      "plpython3"
      "omnigres"
    ];
    sql = ''
      -- https://docs.omnigres.org/omni_id/identity_type/#usage
      CREATE EXTENSION omni_id;

      SELECT identity_type('user_id');
    '';
  };

  meta = {
    description = "Postgres as a Business Operating System";
    homepage = "https://docs.omnigres.org";
    maintainers = with lib.maintainers; [ mtrsk ];
    platforms = postgresql.meta.platforms;
    license = lib.licenses.asl20;
  };
})
